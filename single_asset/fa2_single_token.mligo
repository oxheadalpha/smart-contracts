#include "fa2_interface.mligo"

type ledger = (address, nat) big_map
type operators = ((address * address), bool) big_map

type single_token_storage = {
  ledger : ledger;
  operators : operators;
  metadata : token_metadata;
  total_supply : nat;
  permissions_descriptor : permissions_descriptor;
}

let validate_operator (txs, self, ops_storage 
    : (transfer_descriptor list) * self_transfer_policy * operators) : unit =
  let can_self_tx = match self with
  | Self_transfer_permitted -> true
  | Self_transfer_denied -> false
  in
  let operator = Current.sender in
  let owners = List.fold
    (fun (owners, tx : (address set) * transfer_descriptor) ->
      match tx.from_ with
      | None -> owners
      | Some o -> Set.add o owners
    ) txs (Set.empty : address set) in

  Set.iter
    (fun (owner : address) ->
      if can_self_tx && owner = operator
      then unit
      else
        let key = owner, operator in
        let is_op_opt = Big_map.find_opt key ops_storage in
        match is_op_opt with
        | None -> failwith "not permitted operator"
        | Some o -> unit
    ) owners

let transfers_to_descriptors (txs : transfer list) : transfer_descriptor list =
  List.map 
    (fun (tx : transfer) ->
      if tx.token_id <> 0n
      then (failwith "Only 0n token_id is accepted" : transfer_descriptor)
      else {
        from_ = Some tx.from_;
        to_ = Some tx.to_;
        token_id = tx.token_id;
        amount = tx.amount;
      }) txs 


let get_balance_amt (owner, ledger : address  * ledger) : nat =
  let bal_opt = Big_map.find_opt owner ledger in
  match bal_opt with
  | None -> 0n
  | Some b -> b

let get_balance (p, ledger : balance_of_param * ledger) : operation =
  let to_balance = fun (r : balance_of_request) ->
    if r.token_id <> 0n
    then (failwith "Only 0n token_id is accepted" : balance_of_response)
    else
      let bal = get_balance_amt (r.owner, ledger) in
      { request = r; balance = bal; } 
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
  | None -> (failwith ("Insufficient balance") : ledger)
  | Some new_bal ->
    if new_bal = 0n
    then Big_map.remove owner ledger
    else Map.update owner (Some new_bal) ledger

let transfer (txs, ledger : (transfer_descriptor list) * ledger) : ledger =
  let make_transfer = fun (l, tx : ledger * transfer_descriptor) ->
    let l1 = match tx.from_ with
    | None -> l
    | Some from_ -> dec_balance (from_, tx.amount, l) 
    in
    let l2 = match tx.to_ with
    | None -> l1
    | Some to_ -> inc_balance (to_, tx.amount, l1)
    in
    l2 
  in
    
  List.fold make_transfer txs ledger

let validate_operator_tokens (tokens : operator_tokens) : unit =
  match tokens with
  | All_tokens -> unit
  | Some_tokens ts ->
    if Set.size ts <> 1n
    then failwith "Only 0n token_id is accepted"
    else 
      (if Set.mem 0n ts
      then unit
      else failwith "Only 0n token_id is accepted")

let validate_token_ids (tokens : token_id list) : unit =
  match tokens with
  | tid :: tail -> 
    if List.size tail <> 0n
    then failwith "Only 0n token_id is accepted"
    else 
    (if tid = 0n
    then unit
    else failwith "Only 0n token_id is accepted"
    )
  | [] -> failwith "No token_id provided"

let update_operators (params, storage : (update_operator list) * operators)
    : operators =
  List.fold
    (fun (s, up : operators * update_operator) ->
      match up with
      | Add_operator op -> 
        let u = validate_operator_tokens op.tokens in
        let key = op.owner, op.operator in
        Big_map.update key (Some true) s

      | Remove_operator op -> 
        let u = validate_operator_tokens op.tokens in
        let key = op.owner, op.operator in
        Big_map.remove key s
    ) params storage 

let fa2_main (param, storage : fa2_entry_points * single_token_storage)
    : (operation  list) * single_token_storage =
  match param with
  | Transfer txs -> 
    let tx_descriptors = transfers_to_descriptors txs in
    let u = validate_operator (tx_descriptors, storage.permissions_descriptor.self, storage.operators) in
    let new_ledger = transfer (tx_descriptors, storage.ledger) in
    let new_storage = { storage with ledger = new_ledger; }
    in ([] : operation list), new_storage

  | Balance_of p -> 
    let op = get_balance (p, storage.ledger) in
    [op], storage

  | Total_supply p ->
    let u = validate_token_ids p.token_ids in
    let response = { token_id = 0n; total_supply = storage.total_supply; } in
    let op = Operation.transaction [response] 0mutez p.callback in
    [op], storage

  | Token_metadata p ->
    let u = validate_token_ids p.token_ids in
    let op = Operation.transaction [storage.metadata] 0mutez p.callback in
    [op], storage

  | Permissions_descriptor callback ->
    let op = Operation.transaction storage.permissions_descriptor 0mutez callback in
    [op], storage

  | Update_operators updates ->
    let new_ops = update_operators (updates, storage.operators) in
    let new_storage = { storage with operators = new_ops; } in
    ([] : operation list), new_storage

  | Is_operator p ->
    let u = validate_operator_tokens p.operator.tokens in
    let key = p.operator.owner, p.operator.operator in
    let is_op_opt = Big_map.find_opt key storage.operators in
    let is_op = match is_op_opt with
    | None -> false
    | Some o -> o
    in 
    let resp = { operator = p.operator; is_operator = is_op; } in
    let op = Operation.transaction resp 0mutez p.callback in
    [op], storage

