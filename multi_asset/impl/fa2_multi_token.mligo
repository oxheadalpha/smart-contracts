#include "../fa2_hook.mligo"

(* (owner,token_id) -> balance *)
type ledger = ((address*nat), nat) big_map

type token_info = {
  metadata : token_metadata;
  total_supply : nat;
}
(* token_id -> metadata *)
type token_storage = (nat, token_info) big_map

type operator_tokens_entry =
  | All_operator_tokens
  | Some_operator_tokens of token_id set
  | All_operator_tokens_except of token_id set

(*  (owner, operator) -> tokens *)
type operator_storage = ((address * address), operator_tokens_entry) big_map

type multi_token_storage = {
  hook : set_hook_param option;
  ledger : ledger;
  tokens : token_storage;
  operators : operator_storage;
}

let add_tokens (existing_ts, ts_to_add : (operator_tokens_entry option) * (token_id set))
    : operator_tokens_entry =
  match existing_ts with
  | None -> Some_operator_tokens ts_to_add
  | Some ets -> (
    match ets with
    | All_operator_tokens -> All_operator_tokens
    | Some_operator_tokens ets -> 
      (* merge sets *)
      let new_ts = Set.fold 
        (fun (acc, tid : (token_id set) * token_id) -> Set.add tid acc)
        ts_to_add ets in
      Some_operator_tokens new_ts
    | All_operator_tokens_except ets ->
      (* subtract sets *)
      let new_ts = Set.fold 
        (fun (acc, tid : (token_id set) * token_id) -> Set.remove tid acc)
        ts_to_add ets in
      if (Set.size new_ts) = 0n 
      then All_operator_tokens 
      else All_operator_tokens_except new_ts
  )

let add_operator (op, storage : operator_param * operator_storage) : operator_storage =
  let key = op.owner, op.operator in
  let new_tokens = match op.tokens with
  | All_tokens -> All_operator_tokens
  | Some_tokens ts_to_add ->
      let existing_tokens = Big_map.find_opt key storage in
      add_tokens (existing_tokens, ts_to_add)
  in
  Big_map.update key (Some new_tokens) storage

let remove_tokens (existing_ts, ts_to_remove : (operator_tokens_entry option) * (token_id set))
    : operator_tokens_entry option =
  match existing_ts with
  | None -> (None : operator_tokens_entry option)
  | Some ets -> (
    match ets with
    | All_operator_tokens -> Some (All_operator_tokens_except ts_to_remove)
    | Some_operator_tokens ets ->
      (* subtract sets *)
      let new_ts = Set.fold 
        (fun (acc, tid : (token_id set) * token_id) -> Set.remove tid acc)
        ts_to_remove ets in
      if (Set.size new_ts) = 0n
      then (None : operator_tokens_entry option)
      else Some (Some_operator_tokens new_ts)
    | All_operator_tokens_except ets ->
       (* merge sets *)
      let new_ts = Set.fold 
        (fun (acc, tid : (token_id set) * token_id) -> Set.add tid acc)
        ts_to_remove ets in
      Some (All_operator_tokens_except new_ts)
  )

let remove_operator (op, storage : operator_param * operator_storage) : operator_storage =
  match op.tokens with
  | All_tokens -> storage
  | Some_tokens ts_to_remove ->
    let key = op.owner, op.operator in
    let existing_tokens = Big_map.find_opt key storage in
    let new_tokens_opt = remove_tokens (existing_tokens, ts_to_remove) in
    Big_map.update key new_tokens_opt storage  

let are_tokens_included (existing_tokens, ts : operator_tokens_entry * operator_tokens) : bool =
  match existing_tokens with
  | All_operator_tokens -> true
  | Some_operator_tokens ets -> (
    match ts with
    | All_tokens -> false
    | Some_tokens ots ->
      (* all ots tokens must be in ets set*)
      Set.fold (fun (res, ti : bool * token_id) ->
        if (Set.mem ti ets) then res else false
      ) ots true
  )
  | All_operator_tokens_except ets -> (
    match ts with 
    | All_tokens -> false
    | Some_tokens ots ->
      (* None of the its tokens must be in ets *)
      Set.fold (fun (res, ti : bool * token_id) ->
          if (Set.mem ti ets) then false else res
      ) ots true
  )

let is_operator_impl (p, storage : operator_param * operator_storage) : bool = 
  let key = p.owner, p.operator in
  let op_tokens = Big_map.find_opt key storage in
  match op_tokens with
  | None -> false
  | Some existing_tokens -> are_tokens_included (existing_tokens, p.tokens)
    
let update_operators (params, storage : (update_operator list) * operator_storage)
    : operator_storage =
  List.fold
    (fun (s, up : operator_storage * update_operator) ->
      match up with
      | Add_operator op -> add_operator (op, s)
      | Remove_operator op -> remove_operator (op, s)
    ) params storage

let is_operator (param, storage :  is_operator_param * operator_storage) : operation =
  let is_op = is_operator_impl (param.operator, storage) in 
  let r : is_operator_response = { 
    operator = param.operator;
    is_operator = is_op; 
  } in
  Operation.transaction r 0mutez param.callback

type owner_to_tokens = (address, (token_id set)) map

