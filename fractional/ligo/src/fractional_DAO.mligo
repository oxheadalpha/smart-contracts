#if ! FRACTIONAL_DAO

#define FRACTIONAL_DAO

#include "../fa2/fa2_interface.mligo"
#include "../fa2_modules/simple_admin.mligo"
#include "fa2_multi_token_mligo"


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
  ownership : ownership_state list;
  voting_threshold : nat;
  expiration : timestamp;
}

type nft_ownership = {
  voting_threshold : nat;
  expiration : timestamp;
  ownership_token : token_id;
}

type ownership = (global_token_id, nft_ownership) big_map;

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

type pending_votes = (transfer_votes_key, transfer_votes) big_map;


type dao_storage = {
  ownership_tokens : multi_token_storage;
  next_ownership_token_id : nat;
  admin : simple_admin_storage;
  vote_nonce : nat;
  owned_nfts : ownership;
  pending_votes : pending_votes;
}

type dao_entrypoints =
  | Fa2 of fa2_entrypoints (* handling ownership FA2 fungible tokens *)
  | Set_ownership of set_ownership_param
  | Vote_transfer of vote_transfer_param
  | Admin of simple_admin

let dao_main (p, s : dao_entrypoints, dao_storage) : operation list * dao_storage =
  match p with
  | Fa2 fa2 -> 
    let u = fail_if_paused s.admin in
    let ops, new_ownership = fa2_main(p, s.ownership_tokens)
    ops, { s with ownership_tokens = new_ownership; }

  | Set_ownership op ->
    let u = fail_if_not_admin s.admin in
    let new_s = set_ownership(op, s) in
    ([] : operation list), new_s

  | Vote_transfer vp ->
    let new_s = vote_transfer(vp, s) in
    ([] : operation list), new_s

  | Admin ap -> 
    let ops, new_admin = simple_admin (ap, s.admin) in
    ops, { s with admin = new_admin; }

#endif
