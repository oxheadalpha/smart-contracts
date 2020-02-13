(*
  This is stub implementation of `multi_token_receiver` interface which
  accepts transfer of any token.
*)

#include "../fa2_interface.mligo"

type receiver_operator_param = {
  fa2 : address;
  operator : address;
}

type receiver =
  | Add_operator of receiver_operator_param
  | Remove_operator of receiver_operator_param
  | Continue_config_action of permission_policy_config list
  | Default of unit

type pending_config_action = 
| Nothing_pending
| Pending_add_operator of address
| Pending_remove_operator of address


let get_config_op (fa2: address) (own_address : address) : operation =
  let fa2_get_config : ((permission_policy_config list) contract) contract = 
      Operation.get_entrypoint "%get_permissions_policy" fa2 in
  let continued : (permission_policy_config list) contract =
    Operation.get_entrypoint "%Continue_config_action" own_address in
  Operation.transaction continued 0mutez fa2_get_config

let is_pending_action (a : pending_config_action) : bool =
  match a with
  | Nothing_pending -> false
  | Pending_add_operator o -> true
  | Pending_remove_operator o -> true


let get_operator_config (configs : permission_policy_config list)
    : fa2_operators_config_entry_points contract =
  let f = fun (res, cfg : (address option) * permission_policy_config) -> 
    match cfg with
      | Allowances_config a -> res
      | Operators_config a -> Some a
      | Whitelist_config a -> res
      | Custom_config c -> res
  in
  let op_config = List.fold f configs (None : address option) in
  match op_config with
  | None ->
    (failwith "No operators config for FA2 available" :
    fa2_operators_config_entry_points contract)
  | Some a -> 
    let c : fa2_operators_config_entry_points contract = Operation.get_contract a in
    c

let continue_config_op (configs : permission_policy_config list) 
    (a : pending_config_action) : operation =
  let cfg = get_operator_config configs in
  match a with
  | Nothing_pending -> 
    (failwith "there is no pending config operation to continue" : operation)
  | Pending_add_operator o ->
    let param : operator_param = {
      operator = o;
      owner = Current.self_address;
    } in
    Operation.transaction (Add_operators [param]) 0mutez cfg
  | Pending_remove_operator o ->
      let param : operator_param = {
      operator = o;
      owner = Current.self_address;
    } in
    Operation.transaction (Remove_operators [param]) 0mutez cfg

let main (param, s : receiver * pending_config_action) 
    : (operation list) * pending_config_action =
  match param with

  | Add_operator p ->
    if is_pending_action (s)
    then
      (failwith "pending config action" : (operation list) * pending_config_action)
    else
      let cont_op = get_config_op p.fa2 Current.self_address in
      [cont_op], (Pending_add_operator p.operator)

  | Remove_operator p ->
    if is_pending_action (s)
    then
      (failwith "pending config action" : (operation list) * pending_config_action)
    else
      let cont_op = get_config_op p.fa2 Current.self_address in
      [cont_op], (Pending_remove_operator p.operator)

  | Continue_config_action configs ->
    let op = continue_config_op configs s in
    [op], Nothing_pending

  | Default u -> ([] : operation list), s
  