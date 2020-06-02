
(*
  `fa2_nft_asset` contract combines `fa2_nft_token` transfer API with
  `simple_admin` API and `token_manager` API.  Input parameter type for the
  `fa2_nft_asset` contract is a union of `fa2_entry_points` and 
  `simple_admin` and `token_manager` parameter types.
  Depending on the input, `fa2_nft_asset` dispatches the call to either
  `fa2_entry_points` or `simple_admin`  or `token_manager` entry points. 
  If the contract is paused, `fa2_nft_token` entry points cannot be invoked.
  Only current admin can access `simple_admin` and `token_manager` entry points.
*)

#if !FA2_NFT_ASSET
#define FA2_NFT_ASSET

#include "fa2_nft_token.mligo"
#include "token_manager.mligo"
#include "simple_admin.mligo"

type nft_asset_storage = {
  admin : simple_admin_storage;
  assets : nft_token_storage;
}

type nft_asset_param =
  | Assets of fa2_entry_points
  | Admin of simple_admin
  | Tokens of token_manager

let nft_asset_main 
    (param, s : nft_asset_param * nft_asset_storage)
  : (operation list) * nft_asset_storage =
  match param with
  | Admin p ->
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

    let ops, assets = fa2_main (p, s.assets) in
    let new_s = { s with assets = assets; } in
    (ops, new_s)


(** Example of NFT asset initial storage *)

let store : nft_asset_storage = {
            admin = {
              admin = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
              pending_admin = (None : address option);
              paused = true;
            };
            assets = {
                ledger = (Big_map.empty : (token_id, address) big_map);
                operators = (Big_map.empty : ((address * address), unit) big_map);
                metadata = {
                  token_defs = (Set.empty : token_def set);
                  last_used_id = 0n;
                  metadata = (Big_map.empty : (token_def, token_metadata) big_map);
                };
            };
        } 

#endif
