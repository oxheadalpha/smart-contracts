(*
  `multi_asset` contract combines erc1155 transfer API with
  `simple_admin` API.  Input parameter type for the `multi_asset`
  contract is a union of `erc115` and `simple_admin` parameter types.
  Depending on the input, `multi_asset` dispatches call to either
  `erc1155` or `simple_admin` entry points. 
  If contract is paused, erc1155 entry points cannot be invoked.
*)

#include "simple_admin.mligo"

type multi_asset_storage = {
  admin : simple_admin_storage;
  assets : erc1155_storage;
}

type multi_asset_param =
  | Assets of erc1155
  | Admin of simple_admin

let multi_asset_main (param : multi_asset_param) (s : multi_asset_storage) : (operation list) * multi_asset_storage =
  match param with
    | Admin p ->  
        let ctx = {
          admin_storage = s.admin;
          balance_storage = s.assets.balance_storage;
        } in

        let ops_ctx = simple_admin p ctx in 

        let new_ctx = ops_ctx.(1) in
        let new_s = {
          admin = new_ctx.admin_storage;
          assets = {
            approvals = s.assets.approvals;
            balances = new_ctx.balance_storage;
          };
        } in 
        (ops_ctx.(0), s)

    | Assets p -> 
        if s.admin.paused
        then (failwith("contract is paused") : (operation list) * multi_asset_storage)
        else 
          let ops_assets = erc1155_main p s.assets in
          let new_s = {
            admin = s.admin;
            assets = ops_assets.(1);
          } in
          (ops_assets.(0), new_s)
