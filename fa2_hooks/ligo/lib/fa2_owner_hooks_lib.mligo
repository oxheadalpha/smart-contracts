#if !FA2_BEHAVIORS
#define FA2_BEHAVIORS

(** 
Generic implementation of the permission logic for sender and receiver hooks. 
Actual behavior is driven by a `permissions_descriptor`.
To be used in FA2 and/or FA2 permission transfer hook contract implementation
which supports sender/receiver hooks.
*)

#include "../fa2_interface.mligo"
#include "../fa2_errors.mligo"

type get_owners = transfer_descriptor -> (address option) list

type hook_result =
  | Hook_contract of transfer_descriptor_param_michelson contract
  | Hook_undefined of string

type to_hook = address -> hook_result

type transfer_hook_params = {
  ligo_param : transfer_descriptor_param;
  michelson_param : transfer_descriptor_param_michelson;
}

(**
Extracts a set of unique `from_` or `to_` addresses from the transfer batch.
@param batch transfer batch
@param get_owner selector of `from_` or `to_` addresses from each individual `transfer_descriptor`
 *)
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
        match to_hook owner with
        | Hook_contract h ->
          let op = Operation.transaction p.michelson_param 0mutez h in
          op :: ops
        | Hook_undefined error ->
          (* owner hook is not implemented by the target contract *)
          if is_required
          then (failwith error : operation list) (* owner hook is required: fail *)
          else ops (* owner hook is optional: skip it *)
        )
      owners ([] : operation list)

let validate_owner(p, policy, get_owners, to_hook : 
    transfer_hook_params * owner_hook_policy * get_owners * to_hook)
    : operation list =
  match policy with
  | Owner_no_hook -> ([] : operation list)
  | Optional_owner_hook -> validate_owner_hook (p, get_owners, to_hook, false)
  | Required_owner_hook -> validate_owner_hook (p, get_owners, to_hook, true)

(**
Given an address of the token receiver, tries to get an entry point for
`fa2_token_receiver` interface.
 *)
let to_receiver_hook : to_hook = fun (a : address) ->
    let c : (transfer_descriptor_param_michelson contract) option = 
    Operation.get_entrypoint_opt "%tokens_received" a in
    match c with
    | Some c -> Hook_contract c
    | None -> Hook_undefined fa2_receiver_hook_undefined

(**
Create a list iof Tezos operations invoking all token receiver contracts that
implement `fa2_token_receiver` interface. Fail if specified `owner_hook_policy`
cannot be met.
 *)
let validate_receivers (p, receiver_policy : transfer_hook_params * owner_hook_policy)
    : operation list =
  let get_receivers : get_owners = fun (tx : transfer_descriptor) -> 
    List.map (fun (t : transfer_destination_descriptor) -> t.to_ )tx.txs in
  validate_owner (p, receiver_policy, get_receivers, to_receiver_hook)

(**
Given an address of the token sender, tries to get an entry point for
`fa2_token_sender` interface.
 *)
let to_sender_hook : to_hook = fun (a : address) ->
    let c : (transfer_descriptor_param_michelson contract) option = 
    Operation.get_entrypoint_opt "%tokens_sent" a in
    match c with
    | Some c -> Hook_contract c
    | None -> Hook_undefined fa2_sender_hook_undefined

(**
Create a list iof Tezos operations invoking all token sender contracts that
implement `fa2_token_sender` interface. Fail if specified `owner_hook_policy`
cannot be met.
 *)
let validate_senders (p, sender_policy : transfer_hook_params * owner_hook_policy)
    : operation list =
  let get_sender : get_owners = fun (tx : transfer_descriptor) -> [tx.from_] in
  validate_owner (p, sender_policy, get_sender, to_sender_hook)

(**
Generate a list of Tezos operations invoking sender and receiver hooks according to
the policies defined by the permissions descriptor.
To be used in FA2 and/or FA2 transfer hook contract implementation which supports
sender/receiver hooks.
 *)
let owners_transfer_hook (p, descriptor : transfer_hook_params * permissions_descriptor)
    : operation list =
  let sender_ops = validate_senders (p, descriptor.sender) in
  let receiver_ops = validate_receivers (p, descriptor.receiver) in
  (* merge two lists *)
  List.fold (fun (l, o : (operation list) * operation) -> o :: l) receiver_ops sender_ops


let transfers_to_descriptors (txs : transfer list) : transfer_descriptor list =
  List.map 
    (fun (tx : transfer) ->
      let txs = List.map 
        (fun (dst : transfer_destination) ->
          {
            to_ = Some dst.to_;
            token_id = dst.token_id;
            amount = dst.amount;
          }
        ) tx.txs in
        {
          from_ = Some tx.from_;
          txs = txs;
        }
    ) txs 

#endif
