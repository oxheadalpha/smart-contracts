(** Reference implementation of the FA2 operator storage and config API functions *)

#include "fa2_convertors.mligo"

(*  (owner, operator) -> unit *)
type operator_storage = ((address * address), unit) big_map

    
let update_operators (params, storage : (update_operator list) * operator_storage)
    : operator_storage =
  List.fold
    (fun (s, up : operator_storage * update_operator) ->
      match up with
      | Add_operator_p op -> 
        Big_map.update (op.owner, op.operator) (Some unit) s
      | Remove_operator_p op -> 
        Big_map.remove (op.owner, op.operator) s
    ) params storage


let is_operator (param, storage :  is_operator_param * operator_storage) : operation =
  let op_key = (param.operator.owner, param.operator.operator) in
  let is_op = Big_map.mem op_key storage in 
  let r : is_operator_response = { 
    operator = param.operator;
    is_operator = is_op; 
  } in
  let rm = is_operator_response_to_michelson r in
  Operation.transaction rm 0mutez param.callback

let validate_operator (tx_policy, txs, ops_storage 
    : operator_transfer_policy * (transfer list) * operator_storage) : unit =
  let can_owner_tx, can_operator_tx = match tx_policy with
  | No_transfer -> (failwith "TX_DENIED" : bool * bool)
  | Owner_transfer -> true, false
  | Owner_or_operator_transfer -> true, true
  in
  let operator = Current.sender in
  List.iter
    (fun (tx : transfer) ->
      if can_owner_tx && tx.from_ = operator
      then unit
      else if not can_operator_tx
      then failwith "NOT_OWNER"
      else
        if Big_map.mem (tx.from_, operator) ops_storage
        then unit else failwith "NOT_OPERATOR"
    ) txs
