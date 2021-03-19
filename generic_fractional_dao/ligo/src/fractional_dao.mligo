#if !FRACTIONAL_DAO
#define FRACTIONAL_DAO

#include "fa2_single_token.mligo"

type permit = 
{
  key : key; (* user's key *)
  signature : signature; (*signature of packed vote_param + permit context *)
}

type proposal_info = {
  vote_amount : nat;
  voters : address set;
  timestamp : timestamp;
  lambda: unit -> operation list
}

type vote_param =
[@layout:comb]
{
  lambda : unit -> operation list;
  permit : permit option;
}

type set_voting_threshold_param = 
(* [@layout: comb] *)
{
  old_threshold: nat;
  new_threshold: nat;
}

type dao_storage = {
  ownership_token : single_token_storage;
  voting_threshold : nat;
  voting_period : nat;
  vote_count : nat;
  pending_proposals: (bytes, vote_param) big_map;
}

type dao_entrypoints =
  | Fa2 of fa2_entry_points
  | Set_voting_threshold of set_voting_threshold_param

[@inline]
let assert_self_call () =
  if Tezos.sender = Tezos.self_address
  then unit
  else failwith "UNVOTED_CALL"

let set_voting_threshold (t, s : set_voting_threshold_param * dao_storage)
    : dao_storage =
  if t.old_threshold <> s.voting_threshold
  then (failwith "INVALID_OLD_THRESHOLD" : dao_storage)
  else if t.new_threshold > s.ownership_token.total_supply
  then (failwith "THRESHOLD_EXCEEDS_TOTAL_SUPPLY" : dao_storage)
  else { s with voting_threshold = t.new_threshold; }

let main(param, storage : dao_entrypoints * dao_storage) 
    : (operation list) * dao_storage =
  match param with
  | Fa2 fa2 -> 
    let ops, new_ownership = fa2_main(fa2, storage.ownership_token) in
    ops, { storage with ownership_token = new_ownership; }

  | Set_voting_threshold t ->
    let u = assert_self_call () in
    let new_storage = set_voting_threshold (t, storage) in
    ([] : operation list), new_storage

#endif