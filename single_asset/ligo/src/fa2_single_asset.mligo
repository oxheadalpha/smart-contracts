
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
  | Assets of fa2_entry_points
  | Admin of simple_admin
  | Tokens of token_manager

let single_asset_main 
    (param, s : single_asset_param * single_asset_storage)
  : (operation list) * single_asset_storage =
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


(**
This is a sample initial fa2_single_asset storage.
 *)

let store : single_asset_storage = {
            admin = {
              admin = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
              pending_admin = (None : address option);
              paused = true;
            };
            assets = {
                ledger = (Big_map.empty : (address, nat) big_map);
                operators = (Big_map.empty : ((address * address), unit) big_map);
                token_metadata = Big_map.literal [
                  (
                    0n, 
                    Layout.convert_to_right_comb ({
                      token_id = 0n;
                      symbol = "TK1";
                      name = "Test Token";
                      decimals = 0n;
                      extras = (Map.empty : (string, string) map);
                    } : token_metadata)
                  );
                ];
                total_supply = 0n;
            };
        }