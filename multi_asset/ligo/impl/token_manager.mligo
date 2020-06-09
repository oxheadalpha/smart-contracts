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

#include "fa2_multi_token.mligo"

type create_token_param = {
  token_id : nat;
  metadata : token_metadata;
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
        metadata = param.metadata;
        total_supply = 0n;
      } in
      Big_map.add param.token_id ti tokens

let burn_param_to_hook_param (ts : mint_burn_tx list) : transfer_descriptor_param =
  let batch : transfer_descriptor list = List.map 
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
    fa2 = Current.self_address;
  }

let mint_param_to_hook_param (ts : mint_burn_tx list) : transfer_descriptor_param =
  let batch : transfer_descriptor list = List.map 
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
    fa2 = Current.self_address;
  }

let  mint_update_balances (txs, ledger : (mint_burn_tx list) * ledger) : ledger =
  let mint = fun (l, tx : ledger * mint_burn_tx) ->
    inc_balance (tx.owner, tx.token_id, tx.amount, l) in

  List.fold mint txs ledger

let mint_update_total_supply (txs, tokens : (mint_burn_tx list) * token_storage) : token_storage =
  let update = fun (tokens, tx : token_storage * mint_burn_tx) ->
    let info_opt = Big_map.find_opt tx.token_id tokens in
    match info_opt with
    | None -> (failwith "token id not found" : token_storage)
    | Some ti ->
      let new_s = ti.total_supply + tx.amount in
      let new_ti = { ti with total_supply = new_s } in
      Big_map.update tx.token_id (Some new_ti) tokens in

  List.fold update txs tokens

let mint_tokens (param, storage : mint_burn_tokens_param * multi_token_storage) 
    : (operation list) * multi_token_storage =
    let hook = get_hook storage.hook in
    let hook_contract = hook.hook unit in
    let hp = mint_param_to_hook_param param in
    let op = Operation.transaction hp 0mutez hook_contract in

    let new_ledger = mint_update_balances (param, storage.ledger) in
    let new_tokens = mint_update_total_supply (param, storage.tokens) in
    let new_s = { storage with
      ledger = new_ledger;
      tokens = new_tokens;
    } in
    ([op], new_s)

let burn_update_balances(txs, ledger : (mint_burn_tx list) * ledger) : ledger =
  let burn = fun (l, tx : ledger * mint_burn_tx) ->
    dec_balance (tx.owner, tx.token_id, tx.amount, l) in

  List.fold burn txs ledger

let burn_update_total_supply (txs, tokens : (mint_burn_tx list) * token_storage) : token_storage =
  let update = fun (tokens, tx : token_storage * mint_burn_tx) ->
    let info_opt = Big_map.find_opt tx.token_id tokens in
    match info_opt with
    | None -> (failwith "token id not found" : token_storage)
    | Some ti ->
      let new_s = (match Michelson.is_nat (ti.total_supply - tx.amount) with
      | None -> (failwith "total supply is less than zero" : nat)
      | Some s -> s)
      in
      let new_ti = { ti with total_supply = new_s } in
      Big_map.update tx.token_id (Some new_ti) tokens in

  List.fold update txs tokens

let burn_tokens (param, storage : mint_burn_tokens_param * multi_token_storage) 
    : (operation list) * multi_token_storage =
    let hook = get_hook storage.hook in
    let hcontract = hook.hook unit in
    let hp = burn_param_to_hook_param param in
    let op = Operation.transaction hp 0mutez hcontract in

    let new_ledger = burn_update_balances (param, storage.ledger) in
    let new_tokens = burn_update_total_supply (param, storage.tokens) in
    let new_s = { storage with
      ledger = new_ledger;
      tokens = new_tokens;
    } in
    ([op], new_s)

let token_manager (param, s : token_manager * multi_token_storage)
    : (operation list) * multi_token_storage =
  match param with

  | Create_token param ->
      let new_tokens = create_token (param, s.tokens) in
      let new_s = { s with tokens = new_tokens } in
      (([]: operation list), new_s)

  | Mint_tokens param -> mint_tokens (param, s)

  | Burn_tokens param -> burn_tokens (param, s)
