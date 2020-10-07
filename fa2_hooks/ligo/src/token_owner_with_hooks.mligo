#include "../fa2_clients/token_owner.mligo"

(* just keeps balances of received tokens *)
type dummy_entry_points =
| Owner of token_owner
| Tokens_received of transfer_descriptor_param
| Tokens_sent of transfer_descriptor_param

(** (fa2, token_id) -> own_balance *)
type balance_storage = ((address * nat), nat) map

let inc_balance (s, tx_dest
    : balance_storage * transfer_destination_descriptor) : balance_storage =
   match tx_dest.to_ with
  | None -> s
  | Some to_ ->
    if to_ <> Tezos.self_address
    then s
    else
      let key = Tezos.sender, tx_dest.token_id in
      let old_bal = Big_map.find_opt key s in
      let new_bal = match old_bal with
      | None -> tx_dest.amount
      | Some bal -> bal + tx_dest.amount
      in
      Big_map.update key (Some new_bal) s

let update_balance_on_receive (p, storage
    : transfer_descriptor_param * balance_storage) : balance_storage =
  List.fold 
    (fun (s, tx : balance_storage * transfer_descriptor) -> 
      List.fold (fun (s, tx_dest : balance_storage * transfer_destination_descriptor) ->
        inc_balance (s, tx_dest)
      ) tx.txs s
    ) p.batch storage

let dec_balance (s, tx_dest
    : balance_storage * transfer_destination_descriptor) : balance_storage =
  let key = Tezos.sender, tx_dest.token_id in
  let old_bal_opt = Big_map.find_opt key s in
  let old_bal = match old_bal_opt with
  | None -> 0n
  | Some bal -> bal
  in
  let new_bal = match is_nat (old_bal - tx_dest.amount) with
  | None -> (failwith "NEGATIVE BALANCE" : nat)
  | Some bal -> bal
  in
  Big_map.update key (Some new_bal) s

let update_balance_on_sent (p, storage
    : transfer_descriptor_param * balance_storage) : balance_storage =
  List.fold 
    (fun (s, tx : balance_storage * transfer_descriptor) ->
      match tx.from_ with
      | None -> s
      | Some from_ ->
        if from_ <> Tezos.self_address
        then s
        else
          List.fold (fun (s, tx_dest : balance_storage * transfer_destination_descriptor) ->
            dec_balance(s, tx_dest)
          ) tx.txs s
    ) p.batch storage


let token_owner_with_hooks_main (param, storage : dummy_entry_points * balance_storage) =
  match param with
  | Owner op -> 
    let ops, u = token_owner_main (op, unit) in
    ops, storage
 
  | Tokens_received pm -> 
    let new_s = update_balance_on_receive (pm, storage) in
    ([] : operation list), new_s
  
  | Tokens_sent pm ->
    let new_s = update_balance_on_sent (pm, storage) in
    ([] : operation list), new_s

