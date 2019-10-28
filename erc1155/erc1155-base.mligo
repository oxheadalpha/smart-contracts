#include "erc1155.mligo"

(*  owner -> operator set *)
type approvals = (address, address set) big_map

let set_approval_for_all (approvals: approvals) (param: set_approval_for_all_param) : approvals =
  let operators = match Map.find_opt sender approvals with
    | Some(ops) -> ops
    | None      -> (Set.empty : address set)
  in
  let new_operators = 
    if param.approved
    then Set.add param.operator operators
    else Set.remove param.operator operators
  in
    if Set.size new_operators = 0p
    then  Map.remove sender approvals
    else Map.update sender (Some new_operators) approvals
  

let is_approved_for_all (approvals: approvals) (param: is_approved_for_all_param) : operation = 
  let req = param.is_approved_for_all_request in
  let operators = Map.find_opt req.owner approvals in
  let result = match operators with
    | None      -> false
    | Some ops  -> Set.mem req.operator ops
  in
  param.approved_view (req, result)


let max_tokens = 4294967295p  (* 2^32-1 *)
let owner_offset = 4294967296p  (* 2^32 *)

type balance_storage = {
  owner_count: nat;
  owner_lookup: (address, nat) map; //TODO: change to big_map
  balances: (nat, nat) map;  //TODO: change to big_map
}

(* return updated storage and newly added owner id *)
let add_owner (s: balance_storage) (owner: address) : (balance_storage * nat) =
  let owner_id  = s.owner_count + 1p in
  let ol = Map.add owner owner_id s.owner_lookup in
  let new_s = 
    { (* TODO: use functional record update once supported by LIGO *)
      owner_count = owner_id;
      owner_lookup = ol;
      balances = s.balances;
    } in
  (new_s, owner_id)

(* gets existing owner id. If owner does not have one, creates a new id and adds it to an owner_lookup *)
let ensure_owner_id (s: balance_storage) (owner: address) : (balance_storage * nat) =
  let owner_id = Map.find_opt owner s.owner_lookup in
  match owner_id with
    | Some id -> (s, id)
    | None    -> add_owner s owner

let pack_balance_key  = fun (s: balance_storage) (key: balance_request) ->
  let owner_id = Map.find_opt key.owner s.owner_lookup in
  match owner_id with
    | None    -> (failwith("No such owner") : nat)
    | Some id -> 
        if key.token_id > max_tokens
        then (failwith("provided token ID is out of allowed range") : nat)
        else key.token_id + (id * owner_offset)
 
let get_balance (s: balance_storage) (key: nat) : nat =
  let bal : nat option = Map.find_opt key s.balances in
  match bal with
    | None    -> 0p
    | Some b  -> b

let get_balance_req (s: balance_storage) (r: balance_request) : nat =
  let balance_key = pack_balance_key s r in
  get_balance s balance_key



let balance_of (s: balance_storage) (param: balance_of_param) : operation =
  let bal = get_balance_req s param.balance_request in
  param.balance_view (param.balance_request, bal)



let balance_of_batch (s: balance_storage) (param: balance_of_batch_param)  : operation =
  let to_balance = fun (r: balance_request) ->
    let bal = get_balance_req s r in
    (r, bal) 
  in
  let requests_2_bals = List.map param.balance_request to_balance in
  param.balance_view requests_2_bals
  
// let safe_transfer_from (s: balance_store) (param: safe_transfer_from_param) : (operation  list) * safe_transfer_from_param =
//   let from_key = 
//     owner = param.from;
//     token_id = param.token_id;
//   } in
//   let from_balance = get_balance from_request in
//   if from_balance


let base_test(p: unit) = 42