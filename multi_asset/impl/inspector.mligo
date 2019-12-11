#include "../multi_token_interface.mligo"

type state = {
  owner : address;
  token_id: nat;
  balance : nat;
}

type storage =
  | State of state
  | Empty of unit

type query_param = {
  mac : address;
  token_id: nat;
  owner : address;
}


type param =
  | Query of query_param
  | Response of (balance_request * nat) list
  | Default of unit

let main (p : param) ( s : storage) : (operation list) * (state option) =
  match p with

  | Query q ->
    let br : balance_request = {
      owner = q.owner;
      token_id = q.token_id;
    } in
    let bp : balance_of_param = {
      balance_request = [ br ];
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

  | Default u -> ([] : operation list), s