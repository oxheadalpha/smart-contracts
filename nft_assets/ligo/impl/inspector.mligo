#include "../fa2_convertors.mligo"

type storage =
  | State of balance_of_response
  | Empty

type query_param = {
  fa2 : address;
  request : balance_of_request_michelson;
}

type assert_is_operator_param = {
  fa2 : address;
  request : operator_param_michelson;
}

type param =
  | Query of query_param
  | Response of balance_of_response_michelson list
  | Assert_is_operator of assert_is_operator_param
  | Is_operator_response of is_operator_response_michelson
  | Default of unit

let main (p, s : param * storage) : (operation list) * storage =
  match p with

  | Query q ->
    let aux : balance_of_param_aux = {
      requests = [ q.request ];
      callback =
        (Operation.get_entrypoint "%response" Current.self_address :
          (balance_of_response_michelson list) contract);
    } in
    let bpm = Layout.convert_to_right_comb aux in
    let fa2 : balance_of_param_michelson contract = 
      Operation.get_entrypoint "%balance_of" q.fa2 in
    let q_op = Operation.transaction bpm 0mutez fa2 in
    [q_op], s

  | Response responses_michelson ->
    let responses = List.map
      (fun (rm : balance_of_response_michelson) ->
        balance_of_response_from_michelson rm
      )
      responses_michelson
    in
    let new_s = 
      match responses with 
      | b :: tl -> b
      | [] -> (failwith "invalid response" : balance_of_response)
    in
    ([] : operation list), State new_s

  | Assert_is_operator p ->
    let fa2 : is_operator_param_michelson contract =
      Operation.get_entrypoint "%is_operator" p.fa2 in
    let callback : is_operator_response_michelson contract =
      Operation.get_entrypoint "%is_operator_response" Current.self_address in
    let aux : is_operator_param_aux = {
      operator = p.request;
      callback = callback;
    } in
    let pm : is_operator_param_michelson = Layout.convert_to_right_comb aux in
    let op = Operation.transaction pm 0mutez fa2 in
    [op], s

  | Is_operator_response rm ->
    let r : is_operator_response_aux = Layout.convert_from_right_comb rm in
    let u = if r.is_operator
      then unit else failwith "not an operator response" in
    ([] : operation list), s

  | Default u -> ([] : operation list), s
