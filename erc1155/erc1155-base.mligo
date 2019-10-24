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

let base_test(p: unit) = 42