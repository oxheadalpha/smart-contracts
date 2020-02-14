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
  descriptor : token_descriptor;
}

type mint_burn_tx = {
  owner : address;
  token_id : token_id;
  amount : nat;
}

type mint_burn_tokens_param = mint_burn_tx list


(* `token_manager` entry points *)
type token_manager =
  | Create_token of create_token_param
  | Mint_tokens of mint_burn_tokens_param
  | Burn_tokens of mint_burn_tokens_param


let create_token 
    (param, tokens : create_token_param * token_storage) : token_storage =
  let token_info = Map.find_opt param.token_id tokens in
  match token_info with
  | Some ti -> (failwith "token already exists" : token_storage)
  | None ->
      let ti = {
        descriptor = param.descriptor;
        total_supply = 0n;
      } in
      Map.add param.token_id ti tokens

let burn_param_to_hook_param (ts : mint_burn_tx list) : hook_param =
  let batch : hook_transfer list = List.map 
    (fun (t : mint_burn_tx) -> {
        from_ = Some t.owner;
        to_ = (None : address option);
        token_id = t.token_id;
        amount = t.amount;
      })
    ts in 
  {
    batch = batch;
    operator = Current.sender;
  }

let mint_param_to_hook_param (ts : mint_burn_tx list) : hook_param =
  let batch : hook_transfer list = List.map 
    (fun (t : mint_burn_tx) -> 
      {
        to_ = Some t.owner;
        from_ = (None : address option);
        token_id = t.token_id;
        amount = t.amount;
      })
    ts in 
  {
    batch = batch;
    operator = Current.sender;
  }

let  mint_update_balances (txs, b : (mint_burn_tx list) * balance_storage) : balance_storage =
  let mint = fun (b, tx : balance_storage * mint_burn_tx) ->
    inc_balance (tx.owner, tx.token_id, tx.amount, b) in

  List.fold mint txs b

let mint_update_total_supply (txs, tokens : (mint_burn_tx list) * token_storage) : token_storage =
  let update = fun (tokens, tx : token_storage * mint_burn_tx) ->
    let tid = get_internal_token_id tx.token_id in
    let tio = Big_map.find_opt tid tokens in
    match tio with
    | None -> (failwith "token id not found" : token_storage)
    | Some ti ->
      let new_s = ti.total_supply + tx.amount in
      let new_ti = { ti with total_supply = new_s } in
      Big_map.update tid (Some new_ti) tokens in

  List.fold update txs tokens

let mint_tokens (param, s : mint_burn_tokens_param * multi_token_storage) 
    : (operation list) * multi_token_storage =
    let hp = mint_param_to_hook_param param in
    let op = permit_transfer (hp, s) in
    let new_bal = mint_update_balances (param, s.balance_storage) in
    let new_tokens = mint_update_total_supply (param, s.token_storage) in
    let new_s = { s with
      balance_storage = new_bal;
      token_storage = new_tokens;
    } in
    ([op], new_s)

let burn_update_balances(txs, b : (mint_burn_tx list) * balance_storage) : balance_storage =
  let burn = fun (b, tx : balance_storage * mint_burn_tx) ->
    dec_balance (tx.owner, tx.token_id, tx.amount, b) in

  List.fold burn txs b

let burn_update_total_supply (txs, tokens : (mint_burn_tx list) * token_storage) : token_storage =
  let update = fun (tokens, tx : token_storage * mint_burn_tx) ->
    let tid = get_internal_token_id tx.token_id in
    let tio = Big_map.find_opt tid tokens in
    match tio with
    | None -> (failwith "token id not found" : token_storage)
    | Some ti ->
      let new_s = (match Michelson.is_nat (ti.total_supply - tx.amount) with
      | None -> (failwith "total supply is less than zero" : nat)
      | Some s -> s)
      in
      let new_ti = { ti with total_supply = new_s } in
      Big_map.update tid (Some new_ti) tokens in

  List.fold update txs tokens

let burn_tokens (param, s : mint_burn_tokens_param * multi_token_storage) 
    : (operation list) * multi_token_storage =
    let hp = burn_param_to_hook_param param in
    let op = permit_transfer (hp, s) in
    let new_bal = burn_update_balances (param, s.balance_storage) in
    let new_tokens = burn_update_total_supply (param, s.token_storage) in
    let new_s = { s with
      balance_storage = new_bal;
      token_storage = new_tokens;
    } in
    ([op], new_s)

let token_manager (param, s : token_manager * multi_token_storage)
    : (operation list) * multi_token_storage =
  match param with

  | Create_token param ->
      let new_tokens = create_token (param, s.token_storage) in
      let new_s = { s with token_storage = new_tokens } in
      (([]: operation list), new_s)

  | Mint_tokens param -> mint_tokens (param, s)

  | Burn_tokens param -> burn_tokens (param, s)

