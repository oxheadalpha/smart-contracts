(*
  One of the possible implementations of token management API which can create
  mint and burn non-fungible tokens.
  
  Mint operation creates a new type of NFTs and assign them to owner accounts.
  Burn operation removes existing NFT type and removes its tokens from owner
  accounts.
*)

#if !TOKEN_MANAGER
#define TOKEN_MANAGER

#include "fa2_nft_token.mligo"

type mint_param =
[@layout:comb]
{
  token_def : token_def;
  metadata : token_metadata;
  owners : address list;
}


(* `token_manager` entry points *)
type token_manager =
  | Mint_tokens of mint_param
  | Burn_tokens of token_def


let validate_mint_param (p : mint_param) : unit =
  let num_tokens = is_nat (p.token_def.to_ - p.token_def.from_) in
  match num_tokens with
  | None -> failwith "EMPTY_TOKEN_DEF_RANGE"
  | Some n -> if n <> List.size p.owners then failwith "INVALID_OWNERS_LENGTH" else unit

type zip_acc = {
  zip : (address * token_id ) list;
  next_token : token_id;
}
let zip_owners_with_token_ids (owners, from_token_id : (address list) * token_id) :
    (address * token_id ) list =
  let res = List.fold 
    ( fun (acc, owner : zip_acc * address) ->
      {
        zip = (owner, acc.next_token) :: acc.zip;
        next_token = acc.next_token + 1n;
      }
    ) 
    owners 
    { 
      zip = ([] : (address * token_id) list); 
      next_token = from_token_id; 
    }
  in
  res.zip

let mint_tokens (p, s : mint_param * nft_token_storage) : nft_token_storage =
  let u = validate_mint_param p in
  if s.metadata.next_token_id > p.token_def.from_
  then (failwith "USED_TOKEN_IDS" : nft_token_storage)
  else
    let new_metadata = {
      token_defs = Set.add p.token_def s.metadata.token_defs;
      metadata = Big_map.add p.token_def p.metadata s.metadata.metadata;
      next_token_id = p.token_def.to_;
    } in
    let tid_owners = zip_owners_with_token_ids (p.owners, p.token_def.from_) in
    let new_ledger = List.fold (fun (l, owner_id : ledger * (address * token_id)) ->
      let owner, tid = owner_id in
      Big_map.add tid owner l
    ) tid_owners s.ledger in
    { s with 
      metadata = new_metadata;
      ledger = new_ledger;
    }


type aux_remove_tokens = {
  from_ : token_id;
  to_ : token_id;
  ledger : ledger;
}

let rec remove_tokens (p : aux_remove_tokens) : aux_remove_tokens =
  if p.from_ = p.to_
  then p
  else
    let new_p = {
        from_ = p.from_ + 1n;
        to_ = p.to_;
        ledger = Big_map.remove p.from_ p.ledger;
    } in
    remove_tokens new_p

let burn_tokens (p, s : token_def * nft_token_storage) : nft_token_storage =
  if not Set.mem p s.metadata.token_defs
  then (failwith "INVALID_PARAM" : nft_token_storage)
  else
    let new_metadata = { s.metadata with
      token_defs = Set.remove p s.metadata.token_defs;
      metadata = Big_map.remove p s.metadata.metadata;
    } in
    let new_ledger = remove_tokens {
      from_ = p.from_; 
      to_ = p.to_; 
      ledger = s.ledger; 
    } in
    { s with
      metadata = new_metadata;
      ledger = new_ledger.ledger;
    }

let token_manager (param, s : token_manager * nft_token_storage)
    : (operation list) * nft_token_storage =
  let new_s = match param with
  | Mint_tokens p -> mint_tokens (p, s)
  | Burn_tokens p -> burn_tokens (p, s)
  in
  ([] : operation list), new_s

#endif
