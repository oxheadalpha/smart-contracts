#if ! FRACTIONAL_DAO

#define FRACTIONAL_DAO

#include "../fa2/fa2_interface.mligo"
#include "../fa2_modules/simple_admin.mligo"
#include "fa2_multi_token.mligo"


type permit = {
  key : key; (* user's key *)
  signature : signature; (*signature of packed transfer_vote parameter + permit context *)
}

type global_token_id = 
[@layout:comb]
{
  fa2 : address;
  token_id : token_id;
}

type transfer_vote =
[@layout:comb]
{
  nft_token : global_token_id;
  to_ : address;
  voter : address; (* part of a collective from_ represented by the DAO address *)
}

type vote_transfer_param =
[@layout:comb]
{
  vote : transfer_vote;
  permit : permit option;
}

(* permit context:
Tezos.chain_id,
Tezos.self_address,
storage.vote_nonce,
*)

type ownership_stake =
[@layout:comb]
{
  owner : address;
  amount : nat; (* amount of the ownership token representing an ownership stake*)
}

type set_ownership_param =
[@layout:comb]
{
  nft_token : global_token_id;
  ownership : ownership_stake list;
  voting_threshold : nat;
  voting_period : nat;
}

type nft_ownership = {
  voting_threshold : nat;
  voting_period : nat;
  ownership_token : token_id;
}

type ownership = (global_token_id, nft_ownership) big_map

type transfer_votes = {
  to_ : address;
  vote_amount : nat;
  voters : address set;
}

type transfer_votes_key =
[@layout:comb]
{
  vote_nonce : nat;
  nft_token : global_token_id;
}

type pending_votes = (transfer_votes_key, transfer_votes) big_map

type dao_storage = {
  ownership_tokens : multi_token_storage;
  next_ownership_token_id : nat;
  admin : simple_admin_storage;
  vote_nonce : nat;
  owned_nfts : ownership;
  pending_votes : pending_votes;
  metadata : contract_metadata;
}

let mint_ownership_token (ownership, token_id, s : 
    ownership_stake list * token_id * multi_token_storage) : multi_token_storage =
  let meta = { 
    token_id = token_id;
    extras = Map.literal [
    ("symbol", Bytes.pack "OT");
    ("name", Bytes.pack "Ownership Token");
    ("decimals", Bytes.pack "0");
  ]; } in
  let new_token_meta = Big_map.add token_id meta s.token_metadata in
  
  let new_ledger, token_supply = List.fold 
    (fun (acc, ownership : (ledger * nat) * ownership_stake ) ->
      let ledger, supply = acc in
      let new_ledger = 
        Big_map.add (ownership.owner, token_id) ownership.amount ledger in
      let new_supply = supply + ownership.amount in
      (new_ledger, new_supply)
    ) ownership (s.ledger, 0n) in

  let new_supply = Big_map.add token_id token_supply s.token_total_supply in
  { s with
    token_metadata = new_token_meta;
    ledger = new_ledger;
    token_total_supply = new_supply;
  }

let set_ownership (p, s : set_ownership_param * dao_storage) : dao_storage =
  if Big_map.mem p.nft_token s.owned_nfts
  then (failwith "DUP_OWNERSHIP" : dao_storage)
  else
    let token_ownership = {
      voting_threshold = p.voting_threshold;
      voting_period = p.voting_period;
      ownership_token = s.next_ownership_token_id;
    } in
    let new_nfts = Big_map.add p.nft_token token_ownership s.owned_nfts in
    let new_otokens = mint_ownership_token 
      (p.ownership, s.next_ownership_token_id, s.ownership_tokens) in
    { s with 
      owned_nfts = new_nfts;
      next_ownership_token_id = s.next_ownership_token_id + 1n;
      ownership_tokens = new_otokens;
    }

let vote_transfer (p, s : vote_transfer_param * dao_storage)
    : operation list * dao_storage =
  ([] : operation list), s

type dao_entrypoints =
  | Fa2 of fa2_entry_points (* handling ownership FA2 fungible tokens *)
  | Set_ownership of set_ownership_param
  | Vote_transfer of vote_transfer_param
  | Admin of simple_admin

let dao_main (p, s : dao_entrypoints * dao_storage) : operation list * dao_storage =
  match p with
  | Fa2 fa2 -> 
    let u = fail_if_paused s.admin in
    let ops, new_ownership = fa2_main(fa2, s.ownership_tokens) in
    ops, { s with ownership_tokens = new_ownership; }

  | Set_ownership op ->
    let u = fail_if_not_admin s.admin in
    let new_s = set_ownership(op, s) in
    ([] : operation list), new_s

  | Vote_transfer vp ->
    let ops, new_s = vote_transfer(vp, s) in
    ops, new_s

  | Admin ap -> 
    let ops, new_admin = simple_admin (ap, s.admin) in
    ops, { s with admin = new_admin; }

#endif
