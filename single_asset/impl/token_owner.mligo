(*
A simple token owner which works with FA2 instance which supports operators permission policy
and can manage its own operators.
 *)

#include "../fa2_convertors.mligo"

type owner_operator_param = {
  fa2 : address;
  operator : address;
}

type token_owner =
  | Owner_add_operator of owner_operator_param
  | Owner_remove_operator of owner_operator_param
  | Default of unit

let main (param, s : token_owner * unit) 
    : (operation list) * unit =
  match param with

  | Owner_add_operator p ->
    let param : operator_param = {
      operator = p.operator;
      owner = Current.self_address;
    } in
    let param_michelson = operator_update_to_michelson (Add_operator_p param) in
    let fa2_update : (update_operator_michelson list) contract =
      Operation.get_entrypoint "%update_operators" p.fa2 in
    let update_op = Operation.transaction [param_michelson] 0mutez fa2_update in
    [update_op], unit

  | Owner_remove_operator p ->
    let param : operator_param = {
      operator = p.operator;
      owner = Current.self_address;
    } in
    let param_michelson = operator_update_to_michelson (Remove_operator_p param) in
    let fa2_update : (update_operator_michelson list) contract =
      Operation.get_entrypoint "%update_operators" p.fa2 in
    let update_op = Operation.transaction [param_michelson] 0mutez fa2_update in
    [update_op], unit

  | Default u -> ([] : operation list), unit
  