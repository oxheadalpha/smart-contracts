(*
  One of the possible implementations of admin API for `multi_token` contract.

  Only current `admin` of the contract can invoke admin API.
  Admin API allows to 
  
    1. Change administrator, 
    2. Create new toke types,
    3. Mint and burn tokens to some existing or new owner account,
    4. pause the contract.

  Mint operation performs safety check as specified for `multi_token`
  transfer entry points. Burn operation fails if the owner holds
  less tokens then burn amount.
*)

#include "multi_token_impl.mligo"

type create_token_param = {
  token_id : nat;
  descriptor : string;
}

type mint_tokens_param = {
  owner : address;
  batch : tx list;
  data : bytes;
}

type burn_tokens_param = {
  owner : address;
  batch : tx list;
}

(* `simple_admin` entry points *)
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
  tokens : (nat, string) big_map;
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

let create_token 
    (param : create_token_param) (s: simple_admin_storage) : simple_admin_storage =
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

let token_exists (token_id : nat) (tokens : (nat, string) big_map) : unit =
  let d = Map.find_opt token_id tokens in
  match d with  
  | None ->   failwith("token does not exist")
  | Some d -> unit

let mint_tokens_impl
    (param : mint_tokens_param) (tokens : (nat, string) big_map) 
    (s : balance_storage) : balance_storage =
  let owner = ensure_owner_id param.owner s.owners in

  let make_transfer = fun (bals: balances) (t: tx) ->
    let u : unit = token_exists t.token_id tokens in
    let to_key  = make_balance_key_impl owner.id t.token_id in
    let old_bal = get_balance to_key bals in
    Map.update to_key (Some(old_bal + t.amount)) bals in

  let new_bals = List.fold param.batch s.balances make_transfer in
  {
    owners = owner.owners;
    balances = new_bals;
  }

let mint_safe_check (param : mint_tokens_param) : operation list =
  let receiver : multi_token_receiver contract =
    Operation.get_contract param.owner in
  let p : on_multi_tokens_received_param = {
    operator = sender;
    from_ = (None : address option);
    batch = param.batch;
    data = param.data;
  } in
  let op = Operation.transaction (On_multi_tokens_received p) 0mutez receiver in
  [op] 

let mint_tokens 
    (param : mint_tokens_param) (a : simple_admin_storage) 
    (b : balance_storage) : (operation list) * balance_storage =
  let new_b = mint_tokens_impl param a.tokens b in
  let ops = mint_safe_check param in
  (ops, new_b)

let burn_tokens
    (param : burn_tokens_param) (s : balance_storage): balance_storage =
  let owner_id = get_owner_id param.owner s.owners in

  let make_burn = fun (bals : balances) (t : tx) ->
    let from_key = make_balance_key_impl owner_id t.token_id in
    let old_bal =  
      match Map.find_opt from_key bals with
      | Some b  -> b
      | None    -> 0n
    in
    if old_bal < t.amount
    then (failwith("Insufficient funds") : balances)
    else
      Map.update from_key (Some(abs(old_bal - t.amount))) bals
    in

  let new_bals = List.fold param.batch s.balances make_burn in
  {
    owners = s.owners;
    balances = new_bals;
  } 

let simple_admin 
    (param : simple_admin) (ctx : simple_admin_context)
    : (operation list) * simple_admin_context =
  if sender <> ctx.admin_storage.admin
  then 
    (failwith "operation requires admin privileges" : (operation list) * simple_admin_context)
  else
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

    | Mint_tokens param -> 
        let ops_new_bals  = mint_tokens param ctx.admin_storage ctx.balance_storage in
        let new_ctx : simple_admin_context = {
          admin_storage = ctx.admin_storage;
          balance_storage = ops_new_bals.1;
        } in
        (ops_new_bals.0, new_ctx)

    | Burn_tokens param ->
        let new_bals = burn_tokens param ctx.balance_storage in
        let new_ctx = {
          admin_storage = ctx.admin_storage;
          balance_storage = new_bals
        } in
        (([] : operation list), new_ctx)
