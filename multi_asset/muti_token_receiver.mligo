(*
  This is stub implementation of `multi_token_receiver` interface which
  accepts transfer of any token.
*)

#include "multi_token_interface.mligo"

let receiver_stub (p : multi_token_receiver) (s : unit) : (operation list) * unit =
  (([] : operation list), unit)