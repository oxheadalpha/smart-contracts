#include "fa2_fixed_collection_token.mligo"
#include "../fa2_modules/simple_admin.mligo"

type collection_asset_storage = {
  assets : collection_storage;
  admin : simple_admin_storage;
  metadata : contract_metadata;
}

type collection_asset_entrypoints = 
  | Assets of fa2_entry_points
  | Admin of simple_admin

let collection_asset_main (param, storage
    : collection_asset_entrypoints * collection_asset_storage)
    : (operation list) * collection_asset_storage =
  match param with
  | Assets p -> 
    let u2 = fail_if_paused storage.admin in
    let ops, new_assets = fa2_collection_main (p, storage.assets) in
    let new_s = { storage with assets = new_assets; } in
    (ops, new_s)

  | Admin p ->
    let ops, new_admin = simple_admin (p, storage.admin) in
    let new_s = { storage with admin = new_admin; } in
    (ops, new_s)


(* helper storage generator *)

type token_descriptor = {
  id : token_id;
  symbol : string;
  name : string;
  token_uri : string option;
  owner : address;
}

let generate_asset_storage (tokens, admin, permissions, contract_meta
    : (token_descriptor list) * address * permissions_descriptor * bytes) 
    : collection_asset_storage =
  let ledger = List.fold (
    fun (ledger, td : ledger * token_descriptor) ->
      Big_map.add td.id td.owner ledger
  ) tokens (Big_map.empty : ledger) in

  let metadata = List.fold (
    fun (meta, td : token_metadata_storage * token_descriptor) ->
      let m0 : token_metadata = {
        token_id = td.id;
        symbol = td.symbol;
        name = td.name;
        decimals = 0n;
        extras = (Map.empty : (string, string) map);
      } in
      let m1 = match td.token_uri with
      | None -> m0
      | Some uri -> { m0 with
          extras = Map.add "token_uri" uri m0.extras;
        }
      in
      Big_map.add td.id m1 meta
  ) tokens (Big_map.empty : token_metadata_storage) in

  let admin : simple_admin_storage = {
    admin = admin;
    pending_admin = (None : address option);
    paused = false;
  } in

  {
    assets = {
      ledger = ledger;
      operators = (Big_map.empty : operator_storage);
      token_metadata = metadata;
      permissions = permissions;
    };
    admin = admin;
    metadata = Big_map.literal [
      ("", 0x74657a6f732d73746f726167653a636f6e74656e74); (* "tezos-storage:content" *)
      ("content", contract_meta);
    ];
  }


let generate_rainbow_collection_storage (owner_admin, contract_meta : address * bytes)
    : collection_asset_storage =
  let uri : string option = None in
  let tokens : token_descriptor list = [
    { id = 0n; symbol="RED"; name="RAINBOW_TOKEN"; owner = owner_admin; token_uri = uri };
    { id = 1n; symbol="ORANGE"; name="RAINBOW_TOKEN"; owner = owner_admin; token_uri = uri };
    { id = 2n; symbol="YELLOW"; name="RAINBOW_TOKEN"; owner = owner_admin; token_uri = uri };
    { id = 3n; symbol="GREEN"; name="RAINBOW_TOKEN"; owner = owner_admin; token_uri = uri };
    { id = 4n; symbol="BLUE"; name="RAINBOW_TOKEN"; owner = owner_admin; token_uri = uri };
    { id = 5n; symbol="INDIGO"; name="RAINBOW_TOKEN"; owner = owner_admin; token_uri = uri };
    { id = 6n; symbol="VIOLET"; name="RAINBOW_TOKEN"; owner = owner_admin; token_uri = uri };
  ] in
  let permissions : permissions_descriptor = {
    operator = Owner_or_operator_transfer;
    receiver = Optional_owner_hook;
    sender = Owner_no_hook;
    custom = (None : custom_permission_policy option);
  } in
  generate_asset_storage (tokens, owner_admin, permissions, contract_meta)


(*
CLI:
ligo compile-storage collectibles/ligo/src/fa2_fixed_collection_asset.mligo collection_asset_main '
generate_rainbow_collection_storage (("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address), ("00" : bytes))'
*)