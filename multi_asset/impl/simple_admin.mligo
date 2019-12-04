(*
  One of the possible implementations of admin API for `multi_token` contract.

  Only current `admin` of the contract can invoke admin API.
  Admin API allows to 
  
    1. Change administrator, 
    2. Create new toke types,
    3. Mint and burn tokens to some existing or new owner account,
    4. pause the contract.

  Mint operation performs safety check as specified for `multi_token`
  transfer entry points. Burn operation fails if the owner holds
  less tokens then burn amount.
*)

#include "multi_token_impl.mligo"

type create_token_param = {
  token_id : nat;
  descriptor : string;
}

type mint_tokens_param = {
  owner : address;
  batch : tx list;
  data : bytes;
}

type burn_tokens_param = {
  owner : address;
  batch : tx list;
}

(* `simple_admin` entry points *)
type simple_admin =
  | Set_admin of address
  | Pause of bool
  | Create_token of create_token_param
  | Mint_tokens of mint_tokens_param
  | Burn_tokens of burn_tokens_param
  (*
    Adds implicit account to the white list to be able to receive tokens
  *)
  | Add_implicit_owners of key_hash list
  (*
    Removes implicit account from the white list. Not whitelisted implicit accounts
    cannot receive tokens. All existing account token balances if any, will remain
    unchanged. It is still possible to transfer tokens from not whitelisted
    implicit account
  *)
  | Remove_implicit_owners of key_hash list


type simple_admin_storage = {
  admin : address;
  paused : bool;
  (* token_id -> descriptor *)
  tokens : (nat, string) big_map;
}

type simple_admin_context = {
  admin_storage : simple_admin_storage;
  balance_storage : balance_storage;
}

let set_admin (new_admin: address) (s: simple_admin_storage) : simple_admin_storage =
  {
    admin = new_admin;
    paused = s.paused;
    tokens = s.tokens;
  }

let pause (paused : bool) (s: simple_admin_storage) : simple_admin_storage =
  {
    admin = s.admin;
    paused = paused;
    tokens = s.tokens;
  }

let create_token 
    (param : create_token_param) (s: simple_admin_storage) : simple_admin_storage =
  let token : string option = Map.find_opt param.token_id s.tokens in
  match token with
  | Some d -> (failwith "token already exists" : simple_admin_storage)
  | None -> 
    let new_tokens = Map.add param.token_id param.descriptor s.tokens in
    {
      admin = s.admin;
      paused = s.paused;
      tokens = new_tokens;
    }

let token_exists (token_id : nat) (tokens : (nat, string) big_map) : unit =
  let d = Map.find_opt token_id tokens in
  match d with  
  | None ->   failwith("token does not exist")
  | Some d -> unit

let mint_tokens_impl
    (param : mint_tokens_param) (owner_id : nat) (tokens : (nat, string) big_map) 
    (b : balances) : balances =

  let make_transfer = fun (bals: balances) (t: tx) ->
    let u : unit = token_exists t.token_id tokens in
    let to_key  = make_balance_key_impl owner_id t.token_id in
    let old_bal = get_balance to_key bals in
    Map.update to_key (Some(old_bal + t.amount)) bals in

  List.fold make_transfer param.batch b

let mint_safe_check (param : mint_tokens_param) (is_owner_implicit : bool) : operation list =
  if is_owner_implicit
  then ([] : operation list)
  else
    let receiver : multi_token_receiver contract =
      Operation.get_entrypoint "%multi_token_receiver" param.owner in
    let p : on_multi_tokens_received_param = {
      operator = sender;
      from_ = (None : address option);
      batch = param.batch;
      data = param.data;
    } in
    let op = Operation.transaction (On_multi_tokens_received p) 0mutez receiver in
    [op] 

let mint_tokens 
    (param : mint_tokens_param) (a : simple_admin_storage) 
    (b : balance_storage) : (operation list) * balance_storage =
  let owner = ensure_owner_id param.owner b.owners in
  let ops = mint_safe_check param owner.owner.is_implicit in
  let new_bals = mint_tokens_impl param owner.owner.id a.tokens b.balances in
  let new_s = {
    owners = owner.owners;
    balances = new_bals;
  } in 
  (ops, new_s)

