(*
  Wrapper around simple_admin for testing:
  embeds simple_admin.mligo and includes `unit` entrypoints
  that trigger `fail_if_not_admin`, `fail_if_paused`
*)

#include "../simple_admin.mligo"

module SimpleAdminWrapper = struct

  type wrapper_storage =  Admin.storage
  type return = operation list * wrapper_storage

  [@entry] let admin (p : Admin.entrypoints) (s : wrapper_storage) : return =
    Admin.main (p, s)

  [@entry] let fail_if_not_admin (_ : unit) (s : wrapper_storage) : return =
    let _ = Admin.fail_if_not_admin s in
    (([]: operation list), s)

  [@entry] let fail_if_paused  (_ : unit) (s : wrapper_storage) : return =
    let _ = Admin.fail_if_paused s in
    (([]: operation list), s)

end
