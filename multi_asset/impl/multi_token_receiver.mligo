(*
  This is stub implementation of `multi_token_receiver` interface which
  accepts transfer of any token.
*)

#include "../multi_token_interface.mligo"

type receiver_add_operator_param = {
  mac : address;
  operator : address;
}

type receiver =
  | Multi_token_receiver of multi_token_receiver
  | Add_operator of receiver_add_operator_param
  | Default of unit

(*
  This receiver implementation is WIP and may result in locked tokens.
  The implementation needs to include entry points to either initiate tokens
  transfer from this contract and/or add operators who can transfer tokens on
  behalf of this contract.
  Adding additional non `multi_token_receiver` entry points are pending on
  LIGO support for multi entry points
*)
let receiver_stub (p : receiver) (s : unit) : (operation list) * unit =
  match p with
  | Multi_token_receiver r -> (([] : operation list), unit)
  | Add_operator p ->
    let mac : address contract = Operation.get_entrypoint "%add_operator" p.mac in
    let op = Operation.transaction p.operator 0mutez mac in
    [op], unit
  | Default u -> (([] : operation list), unit)
  