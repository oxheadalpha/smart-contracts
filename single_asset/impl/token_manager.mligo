(*
  One of the possible implementations of token management API which can create
  new fungible tokens, mint and burn them.
  
  Token manager API allows to mint and burn tokens to some existing or new owner account.

  Mint operation performs safety check as specified for `multi_token`
  transfer entry points. Burn operation fails if the owner holds
  less tokens then burn amount.
*)

#include "../fa2_single_token.mligo"

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
        to_ = (None : address option);
        token_id = 0n;
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
        token_id = 0n;
        amount = t.amount;
      })
    ts in 
  {
    batch = batch;
    operator = Current.sender;
    fa2 = Current.self_address;
  }

let get_total_supply_change (txs : mint_burn_tx list) : nat =
  List.fold (fun (total, tx : nat * mint_burn_tx) -> total + tx.amount) txs 0n

let mint_tokens (txs, storage : mint_burn_tokens_param * single_token_storage) 
    : (operation list) * multi_token_storage =
    let hook = get_hook storage.hook in
    let hook_contract = hook.hook unit in
    let hp = mint_param_to_hook_param txs in
    let op = Operation.transaction hp 0mutez hook_contract in

    let new_ledger = transfer (hp.batch, storage.ledger) in
    let supply_change = get_total_supply_change txs in
    let new_s = { storage with
      ledger = new_ledger;
      total_supply = storage.total_supply + supply_change;
    } in
    ([op], new_s)

    
let burn_tokens (txs, storage : mint_burn_tokens_param * single_token_storage) 
    : (operation list) * single_token_storage =
    let hook = get_hook storage.hook in
    let hcontract = hook.hook unit in
    let hp = burn_param_to_hook_param txs in
    let op = Operation.transaction hp 0mutez hcontract in

    let new_ledger = transfer (hp.batch, storage.ledger) in
    let supply_change = get_total_supply_change txs in
    let new_supply_opt = Michelson.is_nat (storage.total_supply - supply_change) in
    let new_supply = match new_supply_opt with
    | None -> (failwith "total supply is negative" : nat)
    | Some s -> s
    in
    let new_s = { storage with
      ledger = new_ledger;
      total_supply = new_supply;
    } in
    ([op], new_s)

let token_manager (param, s : token_manager * single_token_storage)
    : (operation list) * single_token_storage =
  match param with
  | Mint_tokens txs -> mint_tokens (txs, s)
  | Burn_tokens txs -> burn_tokens (txs, s)
