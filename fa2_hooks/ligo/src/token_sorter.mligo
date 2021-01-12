#include "../fa2/fa2_interface.mligo"

type forward_param = {
  fa2 : address;
  tokens : token_id list;
}

type sorter_entry_points =
| Tokens_received of transfer_descriptor_param
| Forward of forward_param

(* (fa2, token_id) -> token_info *)
type token_info = {
  destination : address;
  pending_balance : nat;
}
type dispatch_table = ((address * nat), token_info) big_map

type tokens_to_transfer = (nat, nat) map


let inc_pending_balance (s, tx : dispatch_table * transfer_destination_descriptor)
    : dispatch_table =
  let key = (Tezos.sender, tx.token_id) in
  let info_opt = Big_map.find_opt key s in
  match info_opt with
  | None -> (failwith "UNKNOWN TOKEN" : dispatch_table)
  | Some info ->
    let new_info = {info with pending_balance = info.pending_balance + tx.amount; } in
    Big_map.update key (Some new_info) s

let tokens_received (p, storage
    : transfer_descriptor_param * dispatch_table) : dispatch_table =
  List.fold
    (fun (s, td : dispatch_table * transfer_descriptor) ->
      List.fold 
        (fun (s, tx : dispatch_table * transfer_destination_descriptor) ->
          match tx.to_ with
          | None -> s
          | Some to_ ->
            if to_ <> Tezos.self_address
            then s
            else inc_pending_balance (s, tx)
        ) td.txs s
    ) p.batch storage


type tx_result = (transfer_destination list) * dispatch_table

let generate_tx_destinations (p, storage : forward_param * dispatch_table) : tx_result =
    List.fold
      (fun (acc, token_id : tx_result * token_id) ->
        let dsts, s = acc in
        let key = p.fa2, token_id in
        let info_opt = Big_map.find_opt key s in
        match info_opt with
        | None -> (failwith "UNKNOWN TOKEN" : tx_result)
        | Some info -> 
          let new_dst : transfer_destination = {
            to_ = info.destination;
            token_id = token_id;
            amount = info.pending_balance;
          } in
          let new_info = {info with pending_balance = 0n; } in
          let new_s = Big_map.update key (Some new_info) s in
          new_dst :: dsts, new_s
      ) p.tokens (([] : transfer_destination list), storage)

let forward_tokens (p, storage : forward_param * dispatch_table)
    : (operation list) * dispatch_table =
  let tx_dests, new_s = generate_tx_destinations (p, storage) in
  if List.size tx_dests = 0n
  then ([] : operation list), new_s
  else
    let tx : transfer = {
      from_ = Tezos.self_address;
      txs = tx_dests;
    } in
    let fa2_entry : ((transfer list) contract) option = 
    Tezos.get_entrypoint_opt "%transfer"  p.fa2 in
    let callback_op = match fa2_entry with
    | None -> (failwith "CANNOT CALLBACK FA2" : operation)
    | Some c -> Tezos.transaction [tx] 0mutez c
    in
    [callback_op], new_s

let token_sorter_main (param, storage : sorter_entry_points * dispatch_table) =
  match param with
  | Tokens_received pm -> 
    let new_s = tokens_received (pm, storage) in
    ([] : operation list), new_s

  | Forward p -> forward_tokens (p, storage)
