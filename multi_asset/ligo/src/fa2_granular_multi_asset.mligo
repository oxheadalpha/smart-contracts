
(*
  `multi_asset` contract combines `multi_token` transfer API with
  `token_admin` API and `token_manager` API.  Input parameter type for the
  `multi_asset` contract is a union of `multi_token` and `token_admin` parameter
  types.
  The contract can pause individual tokens. If one of the tokens to be transferred
  is paused, whole transfer operation fails.
*)

#include "token_manager.mligo"
#include "../fa2_modules/token_admin.mligo"
#include "../fa2/fa2_permissions_descriptor.mligo"

type multi_asset_storage = {
  admin : token_admin_storage;
  assets : multi_token_storage;
  metadata : contract_metadata;
}

type multi_asset_param =
  | Assets of fa2_entry_points
  | Admin of token_admin
  | Tokens of token_manager

let multi_asset_main 
    (param, s : multi_asset_param * multi_asset_storage)
    : (operation list) * multi_asset_storage =
  match param with
  | Admin p ->  
    let ops, admin = token_admin (p, s.admin) in
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
    let u2 = fail_if_paused (s.admin, p) in
      
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
    paused = (Big_map.empty : paused_tokens_set);
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

let descriptor: permissions_descriptor = {
  operator = Owner_or_operator_transfer;
  receiver = Owner_no_hook;
  sender = Owner_no_hook;
  custom = Some {tag = "PAUSABLE_TOKENS"; config_api = Some Current.self_address; };
}