let validate_operator (txs, self, ops_storage 
    : (transfer list) * self_transfer_policy * operator_storage) : unit =
  let can_self_tx = match self with
  | Self_transfer_permitted -> true
  | Self_transfer_denied -> false
  in
  let operator = Current.sender in
  let tokens_by_owner = List.fold
    (fun (owners, tx : owner_to_tokens * transfer) ->
      let tokens = Map.find_opt tx.from_ owners in
      let new_tokens = match tokens with
      | None -> Set.literal [tx.token_id]
      | Some ts -> Set.add tx.token_id ts
      in
      Map.update tx.from_ (Some new_tokens) owners
    ) txs (Map.empty : owner_to_tokens) in

  Map.iter
    (fun (owner, tokens : address * (token_id set)) ->
      if can_self_tx && owner = operator
      then unit
      else
        let oparam : operator_param = {
          owner = owner;
          operator = sender;
          tokens = Some_tokens tokens;
        } in
        let is_op = is_operator_impl (oparam, ops_storage) in
        if is_op then unit else failwith "not permitted operator"
    ) tokens_by_owner

let get_hook (storage : set_hook_param option) : set_hook_param =
 match storage with
 | None -> (failwith "transfer hook is not set" : set_hook_param)
 | Some h -> h

let transfers_to_hook_param (txs : transfer list) : hook_param =
  let batch : transfer_descriptor list = 
    List.map 
      (fun (tx : transfer) ->
        {
          from_ = Some tx.from_;
          to_ = Some tx.to_;
          token_id = tx.token_id;
          amount = tx.amount;
        }) 
      txs in
    {
      batch = batch;
      operator = Current.sender;
      fa2 = Current.self_address;
    } 

let permit_transfer (txs, storage : (transfer list) * multi_token_storage) : operation =
  let hook = get_hook storage.hook in
  let u = validate_operator (txs, hook.permissions_descriptor.self, storage.operators) in
  let hook_param = transfers_to_hook_param txs in
  let hook_contract = hook.hook unit in
  Operation.transaction hook_param 0mutez hook_contract

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
  | None -> (failwith ("Insufficient balance") : ledger)
  | Some new_bal ->
    if new_bal = 0n
    then Big_map.remove key ledger
    else Map.update key (Some new_bal) ledger

let transfer (txs, ledger : (transfer list) * ledger) : ledger =
  let make_transfer = fun (l, tx : ledger * transfer) ->
    let l1 = dec_balance (tx.from_, tx.token_id, tx.amount, l) in
    let l2 = inc_balance (tx.to_, tx.token_id, tx.amount, l1) in
    l2 
  in
    
  List.fold make_transfer txs ledger

let get_balance (p, ledger : balance_param * ledger) : operation =
  let to_balance = fun (r : balance_request) ->
    let key = r.owner, r.token_id in
    let bal = get_balance_amt (key, ledger) in
    { request = r; balance = bal; } 
  in
  let responses = List.map to_balance p.requests in
  Operation.transaction responses 0mutez p.callback

let get_total_supply (p, tokens : total_supply_param * token_storage) : operation =
  let get_response = fun (tid : token_id) ->
    let info = Big_map.find_opt tid tokens in
    match info with
    | None -> (failwith "token id not found" : total_supply_response)
    | Some i -> { token_id = tid; total_supply = i.total_supply; }
  in
  let responses = List.map get_response p.token_ids in
  Operation.transaction responses 0mutez p.callback

let get_metadata (p, tokens : token_metadata_param * token_storage) : operation =
  let get_meta = fun (tid : token_id) ->
    let info = Big_map.find_opt tid tokens in
    match info with
    | None -> (failwith "token id not found" : token_metadata)
    | Some i -> i.metadata
  in
  let metas = List.map get_meta p.token_ids in
  Operation.transaction metas 0mutez p.callback

let fa2_main (param, storage : fa2_entry_points * multi_token_storage)
    : (operation  list) * multi_token_storage =
  match param with
  | Transfer txs -> 
    (* let op = permit_transfer (txs, storage) in
    let new_ledger = transfer (txs, storage.ledger) in
    let new_storage = { storage with ledger = new_ledger; }
    in [op], new_storage *)
    ([] : operation list), storage

  | Balance p -> 
    let op = get_balance (p, storage.ledger) in
    [op], storage

  | Total_supply p -> 
    let op = get_total_supply (p, storage.tokens) in
    [op], storage

  | Token_metadata p -> 
    let op = get_metadata (p, storage.tokens) in
    [op], storage

  | Permissions_descriptor callback ->
    let hook = get_hook storage.hook in
    let op = Operation.transaction hook.permissions_descriptor 0mutez callback in
    [op], storage

  | Update_operators updates ->
    let new_ops = update_operators (updates, storage.operators) in
    let new_storage = { storage with operators = new_ops; } in
    ([] : operation list), new_storage

  | Is_operator p -> 
    let op = is_operator (p, storage.operators) in
    [op], storage

let multi_token_main (param, s : fa2_with_hook_entry_points * multi_token_storage)
    : (operation  list) * multi_token_storage =
  match param with
  | Set_transfer_hook h -> ([] : operation list), { s with hook = Some h; }
  | Fa2 fa2 -> fa2_main (fa2, s)
