#include "fa2_interface.mligo"


type set_hook_param = {
  hook : unit -> transfer_descriptor_param contract;
  permissions_descriptor : permissions_descriptor;
}

type fa2_with_hook_entry_points =
  | Fa2 of fa2_entry_points
  | Set_transfer_hook of set_hook_param