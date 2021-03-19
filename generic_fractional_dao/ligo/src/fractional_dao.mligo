#if !FRACTIONAL_DAO
#define FRACTIONAL_DAO

#include "fa2_single_token.mligo"

type permit = 
[@layout:comb]
{
  key : key; (* user's key *)
  signature : signature; (*signature of packed lambda + permit context *)
}

type proposal_info = {
  vote_amount : nat;
  voters : address set;
  timestamp : timestamp;
}

type vote =
[@layout:comb]
{
  lambda : unit -> operation list;
  permit : permit option;
}

type set_voting_threshold_param = 
{
  old_threshold: nat;
  new_threshold: nat;
}

type pending_proposals = (bytes, proposal_info) big_map

type dao_storage = {
  ownership_token : single_token_storage;
  voting_threshold : nat;
  voting_period : nat;
  vote_count : nat;
  pending_proposals: pending_proposals;
}

type dao_entrypoints =
  | Fa2 of fa2_entry_points
  | Set_voting_threshold of set_voting_threshold_param
  | Vote of vote

type return = (operation list) * dao_storage

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

let validate_permit (lambda, permit, vote_count
    : (unit -> operation list) * permit * nat) : address =
    let signed_data = Bytes.pack (
      (Tezos.chain_id, Tezos.self_address),
      (vote_count, lambda)
    ) in
    if  Crypto.check permit.key permit.signature signed_data 
    then Tezos.address (Tezos.implicit_account (Crypto.hash_key (permit.key)))
    else (failwith "MISSIGNED" : address)

let is_expired (proposal, voting_period : proposal_info * nat) : bool =
  if Tezos.now - proposal.timestamp > int(voting_period)
  then true
  else false

let add_vote (proposal, voter, ledger : proposal_info * address * ledger) 
    : proposal_info =
  if not Set.mem voter proposal.voters
  then (failwith "NOT_A_VOTER" : proposal_info)
  else proposal

let get_proposal (key, pending_proposals : bytes * pending_proposals) : proposal_info =
  let pi  : proposal_info option = Big_map.find_opt key pending_proposals in 
  match pi with
  | Some pi -> pi
  | None -> {
    vote_amount = 0n;
    voters = (Set.empty : address set);
    timestamp = Tezos.now;
  }

let vote (v, s : vote * dao_storage) : return =
  let voter = match v.permit with
  | None -> Tezos.sender
  | Some p -> validate_permit (v.lambda, p, s.vote_count)
  in
  let vote_key = Bytes.pack v.lambda in
  let proposal = get_proposal (vote_key, s.pending_proposals) in
  if is_expired (proposal, s.voting_period)
  then (failwith "EXPIRED" : return)
  else if Set.mem voter proposal.voters
  then (failwith "DUP_VOTE" : return)
  else
    let updated_proposal = add_vote (proposal, voter, s.ownership_token.ledger) in
    ([] : operation list), s

let main(param, storage : dao_entrypoints * dao_storage) : return =
  match param with
  | Fa2 fa2 -> 
    let ops, new_ownership = fa2_main(fa2, storage.ownership_token) in
    ops, { storage with ownership_token = new_ownership; }

  | Set_voting_threshold t ->
    let u = assert_self_call () in
    let new_storage = set_voting_threshold (t, storage) in
    ([] : operation list), new_storage

  | Vote v -> vote (v, storage)

#endif