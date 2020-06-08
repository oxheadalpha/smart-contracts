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


let burn_param_to_hook_param (ts : mint_burn_tx list) : transfer_descriptor_param =
  let batch : transfer_descriptor list = List.map 
    (fun (t : mint_burn_tx) -> {
        from_ = Some t.owner;
        txs = [{
          to_ = (None : address option);
          token_id = 0n;
          amount = t.amount;
        }];
      })
    ts in 
  {
    batch = batch;
    operator = Current.sender;
  }

let mint_param_to_hook_param (ts : mint_burn_tx list) : transfer_descriptor_param =
  let batch : transfer_descriptor list = List.map 
    (fun (t : mint_burn_tx) -> 
      {
        from_ = (None : address option);
        txs = [{
          to_ = Some t.owner;
          token_id = 0n;
          amount = t.amount;
        }];
      })
    ts in 
  {
    batch = batch;
    operator = Current.sender;
  }

let get_total_supply_change (txs : mint_burn_tx list) : nat =
  List.fold (fun (total, tx : nat * mint_burn_tx) -> total + tx.amount) txs 0n

let noop_owner_validator = fun (p : address * operator_storage) -> unit

let mint_tokens (txs, storage : mint_burn_tokens_param * single_token_storage) 
    : (operation list) * single_token_storage =
    let hp = mint_param_to_hook_param txs in
    let new_ledger = transfer 
      (hp.batch, noop_owner_validator, storage.operators, storage.ledger) in
    let supply_change = get_total_supply_change txs in
    let new_s = { storage with
      ledger = new_ledger;
      total_supply = storage.total_supply + supply_change;
    } in
    ([] : operation list), new_s

    
let burn_tokens (txs, storage : mint_burn_tokens_param * single_token_storage) 
    : (operation list) * single_token_storage =
    let hp = burn_param_to_hook_param txs in
    let new_ledger = transfer 
      (hp.batch, noop_owner_validator, storage.operators, storage.ledger) in
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