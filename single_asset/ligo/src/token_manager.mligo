(*
  
  Token manager API allows to mint and burn tokens to some existing or new owner account.

  Burn operation fails if the owner holds
  less tokens then burn amount.
*)

#if !TOKEN_MANAGER
#define TOKEN_MANAGER

#include "fa2_single_token.mligo"

type mint_burn_tx =
[@layout:comb]
{
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

let mint_params_to_descriptors(txs : mint_burn_tokens_param)
    : transfer_descriptor list = 
  let param_to_destination = fun (p : mint_burn_tx) -> {
        to_ = Some p.owner;
        token_id = 0n;
        amount = p.amount;
      }
  in
  let destinations : transfer_destination_descriptor list = 
    List.map param_to_destination txs in
  [{
    from_ = (None : address option);
    txs = destinations;
  }]

let burn_params_to_descriptors(txs : mint_burn_tokens_param)
    : transfer_descriptor list =
  let param_to_descriptor = fun (p : mint_burn_tx) -> {
      from_ = Some p.owner;
      txs = [{
        to_ = (None : address option);
        token_id = 0n;
        amount = p.amount;
      }]
    } in
  List.map param_to_descriptor txs

let mint_tokens (txs, storage : mint_burn_tokens_param * single_token_storage) 
    : (operation list) * single_token_storage =
  let tx_descriptors = mint_params_to_descriptors txs in
  let nop_operator_validator = 
    fun (p : address * address * token_id * operator_storage) -> unit in
  let ops, new_s1 = fa2_transfer (tx_descriptors, nop_operator_validator, storage) in 

  let supply_change = get_total_supply_change txs in
  let new_s2 = { new_s1 with
    total_supply = storage.total_supply + supply_change;
  } in

  ops, new_s2
  
let burn_tokens (txs, storage : mint_burn_tokens_param * single_token_storage) 
    : (operation list) * single_token_storage =
  let tx_descriptors = burn_params_to_descriptors txs in
  let nop_operator_validator = 
    fun (p : address * address * token_id * operator_storage) -> unit in
  let ops, new_s1 = fa2_transfer (tx_descriptors, nop_operator_validator, storage) in 

  let supply_change = get_total_supply_change txs in
  let new_supply_opt = Michelson.is_nat (storage.total_supply - supply_change) in
  let new_supply = match new_supply_opt with
  | None -> (failwith fa2_insufficient_balance : nat)
  | Some s -> s
  in
  let new_s2 = { new_s1 with
    total_supply = new_supply;
  } in
  ops, new_s2

let token_manager (param, s : token_manager * single_token_storage)
    : (operation list) * single_token_storage =
  match param with
  | Mint_tokens txs -> mint_tokens (txs, s)
  | Burn_tokens txs -> burn_tokens (txs, s)

#endif