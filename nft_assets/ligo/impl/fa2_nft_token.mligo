#if !FA2_NFT_TOKEN
#define FA2_NFT_TOKEN

#include "../fa2_interface.mligo"
#include "../fa2_errors.mligo"
#include "../lib/fa2_operator_lib.mligo"

(* range of nft tokens *)
type token_def = {
  from_ : nat;
  to_ : nat;
}

type nft_meta = (token_def, token_metadata) big_map

type token_storage = {
  token_defs : token_def set;
  last_used_id : token_id;
  metadata : nft_meta;
}

type ledger = (token_id, address) big_map

type nft_token_storage = {
  ledger : ledger;
  operators : operator_storage;
  metadata : token_storage;
  permissions_descriptor : permissions_descriptor;
}

let get_balance (p, ledger : balance_of_param * ledger) : operation =
  let to_balance = fun (r : balance_of_request) ->
    let owner = Big_map.find_opt r.token_id ledger in
    let response = match owner with
    | None -> (failwith token_undefined : balance_of_response)
    | Some o ->
      let bal = if o = r.owner then 1n else 0n in
      { request = r; balance = bal; }
    in
    balance_of_response_to_michelson response
  in
  let responses = List.map to_balance p.requests in
  Operation.transaction responses 0mutez p.callback

let transfer (txs, owner_validator, ops_storage, ledger
    : (transfer list) * ((address * operator_storage) -> unit) * operator_storage * ledger) : ledger =
  let make_transfer = (fun (l, tx : ledger * transfer) ->
    let u = owner_validator (tx.from_, ops_storage) in
    List.fold 
      (fun (ll, dst : ledger * transfer_destination) ->
        if dst.amount = 0n
        then ll
        else if dst.amount <> 1n
        then (failwith insufficient_balance : ledger)
        else
          let owner = Big_map.find_opt dst.token_id ll in
          match owner with
          | None -> (failwith token_undefined : ledger)
          | Some o -> 
            if o <> tx.from_
            then (failwith insufficient_balance : ledger)
            else Big_map.update dst.token_id (Some dst.to_) ll
      ) tx.txs l
  )
  in 
    
  List.fold make_transfer txs ledger


let get_supply (tokens, ledger : (token_id list) * ledger )
    : total_supply_response list =
  List.map (fun (tid: token_id) ->
    if Big_map.mem tid ledger
    then  { token_id = tid; total_supply = 1n; }
    else (failwith token_undefined : total_supply_response)
  ) tokens

let find_token_type (tid, token_defs : token_id * (token_def set)) : token_def =
  let tdef = Set.fold (fun (res, d : (token_def option) * token_def) ->
    match res with
    | Some r -> res
    | None ->
      if tid >= d.from_ && tid < d.to_
      then  Some d
      else (None : token_def option)
  ) token_defs (None : token_def option)
  in
  match tdef with
  | None -> (failwith token_undefined : token_def)
  | Some d -> d

let get_metadata (tokens, meta : (token_id list) * token_storage )
    : token_metadata list =
  List.map (fun (tid: token_id) ->
    let ttype = find_token_type (tid, meta.token_defs) in
    let meta = Big_map.find_opt ttype meta.metadata in
    match meta with
    | Some m -> { m with token_id = tid; }
    | None -> (failwith "NO_DATA" : token_metadata)
  ) tokens

let fa2_main (param, storage : fa2_entry_points * nft_token_storage)
    : (operation  list) * nft_token_storage =
  match param with
  | Transfer txs_michelson ->
    let txs = transfers_from_michelson txs_michelson in
    let validator = make_operator_validator storage.permissions_descriptor.operator in
    let new_ledger = transfer (txs, validator, storage.operators, storage.ledger) in
    let new_storage = { storage with ledger = new_ledger; }
    in ([] : operation list), new_storage

  | Balance_of pm ->
    let p = balance_of_param_from_michelson pm in
    let op = get_balance (p, storage.ledger) in
    [op], storage

  | Total_supply pm ->
    let p : total_supply_param = Layout.convert_from_right_comb pm in
    let supplies = get_supply (p.token_ids, storage.ledger) in
    let supplies_michelson = total_supply_responses_to_michelson supplies in
    let op = Operation.transaction supplies_michelson 0mutez p.callback in
    [op], storage

  | Token_metadata pm ->
    let p : token_metadata_param = Layout.convert_from_right_comb pm in
    let metas = get_metadata (p.token_ids, storage.metadata) in
    let metas_michelson = token_metas_to_michelson metas in
    let op = Operation.transaction metas_michelson 0mutez p.callback in
    [op], storage

  | Permissions_descriptor callback ->
    let descriptor_michelson = permissions_descriptor_to_michelson storage.permissions_descriptor in
    let op = Operation.transaction descriptor_michelson 0mutez callback in
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

let test (u : unit) = unit
#endif