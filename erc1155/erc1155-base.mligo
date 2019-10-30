#include "erc1155.mligo"

(*  owner -> operator set *)
type approvals = (address, address set) big_map

let set_approval_for_all (param : set_approval_for_all_param) (approvals : approvals) : approvals =
  let operators = match Map.find_opt sender approvals with
    | Some(ops) -> ops
    | None      -> (Set.empty : address set)
  in
  let new_operators = 
    if param.approved
    then Set.add param.operator operators
    else Set.remove param.operator operators
  in
    if Set.size new_operators = 0p
    then  Map.remove sender approvals
    else Map.update sender (Some new_operators) approvals
  

let is_approved_for_all (param : is_approved_for_all_param) (approvals : approvals) : operation = 
  let req = param.is_approved_for_all_request in
  let operators = Map.find_opt req.owner approvals in
  let result = match operators with
    | None      -> false
    | Some ops  -> Set.mem req.operator ops
  in
  param.approved_view (req, result)


let max_tokens = 4294967295p  (* 2^32-1 *)
let owner_offset = 4294967296p  (* 2^32 *)

(* owner_token_id -> balance *)
type balances = (nat, nat) map //TODO: change to big_map
type owner_lookup = {
  owner_count : nat;
  (* owner_address -> owner_id *)
  owners: (address, nat) map //TODO: change to big_map
}

type balance_storage = {
  owners : owner_lookup;
  balances : balances;  
}

(* return updated storage and newly added owner id *)
let add_owner (owner : address) (s : owner_lookup) : (nat * owner_lookup) =
  let owner_id  = s.owner_count + 1p in
  let os = Map.add owner owner_id s.owners in
  let new_s = 
    { 
      owner_count = owner_id;
      owners = os;
    } in
  (owner_id, new_s)

(* gets existing owner id. If owner does not have one, creates a new id and adds it to an owner_lookup *)
let ensure_owner_id (owner : address) (s : owner_lookup) : (nat * owner_lookup) =
  let owner_id = Map.find_opt owner s.owners in
  match owner_id with
    | Some id -> (id, s)
    | None    -> add_owner owner s

let get_owner_id (owner: address) (s: owner_lookup) : nat =
   let owner_id = Map.find_opt owner s.owners in
  match owner_id with
    | None    -> (failwith("No such owner") : nat)
    | Some id -> id

let pack_balance_key_impl (owner_id : nat) (token_id : nat) : nat =
  if token_id > max_tokens
  then (failwith("provided token ID is out of allowed range") : nat)
  else token_id + (owner_id * owner_offset)

let pack_balance_key (r : balance_request) (s : owner_lookup) : nat =
  let owner_id = get_owner_id r.owner s in
  pack_balance_key_impl owner_id r.token_id

(* Packs the key to access balance and if owner does not have an id, creates a new id and adds it to an owner_lookup *)
let pack_balance_key_ensure (r : balance_request) (s : owner_lookup) : (nat * owner_lookup) = 
  let id_lookup = ensure_owner_id r.owner s in
  let key = pack_balance_key_impl id_lookup.(0) r.token_id in
  (key, id_lookup.(1))
 
let get_balance (key : nat) (b : balances) : nat =
  let bal : nat option = Map.find_opt key b in
  match bal with
    | None    -> 0p
    | Some b  -> b

let get_balance_req (r : balance_request) (s : balance_storage) : nat =
  let balance_key = pack_balance_key r s.owners in
  get_balance balance_key s.balances



let balance_of (param : balance_of_param) (s : balance_storage) : operation =
  let bal = get_balance_req param.balance_request s in
  param.balance_view (param.balance_request, bal)

let balance_of_batch (param : balance_of_batch_param) (s : balance_storage)   : operation =
  let to_balance = fun (r: balance_request) ->
    let bal = get_balance_req r s in
    (r, bal) 
  in
  let requests_2_bals = List.map param.balance_request to_balance in
  param.balance_view requests_2_bals

