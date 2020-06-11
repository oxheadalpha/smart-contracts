(**
Implementation of the FA2 interface for the single token contract.
 *)


#if !FA2_SINGLE_TOKEN
#define FA2_SINGLE_TOKEN

#include "../fa2_interface.mligo"
#include "../fa2_errors.mligo"
#include "../lib/fa2_operator_lib.mligo"

type ledger = (address, nat) big_map

type single_token_storage = {
  ledger : ledger;
  operators : operator_storage;
  token_metadata : (nat, token_metadata_michelson) big_map;
  total_supply : nat;
}

(**
Converts transfer parameters to `transfer_descriptors.

Helps to reuse the same transfer logic for `transfer`, `min` and `burn` implementation.
Can be used to support optional sender/receiver hooks in future.
 *)
let transfers_to_descriptors (txs : transfer list) : transfer_descriptor list =
  List.map 
    (fun (tx : transfer) ->
      let txs = List.map 
        (fun (dst : transfer_destination) ->
          if dst.token_id <> 0n
          then (failwith fa2_token_undefined : transfer_destination_descriptor)
          else {
            to_ = Some dst.to_;
            token_id = dst.token_id;
            amount = dst.amount;
          }
        ) tx.txs in
        {
          from_ = Some tx.from_;
          txs = txs;
        }
    ) txs 


let get_balance_amt (owner, ledger : address  * ledger) : nat =
  let bal_opt = Big_map.find_opt owner ledger in
  match bal_opt with
  | None -> 0n
  | Some b -> b

let inc_balance (owner, amt, ledger
    : address * nat * ledger) : ledger =
  let bal = get_balance_amt (owner, ledger) in
  let updated_bal = bal + amt in
  Big_map.update owner (Some updated_bal) ledger 

let dec_balance (owner, amt, ledger
    : address * nat * ledger) : ledger =
  let bal = get_balance_amt (owner, ledger) in
  match Michelson.is_nat (bal - amt) with
  | None -> (failwith fa2_insufficient_balance : ledger)
  | Some new_bal ->
    if new_bal = 0n
    then Big_map.remove owner ledger
    else Map.update owner (Some new_bal) ledger

(**
Update leger balances according to the specified transfers. Fails if any of the
permissions or constraints are violated.
@param txs transfers to be applied to the ledger
@param owner_validator function that validates of the tokens from the particular owner can be transferred. 
 *)
let transfer (txs, owner_validator, ops_storage, ledger
    : (transfer_descriptor list) * ((address * operator_storage) -> unit) * operator_storage * ledger)
    : ledger =
  let make_transfer = fun (l, tx : ledger * transfer_descriptor) ->
    let u = match tx.from_ with
    | None -> unit
    | Some o -> owner_validator (o, ops_storage)
    in
    List.fold 
      (fun (ll, dst : ledger * transfer_destination_descriptor) ->
        if dst.token_id <> 0n
        then (failwith fa2_token_undefined : ledger)
        else
          let lll = match tx.from_ with
          | None -> ll (* this is a mint transfer. do not need to update `from_` balance *)
          | Some from_ -> dec_balance (from_, dst.amount, ll)
          in 
          match dst.to_ with
          | None -> lll (* this is a burn transfer. do not need to update `to_` balance *)
          | Some to_ -> inc_balance(to_, dst.amount, lll) 
      ) tx.txs l
  in    
  List.fold make_transfer txs ledger

(** 
Retrieve the balances for the specified tokens and owners
@return callback operation
*)
let get_balance (p, ledger : balance_of_param * ledger) : operation =
  let to_balance = fun (r : balance_of_request) ->
    if r.token_id <> 0n
    then (failwith fa2_token_undefined : balance_of_response_michelson)
    else
      let bal = get_balance_amt (r.owner, ledger) in
      let response = { request = r; balance = bal; } in
      balance_of_response_to_michelson response
  in
  let responses = List.map to_balance p.requests in
  Operation.transaction responses 0mutez p.callback

(** Validate if all provided token_ids are `0n` and correspond to a single token ID *)
let validate_token_ids (tokens : token_id list) : unit =
  List.iter (fun (id : nat) ->
    if id = 0n then unit else failwith fa2_token_undefined
  ) tokens

let fa2_main (param, storage : fa2_entry_points * single_token_storage)
    : (operation  list) * single_token_storage =
  match param with
  | Transfer txs_michelson -> 
    (* convert transfer batch into `transfer_descriptor` batch *)
    let txs = transfers_from_michelson txs_michelson in
    let tx_descriptors = transfers_to_descriptors txs in
    (* 
    will validate that a sender is either `from_` parameter of each transfer
    or a permitted operator for the owner `from_` address.
    *)
    let validator = make_default_operator_validator Tezos.sender in
    let new_ledger = transfer (tx_descriptors, validator, storage.operators, storage.ledger) in
    let new_storage = { storage with ledger = new_ledger; }
    in ([] : operation list), new_storage

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
    (* the contract storage holds `token_metadata` big_map*)
    let callback_op = Operation.transaction Tezos.self_address 0mutez callback in
    [callback_op], storage


#endif
