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
