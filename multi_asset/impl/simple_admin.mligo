(*
  One of the possible implementations of admin API for `multi_token` contract.

  Only current `admin` of the contract can invoke admin API.
  Admin API allows to 
  
    1. Change administrator, 
    2. Pause the contract.
*)

(* `simple_admin` entry points *)
type simple_admin =
  | Set_admin of address
  | Pause of bool


type simple_admin_storage = {
  admin : address;
  paused : bool;
}

let set_admin (new_admin: address) (s: simple_admin_storage) : simple_admin_storage =
  {
    admin = new_admin;
    paused = s.paused;
  }

let pause (paused : bool) (s: simple_admin_storage) : simple_admin_storage =
  {
    admin = s.admin;
    paused = paused;
  }

let simple_admin (param, s : simple_admin *simple_admin_storage)
    : (operation list) * simple_admin_storage =
  if sender <> s.admin
  then 
    (failwith "operation requires admin privileges" : (operation list) * simple_admin_storage)
  else
    match param with
    | Set_admin new_admin ->
        let new_s = set_admin new_admin s in
        (([]: operation list), new_s)

    | Pause paused ->
        let new_s = pause paused s in
        (([]: operation list), new_s)

        

