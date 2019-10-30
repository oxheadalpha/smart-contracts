#include "erc1155-base.mligo"

type create_token_param = {
  token_id : nat;
  descriptor : string;
}

type mint_tokens_param = {
  token_id : nat;
  owner : address;
  amount : nat;
}

type burn_tokens_param = {
  token_id : nat;
  owner : address;
  amount : nat;
}

type simple_admin =
  | Set_admin of address
  | Pause of bool
  | Create_token of create_token_param
  | Mint_tokens of mint_tokens_param
  | Burn_tokens of burn_tokens_param


type simple_admin_storage = {
  admin : address;
  paused : bool;
  (* token_id -> descriptor *)
  tokens : (nat, string) map;
}

let set_admin (new_admin: address) (s: simple_admin_storage) : simple_admin_storage =
  {
    admin = new_admin;
    paused = s.paused;
    tokens = s.tokens;
  }

let pause (paused : bool) (s: simple_admin_storage) : simple_admin_storage =
  {
    admin = s.admin;
    paused = paused;
    tokens = s.tokens;
  }

let create_token (param : create_token_param) (s: simple_admin_storage) : simple_admin_storage =
  let token : string option = Map.find_opt param.token_id s.tokens in
  match token with
    | Some d -> (failwith "token already exists" : simple_admin_storage)
    | None -> 
      let new_tokens = Map.add param.token_id param.descriptor s.tokens in
      {
        admin = s.admin;
        paused = s.paused;
        tokens = new_tokens;
      }


let simple_admin (param : simple_admin) (s : simple_admin_storage) (b : balance_storage) : (operation list) * simple_admin_storage =
  if sender <> s.admin
  then (failwith "operation require admin priveleges" : (operation list) * simple_admin_storage)
  else
    // match param with
    (([]: operation list), s)


let admin_test (p : unit) = unit