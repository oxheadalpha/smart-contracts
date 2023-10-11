
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

module MultiAssetGranular = struct

  type storage = {
    admin : Admin.storage;
    assets : Token.storage;
    metadata : contract_metadata;
  }

  type return = operation list * storage


  [@entry] let assets (p : fa2_entry_points) (s : storage) : return =
    let _ = Admin.fail_if_paused (s.admin, p) in
    let ops, assets = Token.fa2_main (p, s.assets) in
    let new_s = { s with assets = assets } in
    (ops, new_s)

  [@entry] let admin (p : Admin.entrypoints) (s : storage) : return =
    let ops, admin = Admin.main (p, s.admin) in
    let new_s = { s with admin = admin; } in
    (ops, new_s)
  
  [@entry] let tokens (p : token_manager) (s : storage) : return =
    let _ = Admin.fail_if_not_admin s.admin in
    let ops, assets = token_manager (p, s.assets) in 
    let new_s = { s with
      assets = assets
    } in 
    (ops, new_s)

end

(**
This is a sample initial fa2_multi_asset storage.
 *)

let store : MultiAssetGranular.storage = {
  admin = {
    admin = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
    pending_admin = (None : address option);
    paused = (Big_map.empty : Admin.paused_tokens_set);
  };
  assets = {
    ledger = (Big_map.empty : Token.ledger);
    operators = (Big_map.empty : operator_storage);
    token_total_supply = (Big_map.empty : MultiToken.token_total_supply);
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
  custom = Some {
    tag = "PAUSABLE_TOKENS";
    config_api = Some (Tezos.get_self_address ());
  };
}