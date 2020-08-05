#include "fa2_fixed_collection_token.mligo"

(* helper storage generator *)

type token_descriptor = {
  id : token_id;
  symbol : string;
  name : string;
  token_uri : string option;
  owner : address;
}

let generate_asset_storage (tokens, owner
    : (token_descriptor list) * address) 
    : collection_storage =
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
      let m_michelson = Layout.convert_to_right_comb (m1 : token_metadata) in
      Big_map.add td.id m_michelson meta
  ) tokens (Big_map.empty : token_metadata_storage) in

  {
    ledger = ledger;
    operators = (Big_map.empty : operator_storage);
    token_metadata = metadata;
  }


let generate_rainbow_collection_storage (owner : address) : collection_storage =
  let uri : string option = None in
  let tokens : token_descriptor list = [
    { id = 0n; symbol="RED"; name="RAINBOW_TOKEN"; owner = owner; token_uri = uri };
    { id = 1n; symbol="ORANGE"; name="RAINBOW_TOKEN"; owner = owner; token_uri = uri };
    { id = 2n; symbol="YELLOW"; name="RAINBOW_TOKEN"; owner = owner; token_uri = uri };
    { id = 3n; symbol="GREEN"; name="RAINBOW_TOKEN"; owner = owner; token_uri = uri };
    { id = 4n; symbol="BLUE"; name="RAINBOW_TOKEN"; owner = owner; token_uri = uri };
    { id = 5n; symbol="INDIGO"; name="RAINBOW_TOKEN"; owner = owner; token_uri = uri };
    { id = 6n; symbol="VIOLET"; name="RAINBOW_TOKEN"; owner = owner; token_uri = uri };
  ] in
  generate_asset_storage (tokens, owner)


(*
CLI:
ligo compile-storage ligo/src/fa2_fixed_collection_generator.mligo fa2_collection_main 'generate_rainbow_collection_storage ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address)'
*)