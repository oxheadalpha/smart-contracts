#include "fa2_interface.mligo"

let permissions_descriptor_to_michelson (d : permissions_descriptor)
    : permissions_descriptor_michelson =
  let aux : permissions_descriptor_aux = {
    operator = Layout.convert_to_right_comb d.operator;
    receiver = Layout.convert_to_right_comb d.receiver;
    sender = Layout.convert_to_right_comb d.sender;
    custom = match d.custom with
    | None -> (None : custom_permission_policy_michelson option)
    | Some c -> Some (Layout.convert_to_right_comb c)
  } in
  Layout.convert_to_right_comb aux

let transfer_descriptor_param_to_michelson (p : transfer_descriptor_param)
    : transfer_descriptor_param_michelson =
  let aux : transfer_descriptor_param_aux = {
    fa2 = p.fa2;
    operator = p.operator;
    batch = List.map 
      (fun (td: transfer_descriptor) -> Layout.convert_to_right_comb td) 
      p.batch;
  } in
  Layout.convert_to_right_comb aux

let transfer_descriptor_param_from_michelson (p : transfer_descriptor_param_michelson)
    : transfer_descriptor_param =
  let aux : transfer_descriptor_param_aux = Layout.convert_from_right_comb p in
  let b : transfer_descriptor list = List.map 
      (fun (tdm : transfer_descriptor_michelson) -> 
        let td : transfer_descriptor = Layout.convert_from_right_comb tdm in
        td
      )
      aux.batch
  in
  {
    fa2 = aux.fa2;
    operator = aux.operator;
    batch = b;
  }

let transfers_from_michelson (txsm : transfer_michelson list) : transfer list =
  List.map 
    (fun (txm: transfer_michelson) ->
      let tx : transfer = Layout.convert_from_right_comb txm in
      tx
    ) txsm

let operator_param_from_michelson (p : operator_param_michelson) : operator_param =
  let aux : operator_param_aux = Layout.convert_from_right_comb p in
  let tokens : operator_tokens = Layout.convert_from_right_comb aux.tokens in
  {
    owner = aux.owner;
    operator = aux.operator;
    tokens = tokens;
  }

let operator_param_to_michelson (p : operator_param) : operator_param_michelson =
  let aux : operator_param_aux = {
    owner = p.owner;
    operator = p.operator;
    tokens = Layout.convert_to_right_comb p.tokens;
  } in
  Layout.convert_to_right_comb aux

let operator_update_from_michelson (uom : update_operator_michelson) : update_operator =
    let aux : update_operator_aux = Layout.convert_from_right_comb uom in
    match aux with
    | Add_operator opm -> Add_operator_p (operator_param_from_michelson opm)
    | Remove_operator opm -> Remove_operator_p (operator_param_from_michelson opm)

(* check this *)
let operator_updates_from_michelson (updates_michelson : update_operator_michelson list)
    : update_operator list =
  List.map operator_update_from_michelson updates_michelson

let is_operator_param_from_michelson (p : is_operator_param_michelson) : is_operator_param =
  let aux : is_operator_param_aux = Layout.convert_from_right_comb p in
  {
    operator = operator_param_from_michelson aux.operator;
    callback = aux.callback;
  }

let is_operator_response_to_michelson (r : is_operator_response) : is_operator_response_michelson =
  let aux : is_operator_response_aux = {
    operator = operator_param_to_michelson r.operator;
    is_operator = r.is_operator;
  } in
  Layout.convert_to_right_comb aux

let balance_of_param_from_michelson (p : balance_of_param_michelson) : balance_of_param =
  let aux : balance_of_param_aux = Layout.convert_from_right_comb p in
  let requests = List.map 
    (fun (rm : balance_of_request_michelson) ->
      let r : balance_of_request = Layout.convert_from_right_comb rm in
      r
    )
    aux.requests 
  in
  {
    requests = requests;
    callback = aux.callback;
  } 

let balance_of_response_to_michelson (r : balance_of_response) : balance_of_response_michelson =
  let aux : balance_of_response_aux = {
    request = Layout.convert_to_right_comb r.request;
    balance = r.balance;
  } in
  Layout.convert_to_right_comb aux

let total_supply_responses_to_michelson (rs : total_supply_response list)
    : total_supply_response_michelson list =
  List.map
    (fun (r : total_supply_response) ->
      let rm : total_supply_response_michelson = Layout.convert_to_right_comb r in
      rm
    ) rs

let token_metas_to_michelson (ms : token_metadata list) : token_metadata_michelson list =
  List.map
    ( fun (m : token_metadata) ->
      let mm : token_metadata_michelson = Layout.convert_to_right_comb m in
      mm
    ) ms