let burn_tokens
    (param : burn_tokens_param) (s : balance_storage): balance_storage =
  let owner_id = get_owner_id param.owner s.owners in

  let make_burn = fun (bals : balances) (t : tx) ->
    let from_key = make_balance_key_impl owner_id t.token_id in
    let old_bal =  
      match Map.find_opt from_key bals with
      | Some b  -> b
      | None    -> 0n
    in
    match Michelson.is_nat ( old_bal - t.amount ) with
    | None -> (failwith("Insufficient funds") : balances)
    | Some new_bal -> 
        if new_bal = 0n
        then Map.remove from_key bals
        else Map.update from_key (Some new_bal) bals
    in

  let new_bals = List.fold make_burn param.batch s.balances in
  {
    owners = s.owners;
    balances = new_bals;
  } 

let get_implicit_address (hash : key_hash) : address =
  let c : unit contract = Current.implicit_account hash in
  Current.address c

let add_implicit_owners
    (owner_hashes : key_hash list) (s : balance_storage): balance_storage =

  let add_owner = fun (l : owner_lookup) (h : key_hash) -> 
    let owner = get_implicit_address h in
    let entry = Map.find_opt owner l.owners in
    match entry with
    | None -> 
      let r = add_owner owner true l in
      r.owners
    | Some o_e ->
      if o_e.is_implicit
      then s.owners
      else (failwith "originated owner with the same address already exists" : owner_lookup)
    in

let new_lookup = List.fold add_owner owner_hashes s.owners in
{
  owners = new_lookup;
  balances = s.balances;
}

let remove_implicit_owners
    (owner_hashes : key_hash list) (s : balance_storage): balance_storage =
  
  let remove_owner = fun (l : owner_lookup) (h : key_hash) ->
    let owner = get_implicit_address h in
    let entry = Map.find_opt owner l.owners in
    match entry with
    | None -> l
    | Some o_e ->
      if not o_e.is_implicit
      then (failwith "trying to remove non-implicit account" : owner_lookup)
      else
        {
          owner_count = s.owners.owner_count;
          owners = Map.remove owner s.owners.owners;
        } 
    in
  let new_lookup = List.fold remove_owner owner_hashes s.owners in
  {
    owners = new_lookup;
    balances = s.balances;
  }


let simple_admin 
    (param : simple_admin) (ctx : simple_admin_context)
    : (operation list) * simple_admin_context =
  if sender <> ctx.admin_storage.admin
  then 
    (failwith "operation requires admin privileges" : (operation list) * simple_admin_context)
  else
    match param with
    | Set_admin new_admin ->
        let new_admin_s = set_admin new_admin ctx.admin_storage in
        let new_ctx = {
          admin_storage = new_admin_s;
          balance_storage = ctx.balance_storage;
        } in
        (([]: operation list), new_ctx)

    | Pause paused ->
        let new_admin_s = pause paused ctx.admin_storage in
        let new_ctx = {
          admin_storage = new_admin_s;
          balance_storage = ctx.balance_storage;
        } in
        (([]: operation list), new_ctx)

    | Create_token param ->
        let new_admin_s = create_token param ctx.admin_storage in
        let new_ctx = {
          admin_storage = new_admin_s;
          balance_storage = ctx.balance_storage;
        } in
        (([]: operation list), new_ctx)

    | Mint_tokens param -> 
        let ops_new_bals  = mint_tokens param ctx.admin_storage ctx.balance_storage in
        let new_ctx : simple_admin_context = {
          admin_storage = ctx.admin_storage;
          balance_storage = ops_new_bals.1;
        } in
        (ops_new_bals.0, new_ctx)

    | Burn_tokens param ->
        let new_bals = burn_tokens param ctx.balance_storage in
        let new_ctx = {
          admin_storage = ctx.admin_storage;
          balance_storage = new_bals;
        } in
        (([] : operation list), new_ctx)

    | Add_implicit_owners hashes ->
        let new_bals = add_implicit_owners hashes ctx.balance_storage in
        let new_ctx = {
          admin_storage = ctx.admin_storage;
          balance_storage = new_bals;
        } in
        (([] : operation list), new_ctx)

    | Remove_implicit_owners hashes ->
        let new_bals = remove_implicit_owners hashes ctx.balance_storage in
        let new_ctx = {
          admin_storage = ctx.admin_storage;
          balance_storage = new_bals;
        } in
        (([] : operation list), new_ctx)
        

