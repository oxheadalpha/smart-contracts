#include "fa2_interface.mligo"

(* range of nft tokens *)
type token_def = {
  from_ : nat;
  to_ : nat;
}

type nft_meta = (token_def, token_metadata) big_map

type token_storage = {
  token_defs : token_def list; (* reverse order list of defs *)
  metadata : nft_meta;
}

type ledger = (token_id, address) big_map

type operators = ((address * address), bool) big_map

type nft_token_storage = {
  ledger : ledger;
  operators : operators;
  metadata : token_storage;
  permissions_descriptor : permissions_descriptor;
}

let validate_operator (txs, tx_policy, ops_storage 
    : (transfer_descriptor list) * operator_transfer_policy * operators) : unit =
  let can_owner_tx, can_operator_tx = match tx_policy with
  | No_transfer -> (failwith "TX_DENIED" : bool * bool)
  | Owner_transfer -> true, false
  | Owner_or_operator_transfer -> true, true
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
      if can_owner_tx && owner = operator
      then unit
      else if not can_operator_tx
      then failwith "NOT_OWNER"
      else
          let key = owner, operator in
          let is_op_opt = Big_map.find_opt key ops_storage in
          match is_op_opt with
          | None -> failwith "NOT_OPERATOR"
          | Some o -> unit
    ) owners

let validate_operator_tokens (tokens : operator_tokens) : unit =
  match tokens with
  | All_tokens -> unit
  | Some_tokens ts ->
    if Set.size ts <> 1n
    then failwith "TOKEN_UNDEFINED"
    else 
      (if Set.mem 0n ts
      then unit
      else failwith "TOKEN_UNDEFINED")

let get_supply (tokens, ledger : (token_id list) * ledger )
    : total_supply_response list =
  List.map (fun (tid: token_id) ->
    if Big_map.mem tid ledger
    then  { token_id = tid; total_supply = 1n; }
    else (failwith "TOKEN_UNDEFINED" : total_supply_response)
  ) tokens

let find_token_type (tid, token_defs : token_id * (token_def list)) : token_def =
  let tdef = List.fold (fun (res, d : (token_def option) * token_def) ->
    match res with
    | Some r -> res
    | None ->
      if tid >= d.from_ && tid < d.to_
      then  Some d
      else (None : token_def option)
  ) token_defs (None : token_def option)
  in
  match tdef with
  | None -> (failwith "TOKEN_UNDEFINED" : token_def)
  | Some d -> d

let get_metadata (tokens, meta : (token_id list) * token_storage )
    : token_metadata list =
  List.map (fun (tid: token_id) ->
    let ttype = find_token_type (tid, meta.token_defs) in
    let meta = Big_map.find_opt ttype meta.metadata in
    match meta with
    | Some m -> m
    | None -> (failwith "NO_DATA" : token_metadata)
  ) tokens

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

let fa2_main (param, storage : fa2_entry_points * nft_token_storage)
    : (operation  list) * nft_token_storage =
  match param with
  | Transfer txs -> 
    (* let tx_descriptors = transfers_to_descriptors txs in
    let u = validate_operator 
      (tx_descriptors, storage.permissions_descriptor.operator, storage.operators) in
    let new_ledger = transfer (tx_descriptors, storage.ledger) in
    let new_storage = { storage with ledger = new_ledger; }
    in ([] : operation list), new_storage *)
    ([] : operation list), storage

  | Balance_of p -> 
    (* let op = get_balance (p, storage.ledger) in
    [op], storage *)
    ([] : operation list), storage


  | Total_supply p ->
    let supplies = get_supply (p.token_ids, storage.ledger) in    
    let op = Operation.transaction supplies 0mutez p.callback in
    [op], storage

  | Token_metadata p ->
    let metas = get_metadata (p.token_ids, storage.metadata) in
    let op = Operation.transaction metas 0mutez p.callback in
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