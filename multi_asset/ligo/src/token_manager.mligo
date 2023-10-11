(*
  One of the possible implementations of token management API which can create
  new fungible tokens, mint and burn them.
  
  Token manager API allows to:

  1. Create new toke types,
  2. Mint and burn tokens to some existing or new owner account.

 Burn operation fails if the owner holds less tokens then burn amount.
*)

#if !TOKEN_MANAGER
#define TOKEN_MANAGER

#include "fa2_multi_token.mligo"

type mint_burn_tx =
[@layout:comb]
{
  owner : address;
  token_id : token_id;
  amount : nat;
}

type mint_burn_tokens_param = mint_burn_tx list


(* `token_manager` entry points *)
type token_manager =
  | Create_token of token_metadata
  | Mint_tokens of mint_burn_tokens_param
  | Burn_tokens of mint_burn_tokens_param


let create_token (metadata, storage
    : token_metadata * MultiToken.storage) : MultiToken.storage =
  (* extract token id *)
  let new_token_id = metadata.token_id in
  let existing_meta = Big_map.find_opt new_token_id storage.token_metadata in
  match existing_meta with
  | Some m -> (failwith "FA2_DUP_TOKEN_ID" : MultiToken.storage)
  | None ->
    let meta = Big_map.add new_token_id metadata storage.token_metadata in
    let supply = Big_map.add new_token_id 0n storage.token_total_supply in
    { storage with
      token_metadata = meta;
      token_total_supply = supply;
    }


let  mint_update_balances (txs, ledger
    : (mint_burn_tx list) * MultiToken.ledger) : MultiToken.ledger =
  let mint = fun (l, tx : MultiToken.ledger * mint_burn_tx) ->
    MultiToken.inc_balance (tx.owner, tx.token_id, tx.amount, l) in

  List.fold mint txs ledger

let mint_update_total_supply (txs, total_supplies
    : (mint_burn_tx list) * MultiToken.token_total_supply)
    : MultiToken.token_total_supply =
  let update = fun (supplies, tx : MultiToken.token_total_supply * mint_burn_tx) ->
    let supply_opt = Big_map.find_opt tx.token_id supplies in
    match supply_opt with
    | None -> (failwith fa2_token_undefined : MultiToken.token_total_supply)
    | Some ts ->
      let new_s = ts + tx.amount in
      Big_map.update tx.token_id (Some new_s) supplies in

  List.fold update txs total_supplies

let mint_tokens (param, storage : mint_burn_tokens_param * MultiToken.storage) 
    : MultiToken.storage =
  let new_ledger = mint_update_balances (param, storage.ledger) in
  let new_supply = mint_update_total_supply (param, storage.token_total_supply) in
  let new_s = { storage with
    ledger = new_ledger;
    token_total_supply = new_supply;
  } in
  new_s

let burn_update_balances(txs, ledger
    : (mint_burn_tx list) * MultiToken.ledger) : MultiToken.ledger =
  let burn = fun (l, tx : MultiToken.ledger * mint_burn_tx) ->
    MultiToken.dec_balance (tx.owner, tx.token_id, tx.amount, l) in

  List.fold burn txs ledger

let burn_update_total_supply (txs, total_supplies
    : (mint_burn_tx list) * MultiToken.token_total_supply)
    : MultiToken.token_total_supply =
  let update = fun (supplies, tx : MultiToken.token_total_supply * mint_burn_tx) ->
    let supply_opt = Big_map.find_opt tx.token_id supplies in
    match supply_opt with
    | None -> (failwith fa2_token_undefined : MultiToken.token_total_supply)
    | Some ts ->
      let new_s = match is_nat (ts - tx.amount) with
      | None -> (failwith fa2_insufficient_balance : nat)
      | Some s -> s
      in
      Big_map.update tx.token_id (Some new_s) supplies in

  List.fold update txs total_supplies

let burn_tokens (param, storage : mint_burn_tokens_param * MultiToken.storage) 
    : MultiToken.storage =

    let new_ledger = burn_update_balances (param, storage.ledger) in
    let new_supply = burn_update_total_supply (param, storage.token_total_supply) in
    let new_s = { storage with
      ledger = new_ledger;
      token_total_supply = new_supply;
    } in
    new_s

let token_manager (param, s : token_manager * MultiToken.storage)
    : (operation list) * MultiToken.storage =
  match param with

  | Create_token token_metadata ->
    let new_s = create_token (token_metadata, s) in
    (([]: operation list), new_s)

  | Mint_tokens param -> 
    let new_s = mint_tokens (param, s) in
    ([] : operation list), new_s

  | Burn_tokens param -> 
    let new_s = burn_tokens (param, s) in
    ([] : operation list), new_s

#endif