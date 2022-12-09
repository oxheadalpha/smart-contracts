
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
#include "../fa2_modules/simple_admin.mligo"

type single_asset_storage = {
  admin : simple_admin_storage;
  assets : single_token_storage;
  metadata : contract_metadata;
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
    let _ = fail_if_not_admin s.admin in

    let ops, assets = token_manager (p, s.assets) in 
    let new_s = { s with assets = assets; } in 
    (ops, new_s)

  | Assets p -> 
    let _ = fail_if_paused s.admin in

    let ops, assets = fa2_main (p, s.assets) in
    let new_s = { s with assets = assets; } in
    (ops, new_s)


(**
This is a sample initial fa2_single_asset storage.
 *)
#if !OWNER_HOOKS

let store : single_asset_storage = {
            admin = {
              admin = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
              pending_admin = (None : address option);
              paused = true;
            };
            assets = {
                ledger = (Big_map.empty : (address, nat) big_map);
                operators = (Big_map.empty : operator_storage);
                token_metadata = Big_map.literal [
                  ( 0n,
                    {
                      token_id = 0n;
                      token_info = Map.literal [
                        ("symbol", 0x544b31);
                        ("name", 0x5465737420546f6b656e);
                        ("decimals", 0x30);
                      ];
                    }
                  ); 
                ];
                total_supply = 0n;
            };
            metadata = Big_map.literal [
              ("", Bytes.pack "tezos-storage:content" );
              (* ("", 0x74657a6f732d73746f726167653a636f6e74656e74); *)
              ("content", 0x00) (* bytes encoded UTF-8 JSON *)
            ];
        }

#endif