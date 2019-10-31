#include "erc1155_base.mligo"

type create_token_param = {
  token_id : nat;
  descriptor : string;
}

type mint_tokens_param = {
  token_id : nat;
  owner : address;
  amount : nat;
  data : bytes;
}

type mint_tokens_batch_param = {
  owner : address;
  batch : tx list;
  data : bytes;
}

type burn_tokens_param = {
  token_id : nat;
  owner : address;
  amount : nat;
}

type burn_tokens_batch_param = {
  owner : address;
  batch : tx list;
}

type simple_admin =
  | Set_admin of address
  | Pause of bool
  | Create_token of create_token_param
  | Mint_tokens of mint_tokens_param
  | Mint_tokens_batch of mint_tokens_batch_param
  | Burn_tokens of burn_tokens_param
  | Burn_tokens_batch of burn_tokens_batch_param


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

let create_token (param : create_token_param) (s: simple_admin_storage) : simple_admin_storage =
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
    | None ->   failwith("token does not exists")
    | Some d -> unit

let mint_tokens_impl (param : mint_tokens_param) (s : balance_storage) : balance_storage =
  let to_ko = pack_balance_key_ensure param.owner param.token_id s.owners in
  let old_bal = get_balance to_ko.key s.balances in
  let new_bals = Map.update to_ko.key (Some(old_bal + param.amount)) s.balances in
  {
    owners = to_ko.owners;
    balances = new_bals;
  }

let mint_safe_check (param : mint_tokens_param) : operation list =
  let receiver : erc1155_token_receiver contract =  Operation.get_contract param.owner in
  let p : on_erc1155_received_param = {
    operator = sender;
    from_ = (None : address option);
    token_id = param.token_id;
    amount = param.amount;
    data = param.data;
  } in
  let op = Operation.transaction (On_erc1155_received p) 0mutez receiver in
  [op]

let mint_tokens (param : mint_tokens_param) (a : simple_admin_storage) (b : balance_storage): (operation list) * balance_storage =
  let u = token_exists param.token_id a.tokens in
  let new_b = mint_tokens_impl param b in
  let ops = mint_safe_check param in
  (ops, new_b)

let mint_tokens_batch_impl (param : mint_tokens_batch_param) (tokens : (nat, string) big_map) (s : balance_storage) : balance_storage =
  let owner = ensure_owner_id param.owner s.owners in

  let make_transfer = fun (bals: balances) (t: tx) ->
    let u = token_exists t.token_id tokens in
    let to_key  = pack_balance_key_impl owner.id t.token_id in
    let old_bal = get_balance to_key bals in
    Map.update to_key (Some(old_bal + t.amount)) bals in

  let new_bals = List.fold param.batch s.balances make_transfer in
  {
     owners = owner.owners;
    balances = new_bals;
  }

let mint_batch_safe_check (param : mint_tokens_batch_param) : operation list =
  let receiver : erc1155_token_receiver contract =  Operation.get_contract param.owner in
  let p : on_erc1155_batch_received_param = {
    operator = sender;
    from_ = (None : address option);
    batch = param.batch;
    data = param.data;
  } in
  let op = Operation.transaction (On_erc1155_batch_received p) 0mutez receiver in
  [op]

let mint_tokens_batch (param : mint_tokens_batch_param) (a : simple_admin_storage) (b : balance_storage) : (operation list) * balance_storage =
  let new_b = mint_tokens_batch_impl param a.tokens b in
  let ops = mint_batch_safe_check param in
  (ops, new_b)

let burn_tokens (param : burn_tokens_param) (s : balance_storage): balance_storage =
  let from_key = pack_balance_key param.owner param.token_id s.owners in
  let old_bal = get_balance from_key s.balances in
  let new_bal = old_bal - param.amount in
  let new_bals = 
    if new_bal < 0
    then (failwith "Insufficient balance" : balances)
    else if new_bal = 0
    then Map.remove from_key s.balances
    else Map.update from_key (Some(abs(new_bal))) s.balances in
  {
    owners = s.owners;
    balances = new_bals;
  }

let burn_tokens_batch (param : burn_tokens_batch_param) (s : balance_storage): balance_storage =
  let owner_id = get_owner_id param.owner s.owners in

  let make_burn = fun (bals : balances) (t : tx) ->
    let from_key = pack_balance_key_impl owner_id t.token_id in
    let old_bal =  match Map.find_opt from_key bals with
      | Some b  -> b
      | None    -> 0p
    in
    if old_bal < t.amount
    then (failwith("Insufficient funds") : balances)
    else
      Map.update from_key (Some(abs(old_bal - t.amount))) bals
    in

  let new_bals = List.fold param.batch s.balances make_burn in
  {
     owners = s.owners;
    balances = new_bals;
  } 

let simple_admin (param : simple_admin) (ctx : simple_admin_context) : (operation list) * simple_admin_context =
  if sender <> ctx.admin_storage.admin
  then (failwith "operation require admin privileges" : (operation list) * simple_admin_context)
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
            balance_storage = ops_new_bals.(1);
          } in
          (ops_new_bals.(0), new_ctx)

      | Mint_tokens_batch param -> 
          let ops_new_bals  = mint_tokens_batch param ctx.admin_storage ctx.balance_storage in
          let new_ctx : simple_admin_context = {
            admin_storage = ctx.admin_storage;
            balance_storage = ops_new_bals.(1);
          } in
          (ops_new_bals.(0), new_ctx)

      | Burn_tokens param -> 
          let new_bals = burn_tokens param ctx.balance_storage in
          let new_ctx = {
            admin_storage = ctx.admin_storage;
            balance_storage = new_bals
          } in
          (([] : operation list), new_ctx)

      | Burn_tokens_batch param ->
          let new_bals = burn_tokens_batch param ctx.balance_storage in
          let new_ctx = {
            admin_storage = ctx.admin_storage;
            balance_storage = new_bals
          } in
          (([] : operation list), new_ctx)
