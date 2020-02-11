(*
  Reference implementation if `multi_token` core API.

  Since Babylon does not support pairs as keys for big_map,
  This implementation uses composite `balance_key` represented as `nat`.
  Assumed number of different token types is 2^32 (`max_tokens` constant).
  Both token ID and owner ID are "packed" into single `nat` using first 32 bits
  for token ID and the rest of the bits for owner ID.
  Contract storage also keeps mapping between owner address and owner ID
  represented as `nat` (see `owner_lookup`).

  If tokens are transferred to a new owner address which does not exist
  in `owner_lookup` yet, new entry withing lookup is created and the owner
  is assigned a new `nat` ID. This implementation may change in future,
  if support for white list is needed.

  Current implementation is optimized for token transfer, but makes it
  difficult for adding functionality in future which might need retrieve
  aggregate data (like list all token types held by the owner).
*)

#include "../fa2_hook.mligo"

let max_tokens = 4294967295n  (* 2^32-1 *)
let owner_offset = 4294967296n  (* 2^32 *)


(* owner_token_id -> balance *)
type balances = (nat, nat) big_map

type token_info = {
  descriptor : token_descriptor;
  total_supply : nat;
}
(* token_id -> descriptor *)
type token_storage = (nat, token_info) big_map

type owner_lookup = {
  owner_count : nat;
  (* owner_address -> id *)
  owners: (address, nat) big_map
}

type balance_storage = {
  owners : owner_lookup;
  balances : balances;  
}

type owner_result = {
  owner_id : nat;
  owners : owner_lookup;
}

type multi_token_storage = {
  hook : set_hook_param option;
  balance_storage : balance_storage;
  token_storage : token_storage;
}
 
(* return updated storage and newly added owner id *)
let add_owner (owner : address) (s : owner_lookup) : owner_result =
  let owner_id  = s.owner_count + 1n in
  let os = Big_map.add owner owner_id s.owners in
  let new_s = { 
    owner_count = owner_id;
    owners = os;
  } in
  {
    owner_id = owner_id;
    owners = new_s;
  }

(* 
  gets existing owner id. If owner does not have one, creates a new id and adds
  it to an owner_lookup 
*)
let ensure_owner_id (owner : address) (s : owner_lookup) : owner_result =
  let owner_id = Map.find_opt owner s.owners in
  match owner_id with
  | Some id -> { owner_id = id; owners = s; }
  | None    -> add_owner owner s

let get_owner_id (owner: address) (s: owner_lookup) : nat =
  let owner_id = Map.find_opt owner s.owners in
  match owner_id with
  | None    -> (failwith("No such owner") : nat)
  | Some id -> id

let make_balance_key_impl (owner_id : nat) (token_id : nat) : nat =
  if token_id > max_tokens
  then (failwith("provided token ID is out of allowed range") : nat)
  else token_id + (owner_id * owner_offset)

let make_balance_key (owner : address) (token_id : nat) (s : owner_lookup) : nat =
  let owner_id = get_owner_id owner s in
  make_balance_key_impl owner_id token_id

let get_balance (key : nat) (b : balances) : nat =
  let bal : nat option = Map.find_opt key b in
  match bal with
  | None    -> 0n
  | Some b  -> b

let get_balance_req (r : balance_request) (s : balance_storage) : nat =
  match r.token_id with
  | Single u -> (failwith "Multi token_id is expected" : nat)
  | Multi id ->
    let balance_key = make_balance_key r.owner id s.owners in
    get_balance balance_key s.balances

let balance_of 
    (param : balance_of_param) (s : balance_storage) : operation =
  let to_balance = fun (r: balance_request) ->
    let bal = get_balance_req r s in
    let br : balance_response = {
      request = r;
      balance = bal;
    } in
    br
  in
  let responses = List.map to_balance param.balance_requests in
  Operation.transaction responses 0mutez param.balance_view

(* reviewed above *)

