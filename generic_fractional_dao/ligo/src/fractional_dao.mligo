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

type dao_lambda = unit -> operation list

type vote =
[@layout:comb]
{
  lambda : dao_lambda;
  permit : permit option;
}

type set_voting_threshold_param = 
{
  old_threshold: nat;
  new_threshold: nat;
}

type set_voting_period_param = 
{
  old_period: nat;
  new_period: nat;
}

type pending_proposals = (bytes, proposal_info) big_map

type dao_storage = {
  ownership_token : single_token_storage;
  voting_threshold : nat;
  voting_period : nat;
  vote_count : nat;
  pending_proposals: pending_proposals;
  metadata : contract_metadata;
}

type dao_entrypoints =
  | Fa2 of fa2_entry_points
  | Vote of vote
  (** self-governance entry point *)
  | Set_voting_threshold of set_voting_threshold_param
  (** self-governance entry point *)
  | Set_voting_period of set_voting_period_param
  (** self-governance entry point *)
  | Flush_expired of dao_lambda

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

let set_voting_period (p, s : set_voting_period_param * dao_storage)
    : dao_storage =
  if p.old_period <> s.voting_period
  then (failwith "INVALID_OLD_PERIOD" : dao_storage)
  else if p.new_period < 300n
  then (failwith "PERIOD_TOO_SHORT" : dao_storage)
  else { s with voting_period = p.new_period; }

let is_expired (proposal, voting_period : proposal_info * nat) : bool =
  if Tezos.now - proposal.timestamp > int(voting_period)
  then true
  else false

let flush_expired (lambda, s : dao_lambda * dao_storage ) : dao_storage =
  let key = Bytes.pack lambda in
  match Big_map.find_opt key s.pending_proposals with
  | None -> (failwith "PROPOSAL_DOES_NOT_EXIST" : dao_storage)
  | Some proposal ->
    if is_expired(proposal, s.voting_period)
    then 
      let new_pending = Big_map.remove key s.pending_proposals in
      { s with pending_proposals = new_pending; }
    else (failwith "NOT_EXPIRED" : dao_storage)


let validate_permit (lambda, permit, vote_count 
    : dao_lambda * permit * nat) : address =
  let signed_data = Bytes.pack (
    (Tezos.chain_id, Tezos.self_address),
    (vote_count, lambda)
  ) in
  if  Crypto.check permit.key permit.signature signed_data 
  then Tezos.address (Tezos.implicit_account (Crypto.hash_key (permit.key)))
  else (failwith "MISSIGNED" : address)

let get_voter_stake (voter, ledger : address * ledger) : nat =
  match Big_map.find_opt voter ledger with
  | None -> (failwith "NOT_VOTER" : nat)
  | Some stake -> stake

let update_proposal (proposal, vote_key, s : proposal_info * bytes * dao_storage)
    : return =
  let new_pending = Big_map.update vote_key (Some proposal) s.pending_proposals in
  let new_s = { s with
    pending_proposals = new_pending;
    vote_count = s.vote_count + 1n;
  } in
  ([] : operation list), new_s

let execute_proposal (lambda, vote_key, s : dao_lambda * bytes * dao_storage)
    : return =
  let new_pending = Big_map.remove vote_key s.pending_proposals in
  let ops = lambda () in
  let new_s = { s with
    pending_proposals = new_pending;
    vote_count = s.vote_count + 1n;
  } in
  ops, new_s

let vote (v, s : vote * dao_storage) : return =
  let voter = match v.permit with
  | None -> Tezos.sender
  | Some p -> validate_permit (v.lambda, p, s.vote_count)
  in
  let voter_stake = get_voter_stake (voter, s.ownership_token.ledger) in
  let vote_key = Bytes.pack v.lambda in
  let proposal = match Big_map.find_opt vote_key s.pending_proposals with
  | None -> {
    vote_amount = voter_stake;
    voters = Set.literal [voter];
    timestamp = Tezos.now;
  }
  | Some p ->
    if is_expired (p, s.voting_period)
    then (failwith "EXPIRED" : proposal_info)
    else if Set.mem voter p.voters
    then (failwith "DUP_VOTE" : proposal_info)
    else 
      { p with
        vote_amount = p.vote_amount + voter_stake;
        voters = Set.add voter p.voters;
      }
  in
  if proposal.vote_amount < s.voting_threshold
  then update_proposal (proposal, vote_key, s)
  else execute_proposal (v.lambda, vote_key, s)

let main(param, storage : dao_entrypoints * dao_storage) : return =
  match param with
  | Fa2 fa2 -> 
    let ops, new_ownership = fa2_main(fa2, storage.ownership_token) in
    ops, { storage with ownership_token = new_ownership; }

  | Vote v -> vote (v, storage)

  | Set_voting_threshold t ->
    let u = assert_self_call () in
    let new_storage = set_voting_threshold (t, storage) in
    ([] : operation list), new_storage

  | Set_voting_period p ->
    let u = assert_self_call () in
    let new_storage = set_voting_period (p, storage) in
    ([] : operation list), new_storage

  | Flush_expired lambda ->
    let new_storage = flush_expired (lambda, storage) in
    ([] : operation list), new_storage

let sample_storage : dao_storage = {
  ownership_token = {
    ledger = Big_map.literal [
      (("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address), 50n);
      (("KT193LPqieuBfx1hqzXGZhuX2upkkKgfNY9w" : address), 50n);
    ];
    operators = (Big_map.empty : operator_storage);
    token_metadata = Big_map.literal [
      ( 0n,
        {
          token_id = 0n;
          token_info = Map.literal [
            ("symbol", 0x544b31);
            ("name", 0x5465737420546f6b656e);
            ("decimals", 0x30);
          ];
        }
      ); 
    ];
    total_supply = 100n;
  };
  voting_threshold = 75n;
  voting_period = 10000000n;
  vote_count = 0n;
  pending_proposals = (Big_map.empty : pending_proposals);
  metadata = Big_map.literal [
    ("", Bytes.pack "tezos-storage:content" );
    ("", 0x00);
    ("content", 0x00) (* bytes encoded UTF-8 JSON *)
  ];
}

let sample_param : vote = {
  lambda = fun (u:unit) -> ([] : operation list);
  permit = (None : permit option);
}

#endif
