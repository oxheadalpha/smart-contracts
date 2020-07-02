(*
  
  Token manager API allows to mint and burn tokens to some existing or new owner account.

  Burn operation fails if the owner holds
  less tokens then burn amount.
*)

#if !TOKEN_MANAGER
#define TOKEN_MANAGER

#include "fa2_single_token.mligo"

type mint_burn_tx = {
  owner : address;
  amount : nat;
}

type mint_burn_tokens_param = mint_burn_tx list


(* `token_manager` entry points *)
type token_manager =
  | Mint_tokens of mint_burn_tokens_param
  | Burn_tokens of mint_burn_tokens_param


let get_total_supply_change (txs : mint_burn_tx list) : nat =
  List.fold (fun (total, tx : nat * mint_burn_tx) -> total + tx.amount) txs 0n

let  mint_update_balances (txs, ledger : (mint_burn_tx list) * ledger) : ledger =
  let mint = fun (l, tx : ledger * mint_burn_tx) ->
    inc_balance (tx.owner, tx.amount, l) 
  in

  List.fold mint txs ledger

let mint_tokens (txs, storage : mint_burn_tokens_param * single_token_storage) 
    : (operation list) * single_token_storage =
  let new_ledger = mint_update_balances (txs, storage.ledger) in
  let supply_change = get_total_supply_change txs in
  let new_s = { storage with
    ledger = new_ledger;
    total_supply = storage.total_supply + supply_change;
  } in
  ([] : operation list), new_s

let burn_update_balances(txs, ledger : (mint_burn_tx list) * ledger) : ledger =
  let burn = fun (l, tx : ledger * mint_burn_tx) ->
    dec_balance (tx.owner, tx.amount, l) in

  List.fold burn txs ledger
    
let burn_tokens (txs, storage : mint_burn_tokens_param * single_token_storage) 
    : (operation list) * single_token_storage =
  let new_ledger = burn_update_balances (txs, storage.ledger) in 
  let supply_change = get_total_supply_change txs in
  let new_supply_opt = Michelson.is_nat (storage.total_supply - supply_change) in
  let new_supply = match new_supply_opt with
  | None -> (failwith fa2_insufficient_balance : nat)
  | Some s -> s
  in
  let new_s = { storage with
    ledger = new_ledger;
    total_supply = new_supply;
  } in
  ([] : operation list), new_s

let token_manager (param, s : token_manager * single_token_storage)
    : (operation list) * single_token_storage =
  match param with
  | Mint_tokens txs -> mint_tokens (txs, s)
  | Burn_tokens txs -> burn_tokens (txs, s)

#endif