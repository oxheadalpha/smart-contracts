

(*
  One of the possible implementations of token management API which can create
  new fungible tokens, mint and burn them.
  
  Token manager API allows to:

  1. Create new toke types,
  2. Mint and burn tokens to some existing or new owner account.

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

(* `token_manager` entry points *)
type token_manager =
  | Create_token of create_token_param
  | Mint_tokens of mint_tokens_param
  | Burn_tokens of burn_tokens_param

(* token_id -> descriptor *)
type token_storage = (nat, string) big_map

type token_manager_context = {
  tokens : token_storage;
  balances : balance_storage;
}


let create_token 
    (param : create_token_param) (tokens: token_storage) : token_storage =
  let token : string option = Map.find_opt param.token_id tokens in
  match token with
  | Some d -> (failwith "token already exists" : token_storage)
  | None -> Map.add param.token_id param.descriptor tokens
   

let token_exists (token_id : nat) (tokens : token_storage) : unit =
  let d = Map.find_opt token_id tokens in
  match d with  
  | None ->   failwith("token does not exist")
  | Some d -> unit

let mint_tokens_impl
    (param : mint_tokens_param) (owner_id : nat) (tokens : token_storage) 
    (b : balances) : balances =

  let make_transfer = fun (bals: balances) (t: tx) ->
    let u : unit = token_exists t.token_id tokens in
    let to_key  = make_balance_key_impl owner_id t.token_id in
    let old_bal = get_balance to_key bals in
    Map.update to_key (Some(old_bal + t.amount)) bals in

  List.fold make_transfer param.batch b

let mint_safe_check (param : mint_tokens_param) (is_owner_implicit : bool) : operation list =
  if is_owner_implicit
  then ([] : operation list)
  else
    let receiver : multi_token_receiver contract =
      Operation.get_entrypoint "%multi_token_receiver" param.owner in
    let p : on_multi_tokens_received_param = {
      operator = sender;
      from_ = (None : address option);
      batch = param.batch;
      data = param.data;
    } in
    let op = Operation.transaction (On_multi_tokens_received p) 0mutez receiver in
    [op] 

let mint_tokens 
    (param : mint_tokens_param) (tokens : token_storage) 
    (b : balance_storage) : (operation list) * balance_storage =
  let owner = ensure_owner_id param.owner b.owners in
  let ops = mint_safe_check param owner.owner.is_implicit in
  let new_bals = mint_tokens_impl param owner.owner.id tokens b.balances in
  let new_s = {
    owners = owner.owners;
    balances = new_bals;
  } in 
  (ops, new_s)

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
    match Michelson.is_nat ( old_bal - t.amount ) with
    | None -> (failwith("Insufficient funds") : balances)
    | Some new_bal -> 
        if new_bal = 0n
        then Map.remove from_key bals
        else Map.update from_key (Some new_bal) bals
    in

  let new_bals = List.fold make_burn param.batch s.balances in
  {
    owners = s.owners;
    balances = new_bals;
  } 

let token_manager (param : token_manager) (ctx : token_manager_context)
    : (operation list) * token_manager_context =
  match param with

  | Create_token param ->
      let new_tokens = create_token param ctx.tokens in
      let new_ctx = {
        tokens = new_tokens;
        balances = ctx.balances;
      } in
      (([]: operation list), new_ctx)

  | Mint_tokens param -> 
      let ops_new_bals  = mint_tokens param ctx.tokens ctx.balances in
      let new_ctx = {
        tokens = ctx.tokens;
        balances = ops_new_bals.1;
      } in
      (ops_new_bals.0, new_ctx)

  | Burn_tokens param ->
      let new_bals = burn_tokens param ctx.balances in
      let new_ctx = {
        tokens = ctx.tokens;
        balances = new_bals;
      } in
      (([] : operation list), new_ctx)
