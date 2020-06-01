#if !FA2_SINGLE_TOKEN
#define FA2_SINGLE_TOKEN

#include "../fa2_interface.mligo"
#include "../fa2_errors.mligo"
#include "../lib/fa2_operator_lib.mligo"

type ledger = (address, nat) big_map

type single_token_storage = {
  ledger : ledger;
  operators : operator_storage;
  metadata : token_metadata;
  total_supply : nat;
}

let transfers_to_descriptors (txs : transfer list) : transfer_descriptor list =
  List.map 
    (fun (tx : transfer) ->
      let txs = List.map 
        (fun (dst : transfer_destination) ->
          if dst.token_id <> 0n
          then (failwith token_undefined : transfer_destination_descriptor)
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

let get_balance (p, ledger : balance_of_param * ledger) : operation =
  let to_balance = fun (r : balance_of_request) ->
    if r.token_id <> 0n
    then (failwith token_undefined : balance_of_response_michelson)
    else
      let bal = get_balance_amt (r.owner, ledger) in
      let response = { request = r; balance = bal; } in
      balance_of_response_to_michelson response
  in
  let responses = List.map to_balance p.requests in
  Operation.transaction responses 0mutez p.callback

let inc_balance (owner, amt, ledger
    : address * nat * ledger) : ledger =
  let bal = get_balance_amt (owner, ledger) in
  let updated_bal = bal + amt in
  Big_map.update owner (Some updated_bal) ledger 

let dec_balance (owner, amt, ledger
    : address * nat * ledger) : ledger =
  let bal = get_balance_amt (owner, ledger) in
  match Michelson.is_nat (bal - amt) with
  | None -> (failwith insufficient_balance : ledger)
  | Some new_bal ->
    if new_bal = 0n
    then Big_map.remove owner ledger
    else Map.update owner (Some new_bal) ledger

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
        then (failwith token_undefined : ledger)
        else
          let lll = match tx.from_ with
          | None -> ll
          | Some from_ -> dec_balance (from_, dst.amount, ll)
          in 
          match dst.to_ with
          | None -> lll
          | Some to_ -> inc_balance(to_, dst.amount, lll) 
      ) tx.txs l
  in    
  List.fold make_transfer txs ledger

let validate_token_ids (tokens : token_id list) : unit =
  List.iter (fun (id : nat) ->
    if id = 0n then unit else failwith token_undefined
  ) tokens

let fa2_main (param, storage : fa2_entry_points * single_token_storage)
    : (operation  list) * single_token_storage =
  match param with
  | Transfer txs_michelson -> 
    let txs = transfers_from_michelson txs_michelson in
    let tx_descriptors = transfers_to_descriptors txs in
    let validator = make_default_operator_validator Tezos.sender in
    let new_ledger = transfer (tx_descriptors, validator, storage.operators, storage.ledger) in
    let new_storage = { storage with ledger = new_ledger; }
    in ([] : operation list), new_storage

  | Balance_of pm ->
    let p = balance_of_param_from_michelson pm in
    let op = get_balance (p, storage.ledger) in
    [op], storage

  | Total_supply pm ->
    let p : total_supply_param = Layout.convert_from_right_comb pm in
    let u = validate_token_ids p.token_ids in
    let response : total_supply_response = { 
      token_id = 0n;
      total_supply = storage.total_supply;
    } in
    let response_michelson = Layout.convert_to_right_comb response in
    let responses = List.map 
      (fun (tid: token_id) -> response_michelson)
      p.token_ids in
    let op = Operation.transaction responses 0mutez p.callback in
    [op], storage

  | Token_metadata pm ->
    let p : token_metadata_param = Layout.convert_from_right_comb pm in
    let u = validate_token_ids p.token_ids in
    let metadata_michelson : token_metadata_michelson = 
      Layout.convert_to_right_comb storage.metadata in
    let responses = List.map 
      (fun (tid: token_id) -> metadata_michelson)
      p.token_ids in
    let op = Operation.transaction responses 0mutez p.callback in
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

  | Is_operator pm ->
    let p = is_operator_param_from_michelson pm in
    let op = is_operator (p, storage.operators) in
    [op], storage

#endif
