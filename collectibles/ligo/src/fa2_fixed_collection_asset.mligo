#include "fa2_fixed_collection_token.mligo"
#include "../fa2_modules/simple_admin.mligo"

module CollectionAsset = struct

  type storage = {
    assets : Token.storage;
    admin : Admin.storage;
    metadata : contract_metadata;
  }

  type return_type = operation list * storage

  [@entry] let assets (p : fa2_entry_points) (storage : storage) : return_type =
    let _ = Admin.fail_if_paused storage.admin in
    let ops, new_assets = Token.fa2_main (p, storage.assets) in
    let new_s = { storage with assets = new_assets; } in
    (ops, new_s)

  [@entry] let admin (p : Admin.entrypoints) (storage : storage) : return_type =
    let ops, new_admin = Admin.main (p, storage.admin) in
    let new_s = { storage with admin = new_admin; } in
    (ops, new_s)

end

(* this is a sample collection asset contract storage *)
let store : CollectionAsset.storage = {
  assets = {
    ledger = Big_map.literal [
      ( 0n, ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address))
    ];
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
                  ) 
                ];
    permissions = {
      operator = Owner_or_operator_transfer;
      receiver = Optional_owner_hook;
      sender = Optional_owner_hook;
      custom = (None : custom_permission_policy option);
    };
  };
  admin = {
    admin = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
    pending_admin = (None : address option);
    paused = false;
  };
  metadata = Big_map.literal [
    ("", Bytes.pack "tezos-storage:content" );
    ("content", 0x00) (* bytes encoded UTF-8 JSON *)
  ];
}
