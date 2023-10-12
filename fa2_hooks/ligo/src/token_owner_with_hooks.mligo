#include "../fa2_clients/token_owner.mligo"


module TokenOwnerWithHooks = struct


  (** (fa2, token_id) -> own_balance *)
  type balance_storage = ((address * nat), nat) map

  let inc_balance (s, tx_dest
      : balance_storage * transfer_destination_descriptor) : balance_storage =
    match tx_dest.to_ with
    | None -> s
    | Some to_ ->
      if to_ <> (Tezos.get_self_address ())
      then s
      else
        let key = (Tezos.get_sender()), tx_dest.token_id in
        let old_bal = Map.find_opt key s in
        let new_bal = match old_bal with
        | None -> tx_dest.amount
        | Some bal -> bal + tx_dest.amount
        in
        Map.update key (Some new_bal) s

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
    let key = (Tezos.get_sender()), tx_dest.token_id in
    let old_bal_opt = Map.find_opt key s in
    let old_bal = match old_bal_opt with
    | None -> 0n
    | Some bal -> bal
    in
    let new_bal = match is_nat (old_bal - tx_dest.amount) with
    | None -> (failwith "NEGATIVE BALANCE" : nat)
    | Some bal -> bal
    in
    Map.update key (Some new_bal) s

  let update_balance_on_sent (p, storage
      : transfer_descriptor_param * balance_storage) : balance_storage =
    List.fold 
      (fun (s, tx : balance_storage * transfer_descriptor) ->
        match tx.from_ with
        | None -> s
        | Some from_ ->
          if from_ <> (Tezos.get_self_address ())
          then s
          else
            List.fold (fun (s, tx_dest : balance_storage * transfer_destination_descriptor) ->
              dec_balance(s, tx_dest)
            ) tx.txs s
      ) p.batch storage

  type return = operation list * balance_storage

  (* expose TokenOwner module entry points *)

  [@entry] let owner_add_operator
      (p : owner_operator_param) (s : balance_storage) : return =
    let ops, _ = TokenOwner.owner_add_operator p () in
    ops, s

  [@entry] let owner_remove_operator
      (p : owner_operator_param) (s : balance_storage) : return =
    let ops, _ = TokenOwner.owner_remove_operator p () in
    ops, s

  [@entry] let default (_ : unit) (s : balance_storage) : return =
    ([] : operation list), s

  (* just keeps balances of received tokens *)

  [@entry] let tokens_received
      (p : transfer_descriptor_param) (s : balance_storage) : return =
    let new_s = update_balance_on_receive (p, s) in
    ([] : operation list), new_s

  [@entry] let tokens_sent
      (p : transfer_descriptor_param) (s : balance_storage) : return =
    let new_s = update_balance_on_sent (p, s) in
    ([] : operation list), new_s

end
