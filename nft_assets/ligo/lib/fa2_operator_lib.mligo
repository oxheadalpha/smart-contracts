(** Reference implementation of the FA2 operator storage and config API functions *)
#if !FA2_OPERATOR_LIB
#define FA2_OPERATOR_LIB

#include "fa2_convertors.mligo"
#include "../fa2_errors.mligo"

(*  (owner, operator) -> unit *)
type operator_storage = ((address * address), unit) big_map

    
let update_operators (update, storage : update_operator * operator_storage)
    : operator_storage =
  match update with
  | Add_operator_p op -> 
    Big_map.update (op.owner, op.operator) (Some unit) storage
  | Remove_operator_p op -> 
    Big_map.remove (op.owner, op.operator) storage

let validate_update_operators_by_owner (update, updater : update_operator * address)
    : unit =
  let op = match update with
  | Add_operator_p op -> op
  | Remove_operator_p op -> op
  in
  if op.owner = updater then unit else failwith not_owner


let is_operator (param, storage :  is_operator_param * operator_storage) : operation =
  let op_key = (param.operator.owner, param.operator.operator) in
  let is_op = Big_map.mem op_key storage in 
  let r : is_operator_response = { 
    operator = param.operator;
    is_operator = is_op; 
  } in
  let rm = is_operator_response_to_michelson r in
  Operation.transaction rm 0mutez param.callback

let make_operator_validator (tx_policy : operator_transfer_policy)
    : (address * operator_storage)-> unit =
  let can_owner_tx, can_operator_tx = match tx_policy with
  | No_transfer -> (failwith tx_denied : bool * bool)
  | Owner_transfer -> true, false
  | Owner_or_operator_transfer -> true, true
  in
  let operator : address = Tezos.sender in
  (fun (owner, ops_storage : address * operator_storage) ->
      if can_owner_tx && owner = operator
      then unit
      else
        if not can_operator_tx
        then failwith not_owner
        else
          if Big_map.mem  (owner, operator) ops_storage
          then unit else failwith not_operator
  )

(** validate operators for all transfers in the batch at once*)
let validate_operator (tx_policy, txs, ops_storage 
    : operator_transfer_policy * (transfer list) * operator_storage) : unit =
  let validator = make_operator_validator tx_policy in
  List.iter (fun (tx : transfer) -> validator (tx.from_, ops_storage)) txs

#endif
