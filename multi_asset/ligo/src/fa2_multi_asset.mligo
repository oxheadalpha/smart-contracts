
(*
  `multi_asset` contract combines `multi_token` transfer API with
  `simple_admin` API and `token_manager` API.  Input parameter type for the
  `multi_asset` contract is a union of `multi_token` and `simple_admin` parameter
  types.
  Depending on the input, `multi_asset` dispatches call to either
  `multi_token` or `simple_admin`  or `token_manager` entry points. 
  If contract is paused, `multi_token` entry points cannot be invoked.
  Only current admin can access `simple_admin` and `token_manager` entry points.
*)

#include "token_manager.mligo"
#include "../fa2_modules/simple_admin.mligo"

type multi_asset_storage = {
  admin : simple_admin_storage;
  assets : multi_token_storage;
  metadata : contract_metadata;
}

type multi_asset_param =
  | Assets of fa2_entry_points
  | Admin of simple_admin
  | Tokens of token_manager

let multi_asset_main 
    (param, s : multi_asset_param * multi_asset_storage)
    : (operation list) * multi_asset_storage =
  match param with
  | Admin p ->  
      let ops, admin = simple_admin (p, s.admin) in
      let new_s = { s with admin = admin; } in
      (ops, new_s)

  | Tokens p ->
      let u1 = fail_if_not_admin s.admin in
      let ops, assets = token_manager (p, s.assets) in 
      let new_s = { s with
        assets = assets
      } in 
      (ops, new_s)

  | Assets p -> 
      let u2 = fail_if_paused s.admin in
        
      let ops, assets = fa2_main (p, s.assets) in
      let new_s = { s with assets = assets } in
      (ops, new_s)

(**
This is a sample initial fa2_multi_asset storage.
 *)

let store : multi_asset_storage = {
  admin = {
    admin = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
    pending_admin = (None : address option);
    paused = false;
  };
  assets = {
    ledger = (Big_map.empty : ledger);
    operators = (Big_map.empty : operator_storage);
    token_total_supply = (Big_map.empty : token_total_supply);
    token_metadata = (Big_map.empty : token_metadata_storage);
  };
  metadata = Big_map.literal [
    ("", Bytes.pack "tezos-storage:content" );
    (* ("", 0x74657a6f732d73746f726167653a636f6e74656e74); *)
    ("content", 0x00) (* bytes encoded UTF-8 JSON *)
  ];
}
