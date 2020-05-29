#if !FA2_BEHAVIORS
#define FA2_BEHAVIORS

(* #include "fa2_hook_lib.mligo" *)
#include "../fa2_interface.mligo"
#include "../fa2_errors.mligo"


(** generic transfer hook implementation. Behavior is driven by `permissions_descriptor` *)

type get_owners = transfer_descriptor -> (address option) list
type to_hook = address -> ((transfer_descriptor_param_michelson contract) option * string)
type transfer_hook_params = {
  ligo_param : transfer_descriptor_param;
  michelson_param : transfer_descriptor_param_michelson;
}

let get_owners_from_batch (batch, get_owners : (transfer_descriptor list) * get_owners) : address set =
  List.fold 
    (fun (acc, tx : (address set) * transfer_descriptor) ->
      let owners = get_owners tx in
      List.fold 
        (fun (acc, o: (address set) * (address option)) ->
          match o with
          | None -> acc
          | Some a -> Set.add a acc
        )
        owners
        acc
    )
    batch
    (Set.empty : address set)

let validate_owner_hook (p, get_owners, to_hook, is_required :
    transfer_hook_params * get_owners * to_hook * bool)
    : operation list =
    let owners = get_owners_from_batch (p.ligo_param.batch, get_owners) in
    Set.fold 
      (fun (ops, owner : (operation list) * address) ->
        let hook, error = to_hook owner in
        match hook with
        | Some h ->
          let op = Operation.transaction p.michelson_param 0mutez h in
          op :: ops
        | None ->
          if is_required
          then (failwith error : operation list)
          else ops)
      owners ([] : operation list)

let validate_owner(p, policy, get_owners, to_hook : 
    transfer_hook_params * owner_hook_policy * get_owners * to_hook)
    : operation list =
  match policy with
  | Owner_no_hook -> ([] : operation list)
  | Optional_owner_hook -> validate_owner_hook (p, get_owners, to_hook, false)
  | Required_owner_hook -> validate_owner_hook (p, get_owners, to_hook, true)

let to_receiver_hook : to_hook = fun (a : address) ->
    let c : (transfer_descriptor_param_michelson contract) option = 
    Operation.get_entrypoint_opt "%tokens_received" a in
    c, receiver_hook_undefined

let validate_receivers (p, policy : transfer_hook_params * owner_hook_policy)
    : operation list =
  let get_receivers : get_owners = fun (tx : transfer_descriptor) -> 
    List.map (fun (t : transfer_destination_descriptor) -> t.to_ )tx.txs in
  validate_owner (p, policy, get_receivers, to_receiver_hook)

let to_sender_hook : to_hook = fun (a : address) ->
    let c : (transfer_descriptor_param_michelson contract) option = 
    Operation.get_entrypoint_opt "%tokens_sent" a in
    c, sender_hook_undefined

let validate_senders (p, policy : transfer_hook_params * owner_hook_policy)
    : operation list =
  let get_sender : get_owners = fun (tx : transfer_descriptor) -> [tx.from_] in
  validate_owner (p, policy, get_sender, to_sender_hook)

let standard_transfer_hook (p, descriptor : transfer_hook_params * permissions_descriptor)
    : operation list =
  let sender_ops = validate_senders (p, descriptor.sender) in
  let receiver_ops = validate_receivers (p, descriptor.receiver) in
  (* merge two lists *)
  List.fold (fun (l, o : (operation list) * operation) -> o :: l) receiver_ops sender_ops

#endif
