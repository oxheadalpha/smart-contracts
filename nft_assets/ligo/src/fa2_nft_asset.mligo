
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
#include "../fa2_modules/simple_admin.mligo"

module NftAsset = struct

  type storage = {
    admin : Admin.storage;
    assets : Token.storage;
    metadata : contract_metadata;
  }

  type return = operation list * storage

  [@entry] let assets (p : NftToken.entrypoints) (s : storage) : return =
    let _ = Admin.fail_if_paused s.admin in
    let ops, assets = NftToken.main (p, s.assets) in
    let new_s = { s with assets = assets; } in
    (ops, new_s)

  [@entry] let admin (p : Admin.entrypoints) (s : storage) : return =
    let ops, admin = Admin.main (p, s.admin) in
    let new_s = { s with admin = admin; } in
    (ops, new_s)

  [@entry] let tokens (p : token_manager) (s : storage) : return =
      let _ = Admin.fail_if_not_admin s.admin in
      let ops, assets = token_manager (p, s.assets) in 
      let new_s = { s with assets = assets; } in 
      (ops, new_s)

end

(** Example of NFT asset initial storage *)

let store : NftAsset.storage = {
            admin = {
              admin = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
              pending_admin = (None : address option);
              paused = true;
            };
            assets = {
                ledger = (Big_map.empty : (token_id, address) big_map);
                operators = (Big_map.empty : operator_storage);
                metadata = {
                  token_defs = (Set.empty : token_def set);
                  next_token_id = 0n;
                  metadata = (Big_map.empty : (token_def, token_metadata) big_map);
                };
            };
            metadata = Big_map.literal [
              ("", Bytes.pack "tezos-storage:content" );
              (* ("", 0x74657a6f732d73746f726167653a636f6e74656e74); *)
              ("content", 0x00) (* bytes encoded UTF-8 JSON *)
            ];
        } 

#endif
