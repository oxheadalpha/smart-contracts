#include "../lib/fa2_convertors.mligo"

type storage =
  | State of balance_of_response
  | Empty

type query_param = {
  fa2 : address;
  owner : address;
}

type param =
  | Query of query_param
  | Response of balance_of_response_michelson list
  | Default of unit

let main (p, s : param * storage) : (operation list) * storage =
  match p with

  | Query q ->
    let br : balance_of_request = {
      owner = q.owner;
      token_id = 0n;
    } in
    let aux : balance_of_param_aux = {
      requests = [ Layout.convert_to_right_comb br ];
      callback =
        (Operation.get_entrypoint "%response" Current.self_address :
          (balance_of_response_michelson list) contract);
    } in
    let bpm = Layout.convert_to_right_comb aux in
    let fa2 : balance_of_param_michelson contract = 
      Operation.get_entrypoint "%balance_of" q.fa2 in
    let q_op = Operation.transaction bpm 0mutez fa2 in
    [q_op], s

  | Response r_michelson ->
    let new_s = 
      match r_michelson with 
      | [] -> (failwith "invalid response" : balance_of_response)
      | b :: tl -> balance_of_response_from_michelson b
    in
    ([] : operation list), State new_s

  | Default u -> ([] : operation list), s
