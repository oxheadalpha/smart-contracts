(*
  One of the possible implementations of admin API for FA2 contract.
  The admin API can change an admin address using two step confirmation pattern and
  pause/unpause the contract. Only current admin can initiate those operations.
  
  Other entry points may guard their access using helper functions
  `fail_if_not_admin` and `fail_if_paused`.
*)

#if !SIMPLE_ADMIN
#define SIMPLE_ADMIN

#include "./admin_sig.mligo"

module Admin : AdminSig = struct

  type entrypoints =
    | Set_admin of address
    | Confirm_admin of unit
    | Pause of bool


  type storage = {
    admin : address;
    pending_admin : address option;
    paused : bool;
  }

  let set_admin (new_admin, s : address * storage) : storage =
    { s with pending_admin = Some new_admin; }

  let confirm_new_admin (s : storage) : storage =
    match s.pending_admin with
    | None -> (failwith "NO_PENDING_ADMIN" : storage)
    | Some pending ->
      let sender = Tezos.get_sender() in
      if sender = pending
      then {s with 
        pending_admin = (None : address option);
        admin = sender;
      }
      else (failwith "NOT_A_PENDING_ADMIN" : storage)


  let pause (paused, s: bool * storage) : storage =
    { s with paused = paused; }

  let fail_if_not_admin (a : storage) : unit =
    if (Tezos.get_sender()) <> a.admin
    then failwith "NOT_AN_ADMIN"
    else unit

  let fail_if_paused (a : storage) : unit =
    if a.paused
    then failwith "PAUSED"
    else unit

  let main (param, s : entrypoints * storage)
      : (operation list) * storage =
    match param with
    | Set_admin new_admin ->
      let _ = fail_if_not_admin s in
      let new_s = set_admin (new_admin, s) in
      (([]: operation list), new_s)

    | Confirm_admin _ ->
      let new_s = confirm_new_admin s in
      (([]: operation list), new_s)

    | Pause paused ->
      let _ = fail_if_not_admin s in
      let new_s = pause (paused, s) in
      (([]: operation list), new_s)

end

#endif
