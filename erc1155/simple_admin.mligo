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

type simple_admin_context = {
  admin_storage : simple_admin_storage;
  balance_storage : balance_storage;
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

let mint_tokens (param : mint_tokens_param) (s : simple_admin_context) : (operation list) * simple_admin_context =
  (([] : operation list) , s)

let burn_tokens (param : mint_tokens_param) (s : simple_admin_context) : (operation list) * simple_admin_context =
  (([] : operation list) , s)

let simple_admin (param : simple_admin) (ctx : simple_admin_context) : (operation list) * simple_admin_context =
  if sender <> ctx.admin_storage.admin
  then (failwith "operation require admin priveleges" : (operation list) * simple_admin_context)
  else //(([] : operation list), ctx)
    match param with
      | Set_admin new_admin ->
          let new_admin_s = set_admin new_admin ctx.admin_storage in
          let new_ctx = {
            admin_storage = new_admin_s;
            balance_storage = ctx.balance_storage;
          } in
          (([]: operation list), new_ctx)

      | Pause paused ->
          let new_admin_s = pause paused ctx.admin_storage in
          let new_ctx = {
            admin_storage = new_admin_s;
            balance_storage = ctx.balance_storage;
          } in
          (([]: operation list), new_ctx)

      | Create_token param ->
          let new_admin_s = create_token param ctx.admin_storage in
          let new_ctx = {
            admin_storage = new_admin_s;
            balance_storage = ctx.balance_storage;
          } in
          (([]: operation list), new_ctx)

      | Mint_tokens param -> mint_tokens param ctx

      | Burn_tokens param -> burn_tokens param ctx
    


let admin_test (p : unit) = unit