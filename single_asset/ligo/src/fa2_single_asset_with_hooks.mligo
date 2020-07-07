#define OWNER_HOOKS

#include "fa2_single_asset.mligo"

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
            permissions_descriptor = {
              operator = Owner_or_operator_transfer;
              receiver = Optional_owner_hook;
              sender = Optional_owner_hook;
              custom = (None : custom_permission_policy option)
            }
        } 
