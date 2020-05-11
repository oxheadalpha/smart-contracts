(* #include "../fa2_interface.mligo" *)
#include "../fa2_convertors.mligo"

type storage =
  | State of balance_of_response
  | Empty

type query_param = {
  fa2 : address;
  owner : address;
  token_id : token_id;
}

type assert_is_operator_param = {
  fa2 : address;
  request : operator_param;
}

type param =
  | Query of query_param
  | Response of balance_of_response_michelson list
  | Assert_is_operator of assert_is_operator_param
  | Is_operator_response of is_operator_response
  | Default of unit

let main (p, s : param * storage) : (operation list) * storage =
  match p with

  | Query q ->
    let br : balance_of_request = {
      owner = q.owner;
      token_id = q.token_id;
    } in
    let bp : balance_of_param = {
      requests = [ br ];
      callback =
        (Operation.get_entrypoint "%response" Current.self_address :
          (balance_of_response_michelson list) contract);
    } in
    let bpm = balance_of_param_to_michelson bp in
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
    (* let fa2 : is_operator_param contract = Operation.get_entrypoint "%is_operator" p.fa2 in
    let callback : is_operator_response contract =
      Operation.get_entrypoint "%is_operator_response" Current.self_address in
    let pp : is_operator_param = {
      operator = p.request;
      callback = callback;
    } in
    let op = Operation.transaction pp 0mutez fa2 in
    [op], s *)
    ([] : operation list), s

  | Is_operator_response r ->
    (* let u = if r.is_operator
      then unit else failwith "not an operator response" in
    ([] : operation list), s *)
    ([] : operation list), s

  | Default u -> ([] : operation list), s
