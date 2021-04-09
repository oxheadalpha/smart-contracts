#include "fractional_dao.mligo"

(**
Lambda constructor function to be used with ligo compile-expression command
to generate actual lambda code enclosing the parameters
 *)

let set_dao_voting_threshold (dao_address, old_threshold, new_threshold :
    address * nat * nat): dao_lambda =
  fun (u : unit) -> (
    let dao_entry : set_voting_threshold_param contract option =
      Tezos.get_entrypoint_opt "%set_voting_threshold" dao_address in
    match dao_entry with
    | None -> (failwith "NO_DAO_ENTRYPOINT" : operation list)
    | Some dao ->
      let param = {
        old_threshold = old_threshold;
        new_threshold = new_threshold; } in
      let op = Tezos.transaction param 0mutez dao in
      [op]
  )

let set_dao_voting_period (dao_address, old_period, new_period :
    address * nat * nat): dao_lambda =
  fun (u : unit) -> (
    let dao_entry : set_voting_threshold_param contract option =
      Tezos.get_entrypoint_opt "%set_voting_period" dao_address in
    match dao_entry with
    | None -> (failwith "NO_DAO_ENTRYPOINT" : operation list)
    | Some dao ->
      let param = {
        old_period = old_period;
        new_period = new_period; } in
      let op = Tezos.transaction param 0mutez dao in
      [op]
  )
