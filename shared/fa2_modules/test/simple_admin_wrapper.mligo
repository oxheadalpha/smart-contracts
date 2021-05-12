(*
  Wrapper around simple_admin for testing:
  embeds simple_admin.mligo and includes `unit` entrypoints
  that trigger `fail_if_not_admin`, `fail_if_paused`
*)

#include "../simple_admin.mligo"

type wrapper_storage = {
  admin : simple_admin_storage;
}

type wrapper_param =
  | Admin of simple_admin
  | Fail_if_not_admin of unit
  | Fail_if_paused of unit

let wrapper_main
    (param, s : wrapper_param * wrapper_storage)
    : (operation list) * wrapper_storage =
  match param with
  | Admin p ->
      let ops, admin : (operation_list * address) = simple_admin (p, s.admin) in
      let new_s : wrapper_storage = { s with admin = admin; } in
      (ops, new_s)

  | Fail_if_not_admin p ->
      let u : unit = fail_if_not_admin s.admin in
      (([]: operation list), s)

  | Fail_if_paused p ->
      let u : unit = fail_if_paused s.admin in
      (([]: operation list), s)

