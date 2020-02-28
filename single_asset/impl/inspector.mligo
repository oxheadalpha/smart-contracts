include "../fa2_interface.mligo"

type state = {
  owner : address;
  token_id: nat;
  balance : nat;
}

type storage =
  | State of state
  | Empty

type query_param = {
  mac : address;
  token_id: nat;
  owner : address;
}

type assert_is_operator_param = {
  mac : address;
  request : operator_param;
}

type param =
  | Query of query_param
  | Response of balance_response list
  | Assert_is_operator of assert_is_operator_param
  | Is_operator_response of is_operator_response list
  | Default of unit

let main (p, s : param * storage) : (operation list) * (state option) =
  match p with

  | Query q ->
    let br : balance_request = {
      owner = q.owner;
      token_id = q.token_id;
    } in
    let bp : balance_of_param = {
      balance_requests = [ br ];
      balance_view =
        (Operation.get_entrypoint "%response" Current.self_address :
          ((balance_request * nat) list) contract);
    } in
    let mac : balance_of_param contract = 
      Operation.get_entrypoint "%balance_of" q.mac in
    let q_op = Operation.transaction bp 0mutez mac in
    [q_op], s

  | Response r ->
    let new_s = 
      match r with 
      | b :: tl ->
        {
          owner = b.0.owner;
          token_id = b.0.token_id;
          balance = b.1;
        }
      | [] -> (failwith "invalid response" : state)
    in
    ([] : operation list), State new_s

  | Assert_is_operator p ->
    let mac : is_operator_param contract = Operation.get_entrypoint "%is_operator" p.mac in
    let callback : (is_operator_request * bool) contract =
      Operation.get_entrypoint "%is_operator_response" Current.self_address in
    let pp = {
      is_operator_request = p.request;
      is_operator_view = callback;
    } in
    let op = Operation.transaction pp 0mutez mac in
    [op], s

  | Is_operator_response r -> let u = if r.1
    then unit
    else failwith "not an operator response" in
    ([] : operation list), s

  | Default u -> ([] : operation list), s