#if ! FRACTIONAL_DAO

#define FRACTIONAL_DAO

#include "../fa2/fa2_interface.mligo"
#include "../fa2_modules/simple_admin.mligo"
#include "fa2_multi_token.mligo"


module FractionalDao = struct

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

  type ownership_token_param =
  [@layout:comb]
  {
    nft_token : global_token_id;
    callback : token_id contract
  }

  type transfer_vote =
  [@layout:comb]
  {
    to_ : address;
    nft_token : global_token_id;
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

  type transfer_vote_info = {
    vote_amount : nat;
    voters : address set;
    timestamp : timestamp;
  }

  type pending_votes = (transfer_vote, transfer_vote_info) big_map

  type dao_storage = {
    ownership_tokens : Token.storage;
    next_ownership_token_id : nat;
    admin : Admin.storage;
    vote_nonce : nat;
    owned_nfts : ownership;
    pending_votes : pending_votes;
    metadata : contract_metadata;
  }

  let mint_ownership_token (ownership, token_id, s : 
      ownership_stake list * token_id * Token.storage) : Token.storage =
    let meta = { 
      token_id = token_id;
      token_info = Map.literal [
        ("symbol", Bytes.pack "OT");
        ("name", Bytes.pack "Ownership Token");
        ("decimals", Bytes.pack "0");
      ]; 
    } in
    let new_token_meta = Big_map.add token_id meta s.token_metadata in
    
    let new_ledger, token_supply = List.fold 
      (fun (acc, ownership : (Token.ledger * nat) * ownership_stake ) ->
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

  let validate_permit (vote, permit, nonce : transfer_vote * permit * nat) : address =
    let signed_data = Bytes.pack (
      ((Tezos.get_chain_id ()), (Tezos.get_self_address ())),
      (nonce, vote)
    ) in
    if Crypto.check permit.key permit.signature signed_data
    then Tezos.address (Tezos.implicit_account (Crypto.hash_key (permit.key)))
    else (failwith "MISSIGNED" : address)

  let make_transfer (vote : transfer_vote): operation  =
    let tx : transfer = {
        from_ = Tezos.get_self_address ();
        txs = [{to_ = vote.to_; token_id = vote.nft_token.token_id ; amount = 1n; }];
      } in
    let fa2_entry : ((transfer list) contract) option = 
      Tezos.get_entrypoint_opt "%transfer"  vote.nft_token.fa2 in
    match fa2_entry with
    | None -> (failwith "CANNOT_INVOKE_NFT_TRANSFER" : operation)
    | Some c -> Tezos.transaction [tx] 0mutez c

  let burn_ownership_token(token_id, s : token_id * Token.storage) : Token.storage =
    { s with
      token_metadata = Big_map.remove token_id s.token_metadata;
      token_total_supply = Big_map.remove token_id s.token_total_supply;
    }

  let clean_after_transfer (vote, ownership_token, s 
      : transfer_vote * token_id * dao_storage) : dao_storage =
    { s with
      vote_nonce = s.vote_nonce + 1n;
      pending_votes = Big_map.remove vote s.pending_votes;
      owned_nfts = Big_map.remove vote.nft_token s.owned_nfts;
      ownership_tokens = burn_ownership_token (ownership_token, s.ownership_tokens);
    }

  let vote_transfer (p, s : vote_transfer_param * dao_storage)
      : operation list * dao_storage =
    let voter = match p.permit with
    | None -> Tezos.get_sender()
    | Some permit -> validate_permit (p.vote, permit, s.vote_nonce)
    in
    let ownership = match Big_map.find_opt p.vote.nft_token s.owned_nfts with
    | None -> (failwith "NO_OWNERSHIP" : nft_ownership)
    | Some o -> o
    in
    let stake_key = (voter, ownership.ownership_token) in
    let voter_stake = 
      match Big_map.find_opt stake_key s.ownership_tokens.ledger with
      | None -> (failwith "NOT_OWNER" : nat)
      | Some bal -> bal
    in
    let updated_votes = match Big_map.find_opt p.vote s.pending_votes with
    | Some v ->
      if Set.mem voter v.voters
      then (failwith "DUP_VOTE" : transfer_vote_info)
      else if ((Tezos.get_now ()) - v.timestamp) > int(ownership.voting_period)
      then (failwith "EXPIRED" : transfer_vote_info)
      else { v with
        vote_amount = v.vote_amount + voter_stake; 
        voters = Set.add voter v.voters;
      }
    | None -> { 
        vote_amount = voter_stake; 
        voters = Set.literal [voter];
        timestamp = Tezos.get_now ();
      }
    in
    if updated_votes.vote_amount < ownership.voting_threshold
    then 
      let new_pending_votes =
        Big_map.update p.vote (Some updated_votes) s.pending_votes in
        ([] : operation list), { s with 
          pending_votes = new_pending_votes; 
          vote_nonce = s.vote_nonce + 1n; 
        }
    else
      let tx_op = make_transfer p.vote in
      let new_s = clean_after_transfer (p.vote, ownership.ownership_token, s) in
      [tx_op], new_s
    
  let flush_expired (vote, voting_period, pending_votes
      : transfer_vote * nat * pending_votes) : pending_votes =
    match Big_map.find_opt vote pending_votes with
    | None -> (failwith "VOTE_DOES_NOT_EXIST" : pending_votes)
    | Some info ->
      if (Tezos.get_now ()) - info.timestamp > int(voting_period)
      then Big_map.remove vote pending_votes
      else (failwith "VOTE_NOT_EXPIRED" : pending_votes)

  let get_ownership_token (p, owned_nfts : ownership_token_param * ownership) : operation =
    match Big_map.find_opt p.nft_token owned_nfts with
    | None -> (failwith "NO_OWNERSHIP" : operation)
    | Some ownership -> 
      Tezos.transaction ownership.ownership_token 0mutez p.callback

  type return = operation list * dao_storage

  (** handling ownership FA2 fungible tokens *)
  [@entry] let fa2 (fa2 : fa2_entry_points) (s : dao_storage) : return =
    let _ = Admin.fail_if_paused s.admin in
    let ops, new_ownership = Token.fa2_main(fa2, s.ownership_tokens) in
    ops, { s with ownership_tokens = new_ownership; }

  [@entry] let set_ownership (p : set_ownership_param) (s : dao_storage) : return =
    let _ = Admin.fail_if_not_admin s.admin in
    let new_s = set_ownership(p, s) in
    ([] : operation list), new_s
  
  [@entry] let vote_transfer (p : vote_transfer_param) (s : dao_storage) : return =
    let _ = Admin.fail_if_paused s.admin in
    let ops, new_s = vote_transfer(p, s) in
    ops, new_s
  
  [@entry] let flush_expired (p : transfer_vote) (s : dao_storage) : return =
    let _ = Admin.fail_if_paused s.admin in
    let ownership = match Big_map.find_opt p.nft_token s.owned_nfts with
    | None -> (failwith "NO_OWNERSHIP" : nft_ownership)
    | Some o -> o
    in
    let new_pending = flush_expired (p, ownership.voting_period, s.pending_votes) in
    ([] : operation list), { s with pending_votes = new_pending; }

  [@entry] let admin (p : Admin.entrypoints) (s : dao_storage) : return =
    let ops, new_admin = Admin.main (p, s.admin) in
    ops, { s with admin = new_admin; }

  [@entry] let ownership_token (p : ownership_token_param) (s : dao_storage) : return =
    let op = get_ownership_token (p, s.owned_nfts) in
    [op], s

end

let sample_storage : FractionalDao.dao_storage = {
  ownership_tokens = {
    ledger = (Big_map.empty : Token.ledger);
    operators = (Big_map.empty : operator_storage);
    token_total_supply = (Big_map.empty : MultiToken.token_total_supply);
    token_metadata = (Big_map.empty : token_metadata_storage);
  };
  next_ownership_token_id = 0n;
  admin  = {
    admin = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
    pending_admin = (None : address option);
    paused = false;
  };
  vote_nonce = 0n;
  owned_nfts = (Big_map.empty : FractionalDao.ownership);
  pending_votes = (Big_map.empty : FractionalDao.pending_votes);
  metadata  = Big_map.literal [
    ("", Bytes.pack "tezos-storage:content" );
    ("content", 0x00) (* bytes encoded UTF-8 JSON *)
  ];
}
#endif
