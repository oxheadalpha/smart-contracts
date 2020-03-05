
(*
  `fa2_single_asset` contract combines `fa2_single_token` transfer API with
  `simple_admin` API and `token_manager` API.  Input parameter type for the
  `multi_asset` contract is a union of `fa2_with_hook_entry_points` and 
  `simple_admin` and `token_manager` parameter types.
  Depending on the input, `fa2_single_asset` dispatches the call to either
  `fa2_with_hook_entry_points` or `simple_admin`  or `token_manager` entry points. 
  If the contract is paused, `fa2_single_token` entry points cannot be invoked.
  Only current admin can access `simple_admin` and `token_manager` entry points.
*)

#include "token_manager.mligo"
#include "simple_admin.mligo"

type single_asset_storage = {
  admin : simple_admin_storage;
  assets : single_token_storage;
}

type single_asset_param =
  | Assets of fa2_with_hook_entry_points
  | Admin of simple_admin
  | Tokens of token_manager

let fail_if_not_admin (a : simple_admin_storage) : unit =
  if sender <> a.admin
  then failwith "operation requires admin privileges"
  else unit

let fail_if_paused (a : simple_admin_storage) : unit =
  if a.paused
  then failwith("contract is paused")
  else unit

let single_asset_main 
    (param, s : single_asset_param * single_asset_storage)
    : (operation list) * single_asset_storage =
  match param with
  | Admin p ->
    let u = fail_if_not_admin s.admin in 

    let ops, admin = simple_admin (p, s.admin) in
    let new_s = { s with admin = admin; } in
    (ops, new_s)

  | Tokens p ->
      let u1 = fail_if_not_admin s.admin in

      let ops, assets = token_manager (p, s.assets) in 
      let new_s = { s with assets = assets; } in 
      (ops, new_s)

  | Assets p -> 
      let u2 = fail_if_paused s.admin in
        
      let ops, assets = single_token_main (p, s.assets) in
      let new_s = { s with assets = assets; } in
      (ops, new_s)
