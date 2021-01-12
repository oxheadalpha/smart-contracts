(*
A simple token owner which works with FA2 instance and supports operators permission policy
and can manage its own operators.
 *)

#include "../fa2/fa2_interface.mligo"

type owner_operator_param = {
  fa2 : address;
  operator : address;
  token_id : token_id;
}

type token_owner =
  | Owner_add_operator of owner_operator_param
  | Owner_remove_operator of owner_operator_param
  | Default of unit

let token_owner_main (param, s : token_owner * unit) 
    : (operation list) * unit =
  match param with

  | Owner_add_operator p ->
    (* calls specified FA2 contract to add operator *)
    let param : operator_param = {
      operator = p.operator;
      owner = Current.self_address;
      token_id = p.token_id;
    } in
    let fa2_update : update_operator list contract option =
      Tezos.get_entrypoint_opt "%update_operators" p.fa2 in
    let update_op = match fa2_update with
    | None -> (failwith "NO_UPDATE_OPERATORS" : operation)
    | Some entry -> Tezos.transaction [Add_operator param] 0mutez entry in
    [update_op], unit

  | Owner_remove_operator p ->
    (* calls specified FA2 contract to remove operator *)
    let param : operator_param = {
      operator = p.operator;
      owner = Current.self_address;
      token_id = p.token_id;
    } in
    let fa2_update : update_operator list contract option =
      Tezos.get_entrypoint_opt "%update_operators" p.fa2 in
    let update_op = match fa2_update with
    | None -> (failwith "NO_UPDATE_OPERATORS" : operation)
    | Some entry -> Tezos.transaction [Remove_operator param] 0mutez entry in
    [update_op], unit

  | Default u -> ([] : operation list), unit
  