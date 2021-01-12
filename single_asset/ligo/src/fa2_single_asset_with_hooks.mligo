#define OWNER_HOOKS

#include "fa2_single_asset.mligo"

type single_asset_with_hooks_param =
  | SA of single_asset_param
  | Permissions_descriptor of permissions_descriptor contract


let single_asset_with_hooks_main (param, storage
    : single_asset_with_hooks_param * single_asset_storage)
    : (operation list) * single_asset_storage =
  match param with
  | SA sap -> single_asset_main (sap, storage)
  | Permissions_descriptor callback ->
    let callback_op =
        Tezos.transaction storage.assets.permissions_descriptor 0mutez callback in
    [callback_op], storage

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
          operators = (Big_map.empty : operator_storage);
          token_metadata = Big_map.literal [
            (
              0n, 
              ({
                token_id = 0n;
                symbol = "TK1";
                name = "Test Token";
                decimals = 0n;
                extras = (Map.empty : (string, string) map);
              } : token_metadata)
            );
          ];
          total_supply = 0n;
          permissions_descriptor = {
            operator = Owner_or_operator_transfer;
            receiver = Optional_owner_hook;
            sender = Optional_owner_hook;
            custom = (None : custom_permission_policy option);
          };
      };
  } 
