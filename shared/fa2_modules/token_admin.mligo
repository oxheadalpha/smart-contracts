(*
  One of the possible implementations of admin API for FA2 contract.
  The admin API can change an admin address using two step confirmation pattern and
  pause/unpause transfer per token type.
  Only current admin can initiate those operations.
  
  Other entry points may guard their access using helper functions
  `fail_if_not_admin` and `fail_if_paused`.
*)

#if !TOKEN_ADMIN
#define TOKEN_ADMIN

#include "../fa2/fa2_interface.mligo"

module Admin = struct

  type paused_tokens_set = (token_id, unit) big_map

  type pause_param = 
  [@layout:comb]
  {
    token_id : token_id;
    paused : bool;
  }

  type entrypoints =
    | Set_admin of address
    | Confirm_admin of unit
    | Pause of pause_param list


  type storage = {
    admin : address;
    pending_admin : address option;
    paused : paused_tokens_set;
  }

  let set_admin (new_admin, s : address * storage) : storage =
    { s with pending_admin = Some new_admin; }

  let confirm_new_admin (s : storage) : storage =
    match s.pending_admin with
    | None -> (failwith "NO_PENDING_ADMIN" : storage)
    | Some pending ->
      let sender = Tezos.get_sender () in
      if sender = pending
      then { s with 
        pending_admin = (None : address option);
        admin = sender;
      }
      else (failwith "NOT_A_PENDING_ADMIN" : storage)


  let pause (tokens, s: (pause_param list) * storage) : storage =
    let new_paused = List.fold 
      (fun (paused_set, t : paused_tokens_set * pause_param) -> 
        if t.paused
        then Big_map.add t.token_id unit paused_set
        else Big_map.remove t.token_id paused_set
      )
      tokens s.paused in
    { s with paused = new_paused; }

  let fail_if_not_admin (a : storage) : unit =
    if (Tezos.get_sender ()) <> a.admin
    then failwith "NOT_AN_ADMIN"
    else ()

  let fail_if_paused_tokens (transfers, paused : transfer list * paused_tokens_set) : unit =
    List.iter 
      (fun (tx: transfer) ->
        List.iter (fun (txd : transfer_destination) -> 
          if Big_map.mem txd.token_id paused
          then failwith "TOKEN_PAUSED"
          else ()
        ) tx.txs
      ) transfers

  let fail_if_paused (a, param : storage * fa2_entry_points) : unit =
    match param with
    | Balance_of _ -> ()
    | Update_operators _ -> ()
    | Transfer transfers -> fail_if_paused_tokens(transfers, a.paused)
    

  let main (param, s : entrypoints * storage) : (operation list) * storage =
    match param with
    | Set_admin new_admin ->
      let _ = fail_if_not_admin s in
      let new_s = set_admin (new_admin, s) in
      (([]: operation list), new_s)

    | Confirm_admin u ->
      let new_s = confirm_new_admin s in
      (([]: operation list), new_s)

    | Pause tokens ->
      let _ = fail_if_not_admin s in
      let new_s = pause (tokens, s) in
      (([]: operation list), new_s)

end

#endif
