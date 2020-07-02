(**
Defines non-mutable NFT collection. Once contract is created, no tokens can
be minted or burned.
Metadata may/should contain URLs for token images and images hashes.

The implementation may support sender/receiver hooks
 *)

#if ! FA2_FIXED_COLLECTION_TOKEN
#define FA2_FIXED_COLLECTION_TOKEN

#include "../fa2/ligo/fa2_interface.mligo"
#include "../fa2/ligo/fa2_errors.mligo"
#include "../fa2/ligo/lib/fa2_operator_lib.mligo"
#include "../fa2/ligo/lib/fa2_owner_hooks_lib.mligo"

(* token_id -> token_metadata *)
type token_metadata_storage = (token_id, token_metadata_michelson) big_map

(* owner_address -> token_id *)
type ledger = (address, token_id) big_map

type collection_storage = {
  ledger : ledger;
  operators : operator_storage;
  token_metadata : token_metadata_storage;
  permissions_descriptor : permissions_descriptor;
}


let fixed_collection_token_main (param, storage : fa2_entry_points * collection_storage)
    : (operation list) * collection_storage =
  ([] : operation list), storage

#endif