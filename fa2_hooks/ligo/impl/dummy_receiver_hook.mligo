#include "token_owner.mligo"

(* just keeps balances of received tokens *)
type dummy_entry_points =
| Owner of token_owner
| Tokens_received of transfer_descriptor_param_michelson

(** (fa2, token_id) -> own_balance *)
type received_storage = ((address * nat), nat) map

let update_balance (pm, storage
    : transfer_descriptor_param_michelson * received_storage) : received_storage =
  let p = transfer_descriptor_param_from_michelson pm in
  let fa2 = Tezos.sender in
  List.fold 
    (fun (s, tx : received_storage * transfer_descriptor) ->
      List.fold (fun (s, tx_dest : received_storage * transfer_destination_descriptor) ->
        match tx_dest.to_ with
        | None -> s
        | Some to_ ->
          if to_ <> Tezos.self_address
          then s
          else
            let key = fa2, tx_dest.token_id in
            let old_bal = Big_map.find_opt key s in
            let new_bal = match old_bal with
            | None -> tx_dest.amount
            | Some bal -> bal + tx_dest.amount
            in
            Big_map.update key (Some new_bal) s
      ) tx.txs s
    ) p.batch storage

let dummy_receiver_hook_main (param, storage : dummy_entry_points * received_storage) =
  match param with
  | Owner op -> 
    let ops, u = token_owner_main (op, unit) in
    ops, storage
 
  | Tokens_received pm -> 
    let new_s = update_balance (pm, storage) in
    ([] : operation list), new_s

