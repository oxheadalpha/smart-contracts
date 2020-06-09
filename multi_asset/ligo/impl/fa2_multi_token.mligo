#if !FA2_MAC_TOKEN
#define FA2_MAC_TOKEN

#include "../fa2_interface.mligo"
#include "../fa2_errors.mligo"
#include "../lib/fa2_operator_lib.mligo"

(* (owner,token_id) -> balance *)
type ledger = ((address * token_id), nat) big_map

type token_info = {
  metadata : token_metadata;
  total_supply : nat;
}
(* token_id -> metadata *)
type token_storage = (token_id, token_info) big_map

type multi_token_storage = {
  ledger : ledger;
  operators : operator_storage;
  tokens : token_storage;
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
    : (transfer_descriptor list) * ((address * operator_storage) -> unit) * multi_token_storage)
    : ledger =
  let make_transfer = fun (l, tx : ledger * transfer_descriptor) ->
    let u = match tx.from_ with
    | None -> unit
    | Some o -> owner_validator (o, storage.operators)
    in
    List.fold 
      (fun (ll, dst : ledger * transfer_destination_descriptor) ->
        if not Big_map.mem dst.token_id storage.tokens
        then (failwith fa2_token_undefined : ledger)
        else
         let lll = match tx.from_ with
          | None -> ll (* this is a mint transfer. do not need to update `from_` balance *)
          | Some from_ -> dec_balance (from_, dst.token_id, dst.amount, ll)
          in 
          match dst.to_ with
          | None -> lll (* this is a burn transfer. do not need to update `to_` balance *)
          | Some to_ -> inc_balance(to_, dst.token_id, dst.amount, lll) 
      ) tx.txs l
  in
  List.fold make_transfer txs storage.ledger
(* 
let get_balance (p, ledger : balance_of_param * ledger) : operation =
  let to_balance = fun (r : balance_of_request) ->
    let key = r.owner, r.token_id in
    let bal = get_balance_amt (key, ledger) in
    { request = r; balance = bal; } 
  in
  let responses = List.map to_balance p.requests in
  Operation.transaction responses 0mutez p.callback

let get_metadata (p, tokens : token_metadata_param * token_storage) : operation =
  let get_meta = fun (tid : token_id) ->
    let info = Big_map.find_opt tid tokens in
    match info with
    | None -> (failwith "token id not found" : token_metadata)
    | Some i -> i.metadata
  in
  let metas = List.map get_meta p.token_ids in
  Operation.transaction metas 0mutez p.callback *)

let fa2_main (param, storage : fa2_entry_points * multi_token_storage)
    : (operation  list) * multi_token_storage =
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
    let new_ledger = transfer (tx_descriptors, validator, storage) in
    let new_storage = { storage with ledger = new_ledger; }
    in ([] : operation list), new_storage

  | Balance_of p -> 
    (* let op = get_balance (p, storage.ledger) in
    [op], storage *)
    ([] : operation list), storage

  | Token_metadata p -> 
    (* let op = get_metadata (p, storage.tokens) in
    [op], storage *)
    ([] : operation list), storage

  | Update_operators updates ->
    (* let new_ops = update_operators (updates, storage.operators) in
    let new_storage = { storage with operators = new_ops; } in
    ([] : operation list), new_storage *)
    ([] : operation list), storage


#endif