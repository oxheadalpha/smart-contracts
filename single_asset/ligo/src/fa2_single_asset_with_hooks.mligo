#define OWNER_HOOKS

#include "fa2_single_asset.mligo"

(* 
use single_asset_main from  fa2_single_asset.mligo
it will compile with hooks implementation because of OWNER_HOOKS macro
*)

#include "../fa2/fa2_permissions_descriptor.mligo"

(**
This is a sample initial fa2_single_asset storage.
 *)



let store : single_asset_storage = {
      admin = {
        admin = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
        pending_admin = (None : address option);
        paused = false;
      };
      assets = {
          ledger = (Big_map.empty : (address, nat) big_map);
          operators = (Big_map.empty : operator_storage);
          token_metadata = Big_map.literal [
            (
              0n, 
              ({
                token_id = 0n;
                token_info = Map.literal [
                  ("symbol", 0x544b31);
                  ("name", 0x5465737420546f6b656e);
                  ("decimals", 0x30);
                ];
              } : token_metadata)
            );
          ];
          total_supply = 0n;
          permissions = {
            operator = Owner_or_operator_transfer;
            receiver = Optional_owner_hook;
            sender = Optional_owner_hook;
            custom = (None : custom_permission_policy option);
          };
      };
      metadata = Big_map.literal [
        ("", Bytes.pack "tezos-storage:content" );
        (* ("", 0x74657a6f732d73746f726167653a636f6e74656e74); *)
        ("content", 0x00) (* bytes encoded UTF-8 JSON *)
      ];
  } 
