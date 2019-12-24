#include "multi_asset.mligo"

(* let sas : simple_admin_storage = {
  admin = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
  paused = true;
  tokens = (Big_map.empty : (nat, string) big_map);
} *)

(* let mts : multi_token_storage = {
  operators = (Big_map.empty : (address, address set) big_map);
  balance_storage = {
    owners = {
      owner_count = 0n;
      owners = (Big_map.empty : (address, nat) big_map);
    };
    balances = (Big_map.empty : (nat, nat) big_map);
  }
} *)



let storage : multi_asset_storage = {
    admin = {
      admin = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
      paused = true;
      tokens = (Big_map.empty : (nat, string) big_map);
    };
    assets = {
      operators = (Big_map.empty : (address, address set) big_map);
      balance_storage = {
        owners = {
          owner_count = 0n;
          owners = (Big_map.empty : (address, owner_entry) big_map);
        };
        balances = (Big_map.empty : (nat, nat) big_map);
      }
    };
}

(*
  (Pair (Pair (Pair "tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" True) {})
      (Pair (Pair {} (Pair 0 {})) {}))
*)


let param_pause : multi_asset_param =
  Admin (Pause true)

(*
(Left (Left (Right (Right True))))
*)

let param_create_token : multi_asset_param =
  Admin (
    Create_token {
      token_id = 1n;
      descriptor = "first token";
    })

(*
(Left (Left (Left (Right (Pair "first token" 1)))))
*)

let param_mint_tokens : multi_asset_param =
  Admin (
    Mint_tokens {
      owner = ("tz1aYQcaXmowUu59gAgMGdiX6ARR7gdmikZk" : address);
      batch = ([{ token_id = 1n; amount = 10n; }] : tx list);
      data = ("" : bytes);
    })

(*
(Left (Left (Right (Left (Pair (Pair { Pair 10 1 } 0x) "tz1aYQcaXmowUu59gAgMGdiX6ARR7gdmikZk")))))
*)

let param_burn_tokens : multi_asset_param =
  Admin (
    Burn_tokens {
      owner = ("tz1RZUEpGCVgDR9Q1GZD8bsp4WyWpNhu1MRY" : address);
      batch = ([{ token_id = 1n; amount = 5n; }] : tx list);
    })

(*
(Left (Left (Left (Left (Pair { Pair 5 1 } "tz1RZUEpGCVgDR9Q1GZD8bsp4WyWpNhu1MRY")))))
*)

let param_transfer : multi_asset_param =
  Assets (
    Transfer {
      from_ = ("tz1aYQcaXmowUu59gAgMGdiX6ARR7gdmikZk" : address);
      to_ = ("tz1RZUEpGCVgDR9Q1GZD8bsp4WyWpNhu1MRY" : address);
      batch = ([{ token_id = 1n; amount = 8n; }] : tx list);
      data = ("" : bytes);
    })

(*
(Right
   (Right
      (Pair (Pair { Pair 8 1 } 0x)
            (Pair "tz1aYQcaXmowUu59gAgMGdiX6ARR7gdmikZk" "tz1RZUEpGCVgDR9Q1GZD8bsp4WyWpNhu1MRY"))))
*)

let test (p : unit) = unit