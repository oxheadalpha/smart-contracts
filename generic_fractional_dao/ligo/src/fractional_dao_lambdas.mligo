#include "fractional_dao.mligo"

(**
Lambda constructor function to be used with ligo compile-expression command
to generate actual lambda code enclosing the parameters
 *)

let set_dao_voting_threshold (old_threshold, new_threshold : nat * nat): dao_lambda =
  fun (u : unit) -> (
    let dao_entry : set_voting_threshold_param contract option =
      Tezos.get_entrypoint_opt "%set_voting_threshold" Tezos.self_address in
    match dao_entry with
    | None -> (failwith "NO_DAO_SET_VOTING_THRESHOLD" : operation list)
    | Some dao ->
      let param = {
        old_threshold = old_threshold;
        new_threshold = new_threshold; } in
      let op = Tezos.transaction param 0mutez dao in
      [op]
  )

let set_dao_voting_period (old_period, new_period : nat * nat): dao_lambda =
  fun (u : unit) -> (
    let dao_entry : set_voting_period_param contract option =
      Tezos.get_entrypoint_opt "%set_voting_period" Tezos.self_address in
    match dao_entry with
    | None -> (failwith "NO_DAO_SET_VOTING_PERIOD" : operation list)
    | Some dao ->
      let param = {
        old_period = old_period;
        new_period = new_period; } in
      let op = Tezos.transaction param 0mutez dao in
      [op]
  )

let dao_transfer_fa2_tokens (fa2, txs: address * transfer list) : dao_lambda =
  fun (u : unit) -> (
    let fa2_entry : transfer list contract option =
      Tezos.get_entrypoint_opt "%transfer" fa2 in
    match fa2_entry with
    | None -> (failwith "NO_FA2_TRANSFER" : operation list)
    | Some fa2 ->
      let op = Tezos.transaction txs 0mutez fa2 in
      [op]
  )

let dao_update_fa2_operators (fa2, ops: address * update_operator list) : dao_lambda =
  fun (u : unit) -> (
    let fa2_entry : update_operator list contract option =
      Tezos.get_entrypoint_opt "%update_operators" fa2 in
    match fa2_entry with
    | None -> (failwith "NO_FA2_UPDATE_OPERATORS" : operation list)
    | Some fa2 ->
      let op = Tezos.transaction ops 0mutez fa2 in
      [op]
  )
