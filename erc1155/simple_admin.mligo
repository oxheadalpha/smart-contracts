#include "erc1155-base.mligo"

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

type simple_admin =
  | Set_admin of address
  | Pause of bool
  | Create_token of create_token_param
  | Mint_tokens of mint_tokens_param
  // | Mint_tokens_batch of mint_tokens_batch_param
  | Burn_tokens of burn_tokens_param


type simple_admin_storage = {
  admin : address;
  paused : bool;
  (* token_id -> descriptor *)
  tokens : (nat, string) map;
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

let mint_tokens_impl (param : mint_tokens_param) (s : balance_storage) : balance_storage =
  // let to_ko = pack_balance_key param.owner param.token_id s.owners in
  let o = ensure_owner_id param.owner s.owners in
  let to_key = pack_balance_key_impl o.id param.token_id in
  let old_bal = get_balance to_key s.balances in
  let new_bals = Map.update to_key (Some(old_bal + param.amount)) s.balances in
  {
    owners = o.owners;
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
  let d = Map.find_opt param.token_id a.tokens in
  match d with
    | None -> (failwith "Token does not exists" : (operation list) * balance_storage)
    | Some d ->
        let new_b = mint_tokens_impl param b in
        let ops = mint_safe_check param in
        (ops, new_b)

// let mint_tokens_batch_impl (param : mint_tokens_param) (s : balance_storage) : balance_storage =
//   // let owner_owners = ensure_owner_id param.owner s.owners in
//   // let new_owners = owner_owners.(1) in
//   // let owner_id = owner_owners.(0) in 

//   // let make_transfer = fun (bals: balances) (t: tx) ->
//   //   let to_key  = pack_balance_key { owner = param.owner; token_id = t.token_id; } new_owners in
//   //   let old_bal = get_balance to_key bals in
//   //   Map.update to_key (Some(old_bal + t.amount)) bals in

//   // let new_bals = List.fold param.batch s.balances make_transfer in
//   s
//   // {
//    //   owners = new_owners;
//   //   balances = new_bals;
//   // }


let mint_tokens_batch (param : mint_tokens_batch_param) (a : simple_admin_storage) (b : balance_storage): (operation list) * balance_storage =
  // let d = Map.find_opt param.token_id a.tokens in
  // match d with
  //   | None -> (failwith "Token does not exists" : (operation list) * balance_storage)
  //   | Some d ->
        // // let new_b = mint_tokens_impl param b in
        // // let ops = mint_safe_check param in
        // (ops, new_b)
        (([] : operation list), b)

let burn_tokens (param : burn_tokens_param) (s : balance_storage): balance_storage =
  let from_key = pack_balance_key param.owner param.token_id s.owners in
  let old_bal = get_balance from_key s.balances in
  let new_bal = old_bal - param.amount in
  let new_bals = 
    if new_bal < 0
    then (failwith "Insufficiuent balance" : balances)
    else if new_bal = 0
    then Map.remove from_key s.balances
    else Map.update from_key (Some(abs(new_bal))) s.balances in
  {
    owners = s.owners;
    balances = new_bals;
  }

let simple_admin (param : simple_admin) (ctx : simple_admin_context) : (operation list) * simple_admin_context =
  if sender <> ctx.admin_storage.admin
  then (failwith "operation require admin priveleges" : (operation list) * simple_admin_context)
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

      // | Mint_tokens_batch param -> 
      //     let ops_new_bals  = mint_tokens_batch param ctx.admin_storage ctx.balance_storage in
      //     let new_ctx : simple_admin_context = {
      //       admin_storage = ctx.admin_storage;
      //       balance_storage = ops_new_bals.(1);
      //     } in
      //     (ops_new_bals.(0), new_ctx)

      | Burn_tokens param -> 
          let new_bals = burn_tokens param ctx.balance_storage in
          let new_ctx = {
            admin_storage = ctx.admin_storage;
            balance_storage = new_bals
          } in
          (([] : operation list), new_ctx)


let admin_test (p : unit) = unit