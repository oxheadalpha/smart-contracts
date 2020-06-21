#include "token_owner.mligo"

type sorter_entry_points =
| Owner of token_owner
| Tokens_received of transfer_descriptor_param_michelson

(* (fa2, token_id) -> destination *)
type dispatch_table = ((address * nat), address) big_map

type tokens_to_transfer = (nat, nat) map

let inc_balance (acc, tx_dest : tokens_to_transfer * transfer_destination_descriptor)
    : tokens_to_transfer =
  let old_bal = Map.find_opt tx_dest.token_id acc in
  let new_bal = match old_bal with
  | None -> tx_dest.amount
  | Some bal -> bal + tx_dest.amount
  in
  Map.update tx_dest.token_id (Some new_bal) acc

let forward_tokens (pm, storage
    : transfer_descriptor_param_michelson * dispatch_table) : operation list =
  let p = transfer_descriptor_param_from_michelson pm in
  let tokens_to_transfer = List.fold 
    (fun (acc, tx : tokens_to_transfer * transfer_descriptor) ->
      List.fold 
        (fun (acc, tx_dest : tokens_to_transfer * transfer_destination_descriptor) ->
          match tx_dest.to_ with
          | None -> acc
          | Some to_ ->
            if to_ <> Tezos.self_address
            then acc
            else
              inc_balance (acc, tx_dest)
        ) tx.txs acc
    ) p.batch (Map.empty : tokens_to_transfer) in

  let new_destinations = Map.fold 
    (fun (acc, token_entry : (transfer_destination list) * (nat * nat)) ->
      let token_id, token_amount = token_entry in
      let destination = Big_map.find_opt (Tezos.sender, token_id) storage in
      match destination with
      | None -> (failwith "UNKNOWN TOKEN" : transfer_destination list)
      | Some account -> 
        let dst : transfer_destination = {
          to_ = account;
          token_id = token_id;
          amount = token_amount;
        } in
        dst :: acc
    ) tokens_to_transfer ([] : transfer_destination list) in
  let tx : transfer = {
    from_ = Tezos.self_address;
    txs = new_destinations;
  } in

  let txm = transfer_to_michelson tx in
  let fa2_entry : ((transfer_michelson list) contract) option = 
    Operation.get_entrypoint_opt "%transfer"  Tezos.sender in
  let callback_op = match fa2_entry with
  | None -> (failwith "CANNOT CALLBACK FA2" : operation)
  | Some c -> Operation.transaction [txm] 0mutez c
  in
  [callback_op]

let token_sorter_main (param, storage : sorter_entry_points * dispatch_table) =
  match param with
  | Owner op -> 
    let ops, u = token_owner_main (op, unit) in
    ops, storage
 
  | Tokens_received pm -> 
    let ops = forward_tokens (pm, storage) in
    ops, storage


let sample_storage : dispatch_table = Big_map.literal [
            ((("KT1WLmDye4maMYon7DJnYmJbRkxEkvf8nau3" : address), 0n), ("KT1MZe2n9oyX5TgytXGqGZCvbYSH7w25Pbhm" : address));
            ((("KT1WLmDye4maMYon7DJnYmJbRkxEkvf8nau3" : address), 1n), ("KT1SQ6tX4farjq6LWwYj3csXbEeEu64ufdB2" : address));
            ((("KT1WLmDye4maMYon7DJnYmJbRkxEkvf8nau3" : address), 2n), ("KT1PxWRymF52hLjTGsAhtfYpFi7trBY77Gaz" : address));
                    ]