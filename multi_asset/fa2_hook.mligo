#include "fa2_interface.mligo"

type hook_transfer = {
  from_ : address option;
  to_ : address option;
  token_id : token_id;
  amount : nat;
}

type hook_param = {
  batch : hook_transfer list;
  operator : address;
}

type set_hook_param = {
  hook : address;
  config : permission_policy_config list;
}

type fa2_with_hook_entry_points =
  | Fa2 of fa2_entry_points
  | Set_transfer_hook of set_hook_param 