let transfer_balance
    (from_key : nat) (to_key : nat) (amt : nat) (s : balances) : balances = 
  let from_bal = get_balance from_key s in
  match Michelson.is_nat ( from_bal - amt ) with
  | None -> (failwith ("Insufficient balance") : balances)
  | Some fbal ->
    let s1 = 
      if fbal = 0n 
      then Map.remove from_key s
      else Map.update from_key (Some fbal) s 
    in

    let to_bal = get_balance to_key s1 in
    let tbal = to_bal + amt in
    let s2 = Map.update to_key (Some tbal) s1 in
    s2

let permit_transfer(txs : transfer_param) (s : multi_token_storage) : operation =
  match s.hook with
  | None -> (failwith "transfer hook is not set" : operation)
  | Some h ->
    let htxs : hook_transfer list = 
    List.map 
      (fun (tx : transfer) ->
        {
          from_ = Some tx.from_;
          to_ = Some tx.to_;
          token_id = tx.token_id;
          amount = tx.amount;
        }) 
      txs in
    let hp : hook_param = {
      batch = htxs;
      operator = Current.sender;
    } in
    let hook : hook_param contract = Operation.get_contract h.hook in
    Operation.transaction hp 0mutez hook

let transfer (param : transfer list) (s : balance_storage) : balance_storage =
  
  let make_transfer = fun (bals_tx : balance_storage * transfer) ->
    let bals, tx = bals_tx in
    let from_id = get_owner_id tx.from_ bals.owners in
    let to_o = ensure_owner_id tx.to_ bals.owners in
    let tid = match tx.token_id with
    | Single u -> (failwith "Multi token id is expected" : nat)
    | Multi id -> id
    in
    let from_key  = make_balance_key_impl from_id tid in
    let to_key  = make_balance_key_impl to_o.owner_id tid in
    let new_b = transfer_balance from_key to_key tx.amount bals.balances in
    let new_s : balance_storage = {
      owners = to_o.owners;
      balances = new_b;
    } in
    new_s in

  List.fold make_transfer param s

let get_permission_policy (view : ((permission_policy_config list) contract)) 
    (s : multi_token_storage) : operation =
   match s.hook with
    | None -> (failwith "Transfer hook is not set" : operation)
    | Some h -> Operation.transaction h.config 0mutez view

let find_token_info (id : token_id) (tokens : token_storage) : token_info =
  match id with
  | Single u -> (failwith "Milti token id is expected" : token_info)
  | Multi id ->
    let ti = Big_map.find_opt id tokens in
    (match ti with
    | None -> (failwith "token id not found" : token_info)
    | Some i -> i)

let fa2_main (param : fa2_entry_points) (s : multi_token_storage)
    : (operation  list) * multi_token_storage =
  match param with

  | Transfer p ->
      let op = permit_transfer p s in
      let bstore =transfer p s.balance_storage in
      let new_s = { s with balance_storage = bstore; } in
      ([op], new_s)

  | Balance_of p ->
      let op = balance_of p s.balance_storage in
      ([op], s)
  
  | Total_supply p -> 
    let get_response = fun(tid : token_id) ->
        let ti  = find_token_info tid s.token_storage in
        let sr : total_supply_response = {
          token_id = tid;
          supply = ti.total_supply;
        } in
        sr
    in

    let responses = List.map get_response p.token_ids in
    let op = Operation.transaction responses 0mutez p.total_supply_view in
    ([op], s)

  | Token_descriptor p -> 
    let get_response = fun(tid : token_id) ->
        let ti  = find_token_info tid s.token_storage in
        let dr : token_descriptor_response = {
          token_id = tid;
          descriptor = ti.descriptor;
        } in
        dr
    in

    let responses = List.map get_response p.token_ids in
    let op = Operation.transaction responses 0mutez p.token_descriptor_view in
    ([op], s)
      

  | Get_permissions_policy p ->
    let op = get_permission_policy p s in
    ([op], s)

let multi_token_main (param, s : fa2_with_hook_entry_points * multi_token_storage)
    : (operation  list) * multi_token_storage =
  match param with
  | Set_transfer_hook h -> ([] : operation list), { s with hook = Some h; }
  | Fa2 fa2 -> fa2_main fa2 s
