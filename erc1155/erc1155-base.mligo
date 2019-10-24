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

type balance_key = {
  owner: address;
  token_id: nat;
}
let max_tokens = 4294967295p  (* 2^32-1 *)
let owner_offset = 4294967296p  (* 2^32 *)

type balance_storage = {
  owner_count: nat;
  owner_lookup: (address, nat) big_map;
  balances: (nat, nat) big_map;
}

let pack_balance_key_impl (owner_id: nat) (token_id: nat) : nat =
  if token_id > max_tokens
  then (failwith("provided token ID is out of allowed range") : nat)
  else token_id + (owner_id * owner_offset)

let pack_balance_key (s: balance_storage) (key: balance_key) : nat option =
  let owner_id = Map.find_opt key.owner s.owner_lookup in
  match owner_id with
    | None    -> (None: nat option)
    | Some id -> 
        let packed = pack_balance_key_impl id key.token_id in 
        Some(packed)
 
let pack_balance_key_force (s: balance_storage) (key: balance_key) : balance_storage * nat =
  (s, 1p)


let base_test(p: unit) = 42