#if !FA2_MAC_TOKEN
#define FA2_MAC_TOKEN

#include "../fa2/ligo/fa2_interface.mligo"
#include "../fa2/ligo/fa2_errors.mligo"
#include "../fa2/ligo/lib/fa2_operator_lib.mligo"

(* (owner,token_id) -> balance *)
type ledger = ((address * token_id), nat) big_map

(* token_id -> total_supply *)
type token_total_supply = (token_id, nat) big_map

(* token_id -> token_metadata *)
type token_metadata_storage = (token_id, token_metadata_michelson) big_map

type multi_token_storage = {
  ledger : ledger;
  operators : operator_storage;
  token_total_supply : token_total_supply;
  token_metadata : token_metadata_storage;
}

let get_balance_amt (key, ledger : (address * nat) * ledger) : nat =
  let bal_opt = Big_map.find_opt key ledger in
  match bal_opt with
  | None -> 0n
  | Some b -> b

let inc_balance (owner, token_id, amt, ledger
    : address * token_id * nat * ledger) : ledger =
  let key = owner, token_id in
  let bal = get_balance_amt (key, ledger) in
  let updated_bal = bal + amt in
  Big_map.update key (Some updated_bal) ledger 

let dec_balance (owner, token_id, amt, ledger
    : address * token_id * nat * ledger) : ledger =
  let key = owner, token_id in
  let bal = get_balance_amt (key, ledger) in
  match Michelson.is_nat (bal - amt) with
  | None -> (failwith fa2_insufficient_balance : ledger)
  | Some new_bal ->
    if new_bal = 0n
    then Big_map.remove key ledger
    else Map.update key (Some new_bal) ledger

(**
Update leger balances according to the specified transfers. Fails if any of the
permissions or constraints are violated.
@param txs transfers to be applied to the ledger
@param owner_validator function that validates of the tokens from the particular owner can be transferred. 
 *)
let transfer (txs, owner_validator, storage
    : (transfer list) * ((address * operator_storage) -> unit) * multi_token_storage)
    : ledger =
  let make_transfer = fun (l, tx : ledger * transfer) ->
    let u = owner_validator (tx.from_, storage.operators) in
    List.fold 
      (fun (ll, dst : ledger * transfer_destination) ->
        if not Big_map.mem dst.token_id storage.token_metadata
        then (failwith fa2_token_undefined : ledger)
        else
          let lll = dec_balance (tx.from_, dst.token_id, dst.amount, ll) in
          inc_balance(dst.to_, dst.token_id, dst.amount, lll)
      ) tx.txs l
  in
  List.fold make_transfer txs storage.ledger
 
let get_balance (p, ledger, tokens
    : balance_of_param * ledger * token_total_supply) : operation =
  let to_balance = fun (r : balance_of_request) ->
    if not Big_map.mem r.token_id tokens
    then (failwith fa2_token_undefined : balance_of_response_michelson)
    else
      let key = r.owner, r.token_id in
      let bal = get_balance_amt (key, ledger) in
      let response = { request = r; balance = bal; } in
      balance_of_response_to_michelson response
  in
  let responses = List.map to_balance p.requests in
  Operation.transaction responses 0mutez p.callback


let fa2_main (param, storage : fa2_entry_points * multi_token_storage)
    : (operation  list) * multi_token_storage =
  match param with
  | Transfer txs_michelson -> 
     (* convert transfer batch into `transfer_descriptor` batch *)
    let txs = transfers_from_michelson txs_michelson in
    (* 
    will validate that a sender is either `from_` parameter of each transfer
    or a permitted operator for the owner `from_` address.
    *)
    let validator = make_default_operator_validator Tezos.sender in
    let new_ledger = transfer (txs, validator, storage) in
    let new_storage = { storage with ledger = new_ledger; }
    in ([] : operation list), new_storage

  | Balance_of pm -> 
    let p = balance_of_param_from_michelson pm in
    let op = get_balance (p, storage.ledger, storage.token_total_supply) in
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
    (* the contract maintains token metadata in its storage - `token_metadata` big_map *)
    let callback_op = Operation.transaction Tezos.self_address 0mutez callback in
    [callback_op], storage

#endif