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

module TokenOwner = struct

  type return = operation list * unit

  (** calls specified FA2 contract to add operator *)
  [@entry] let owner_add_operator (p : owner_operator_param) (_ : unit) : return =
    let param : operator_param = {
      operator = p.operator;
      owner = Tezos.get_self_address ();
      token_id = p.token_id;
    } in
    let fa2_update : update_operator list contract option =
      Tezos.get_entrypoint_opt "%update_operators" p.fa2 in
    let update_op = match fa2_update with
    | None -> (failwith "NO_UPDATE_OPERATORS" : operation)
    | Some entry -> Tezos.transaction [Add_operator param] 0mutez entry in
    [update_op], ()

  (** calls specified FA2 contract to remove operator *)
  [@entry] let owner_remove_operator (p : owner_operator_param) (_ : unit) : return =
    let param : operator_param = {
      operator = p.operator;
      owner = Tezos.get_self_address ();
      token_id = p.token_id;
    } in
    let fa2_update : update_operator list contract option =
      Tezos.get_entrypoint_opt "%update_operators" p.fa2 in
    let update_op = match fa2_update with
    | None -> (failwith "NO_UPDATE_OPERATORS" : operation)
    | Some entry -> Tezos.transaction [Remove_operator param] 0mutez entry in
    [update_op], ()

  [@entry] let default (_ : unit) (_ : unit) : return = ([] : operation list), ()

end
