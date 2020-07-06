(**
Defines non-mutable NFT collection. Once contract is created, no tokens can
be minted or burned.
Metadata may/should contain URLs for token images and images hashes.

The implementation may support sender/receiver hooks
 *)

#if ! FA2_FIXED_COLLECTION_TOKEN
#define FA2_FIXED_COLLECTION_TOKEN

#include "../fa2/fa2_interface.mligo"
#include "../fa2/fa2_errors.mligo"
#include "../fa2/lib/fa2_operator_lib.mligo"

(* token_id -> token_metadata *)
type token_metadata_storage = (token_id, token_metadata_michelson) big_map

(*  token_id -> owner_address *)
type ledger = (token_id, address) big_map

type collection_storage = {
  ledger : ledger;
  operators : operator_storage;
  token_metadata : token_metadata_storage;
  permissions_descriptor : permissions_descriptor;
}

(**
Update leger balances according to the specified transfers. Fails if any of the
permissions or constraints are violated.
@param txs transfers to be applied to the ledger
@param owner_validator function that validates of the tokens from the particular owner can be transferred. 
 *)
let transfer (txs, owner_validator, ops_storage, ledger
    : (transfer list) * ((address * operator_storage) -> unit) * operator_storage * ledger) : ledger =
  (* process individual transfer *)
  let make_transfer = (fun (l, tx : ledger * transfer) ->
    let u = owner_validator (tx.from_, ops_storage) in
    List.fold 
      (fun (ll, dst : ledger * transfer_destination) ->
        if dst.amount = 0n
        then ll
        else if dst.amount <> 1n
        then (failwith fa2_insufficient_balance : ledger)
        else
          let owner = Big_map.find_opt dst.token_id ll in
          match owner with
          | None -> (failwith fa2_token_undefined : ledger)
          | Some o -> 
            if o <> tx.from_
            then (failwith fa2_insufficient_balance : ledger)
            else Big_map.update dst.token_id (Some dst.to_) ll
      ) tx.txs l
  )
  in 
    
  List.fold make_transfer txs ledger

(** 
Retrieve the balances for the specified tokens and owners
@return callback operation
*)
let get_balance (p, ledger : balance_of_param * ledger) : operation =
  let to_balance = fun (r : balance_of_request) ->
    let owner = Big_map.find_opt r.token_id ledger in
    let response = match owner with
    | None -> (failwith fa2_token_undefined : balance_of_response)
    | Some o ->
      let bal = if o = r.owner then 1n else 0n in
      { request = r; balance = bal; }
    in
    balance_of_response_to_michelson response
  in
  let responses = List.map to_balance p.requests in
  Operation.transaction responses 0mutez p.callback


let fixed_collection_token_main (param, storage : fa2_entry_points * collection_storage)
    : (operation list) * collection_storage =
  match param with
  | Transfer txs_michelson ->
    let txs = transfers_from_michelson txs_michelson in
    let validator = make_default_operator_validator Tezos.sender in
    let new_ledger = transfer (txs, validator, storage.operators, storage.ledger) in

    ([] : operation list), storage
  
  | Balance_of pm ->
    let p = balance_of_param_from_michelson pm in
    let op = get_balance (p, storage.ledger) in
    [op], storage

  | Update_operators updates_michelson ->
    let updates = operator_updates_from_michelson updates_michelson in
    let updater = Tezos.sender in
    let process_update = (fun (ops, update : operator_storage * update_operator) ->
      let u = validate_update_operators_by_owner (update, updater) in
      update_operators (update, ops)
    ) in
    let new_ops = 
      List.fold process_update updates storage.operators in
    let new_storage = { storage with operators = new_ops; } in
    ([] : operation list), new_storage

  | Token_metadata_registry callback ->
    (* the contract stores its own token metadata and exposes `token_metadata` entry point *)
    let callback_op = Operation.transaction Tezos.self_address 0mutez callback in
    [callback_op], storage

#endif