let transfer_balance (from_key : nat) (to_key : nat) (amt : nat) (s : balances) : balances = 
  let from_bal = get_balance from_key s in
  if from_bal < amt
  then (failwith ("Insufficient balance") : balances)
  else
    let fbal = abs (from_bal - amt) in
    let s1 = 
      if fbal = 0p 
      then Map.remove from_key s
      else Map.update from_key (Some fbal) s 
    in
    let to_bal = get_balance to_key s1 in
    let tbal = to_bal + amt in
    let s2 = Map.update to_key (Some tbal) s1 in
    s2

let transfer_safe_check (param : safe_transfer_from_param) : operation list =
  let receiver : erc1155_token_receiver contract =  Operation.get_contract param.to_ in
  // let ops = match receiver with
  //   None    -> ([] : operation list)
  //   Some c  -> 
      let p : on_erc1155_received_param = {
        operator = sender;
        from_ = Some param.from_;
        token_id = param.token_id;
        amount = param.amount;
        data = param.data;
      } in
      let op = Operation.transaction (On_erc1155_received p) 0mutez receiver in
      [op]

let safe_transfer_from (param : safe_transfer_from_param) (s : balance_storage) : (operation  list) * balance_store = 
  let from_key  = pack_balance_key { owner = param.from_; token_id = param.token_id; } s.owners in
  let k_o = pack_balance_key_ensure { owner = param.to_;   token_id = param.token_id; } s.owners in
  let to_key = k_o.(0) in
  let new_owners = k_o.(1) in

  let new_balances = transfer_balance from_key to_key param.amount s.balances in
  let new_store: balance_storage = {
      owners = new_owners;
      balances = new_balances;
    } in
  let ops = transfer_safe_check param in
  (ops, new_store)

let batch_transfer_safe_check (param : safe_batch_transfer_from_param) : operation list =
  let receiver : erc1155_token_receiver contract =  Operation.get_contract param.to_ in
  let p : on_erc1155_batch_received_param = {
      operator = sender;
      from_ = Some param.from_;
      batch = param.batch;
      data = param.data;
    } in
  let op = Operation.transaction (On_erc1155_batch_received p) 0mutez receiver in
  [op]

let safe_batch_transfer_from (param : safe_batch_transfer_from_param) (s : balance_storage) : (operation  list) * balance_store = 
  let from_id = get_owner_id param.from_ s.owners in
  let t_o = ensure_owner_id param.to_ s.owners in
  let to_id = t_o.(0) in
  let new_owners = t_o.(1) in
  let make_transfer = fun (bals: balances) (t: tx) ->
    let from_key  = pack_balance_key_impl from_id t.token_id in
    let to_key  = pack_balance_key_impl to_id t.token_id in
    transfer_balance from_key to_key t.amount bals in 

  let new_balances = List.fold param.batch s.balances make_transfer in
  let new_store: balance_storage = {
    owners = s.owners;
    balances = new_balances;
  } in
  let ops = batch_transfer_safe_check param in
  (ops, new_store)


type erc1155_storage = {
  approvals : approvals;
  balance_storage: balance_storage;
}


let irc1155_main (param : erc1155) (s : erc1155_storage) : (operation  list) * irc1155_storage =
  match param with
    | Safe_transfer_from p ->
        let ops_bstore = safe_transfer_from p s.balance_storage in
        let new_s = {
          approvals = s.approvals;
          balance_storage = ops_bstore.(1);
        } in
        (ops_bstore.(0), new_s)

    | Safe_batch_transfer_from p ->
        let ops_bstore = safe_batch_transfer_from p s.balance_storage in
        let new_s = {
          approvals = s.approvals;
          balance_storage = ops_bstore.(1);
        } in
        (ops_bstore.(0), new_s)

    | Balance_of p ->
        let op = balance_of p s.balance_storage in
        ([op], s)

    | Balance_of_batch p ->
        let op = balance_of_batch p s.balance_storage in
        ([op], s)

    | Set_approval_for_all p ->
        let new_approvals = set_approval_for_all p s.approvals in
        let new_s = {
          approvals = new_approvals;
          balance_storage = s.balance_storage;
        } in
        (([] : operation list), new_s)

    | Is_approved_for_all p  ->
        let op = is_approved_for_all p s.approvals in
        ([op], s)


let base_test (p : unit) = unit