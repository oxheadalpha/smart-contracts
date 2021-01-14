(**
Implementation of the FA2 interface for the single token contract.
 *)


#if !FA2_SINGLE_TOKEN
#define FA2_SINGLE_TOKEN

#include "../fa2/fa2_interface.mligo"
#include "../fa2/fa2_permissions_descriptor.mligo"
#include "../fa2/fa2_errors.mligo"
#include "../fa2/lib/fa2_operator_lib.mligo"
#include "../fa2/lib/fa2_owner_hooks_lib.mligo"


type ledger = (address, nat) big_map

#if !OWNER_HOOKS

type single_token_storage = {
  ledger : ledger;
  operators : operator_storage;
  token_metadata : (nat, token_metadata) big_map;
  total_supply : nat;
}

#else

type single_token_storage = {
  ledger : ledger;
  operators : operator_storage;
  token_metadata : (nat, token_metadata) big_map;
  total_supply : nat;
  permissions : permissions_descriptor;
}

#endif

let get_balance_amt (owner, ledger : address  * ledger) : nat =
  let bal_opt = Big_map.find_opt owner ledger in
  match bal_opt with
  | None -> 0n
  | Some b -> b

let inc_balance (owner, amt, ledger
    : address * nat * ledger) : ledger =
  let bal = get_balance_amt (owner, ledger) in
  let updated_bal = bal + amt in
  if updated_bal = 0n
  then Big_map.remove owner ledger
  else Big_map.update owner (Some updated_bal) ledger 

let dec_balance (owner, amt, ledger
    : address * nat * ledger) : ledger =
  let bal = get_balance_amt (owner, ledger) in
  match Michelson.is_nat (bal - amt) with
  | None -> (failwith fa2_insufficient_balance : ledger)
  | Some new_bal ->
    if new_bal = 0n
    then Big_map.remove owner ledger
    else Big_map.update owner (Some new_bal) ledger

(**
Update leger balances according to the specified transfers. Fails if any of the
permissions or constraints are violated.
@param txs transfers to be applied to the ledger
@param validate_op function that validates of the tokens from the particular owner and token id can be transferred. 
 *)
let transfer (txs, validate_op, ops_storage, ledger
    : (transfer_descriptor list) * operator_validator * operator_storage * ledger)
    : ledger =
  let make_transfer = fun (l, tx : ledger * transfer_descriptor) ->
    List.fold 
      (fun (ll, dst : ledger * transfer_destination_descriptor) ->
        if dst.token_id <> 0n
        then (failwith fa2_token_undefined : ledger)
        else
          let lll = match tx.from_ with
          | None -> ll (* this is a mint transfer. do not need to update `from_` balance *)
          | Some from_ -> 
            let u = validate_op (from_, Tezos.sender, dst.token_id, ops_storage) in
            dec_balance (from_, dst.amount, ll)
          in 
          match dst.to_ with
          | None -> lll (* this is a burn transfer. do not need to update `to_` balance *)
          | Some to_ -> inc_balance(to_, dst.amount, lll) 
      ) tx.txs l
  in    
  List.fold make_transfer txs ledger

(** 
Retrieve the balances for the specified tokens and owners
@return callback operation
*)
let get_balance (p, ledger : balance_of_param * ledger) : operation =
  let to_balance = fun (r : balance_of_request) ->
    if r.token_id <> 0n
    then (failwith fa2_token_undefined : balance_of_response)
    else
      let bal = get_balance_amt (r.owner, ledger) in
      let response : balance_of_response = { request = r; balance = bal; } in
      response
  in
  let responses = List.map to_balance p.requests in
  Tezos.transaction responses 0mutez p.callback

(** Validate if all provided token_ids are `0n` and correspond to a single token ID *)
let validate_token_ids (tokens : token_id list) : unit =
  List.iter (fun (id : nat) ->
    if id = 0n then unit else failwith fa2_token_undefined
  ) tokens


#if !OWNER_HOOKS

let get_owner_hook_ops (tx_descriptors, storage
    : (transfer_descriptor list) * single_token_storage) : operation list =
  ([] : operation list)

#else 

let get_owner_hook_ops (tx_descriptors, storage
    : (transfer_descriptor list) * single_token_storage) : operation list =
  let tx_descriptor_param : transfer_descriptor_param = {
    batch = tx_descriptors;
    operator = Tezos.sender;
  } in
  get_owner_hook_ops_for (tx_descriptor_param, storage.permissions)

#endif

let fa2_transfer (tx_descriptors, validate_op, storage
    : (transfer_descriptor list) * operator_validator * single_token_storage)
    : (operation list) * single_token_storage =
  
  let new_ledger = transfer (tx_descriptors, validate_op, storage.operators, storage.ledger) in
  let new_storage = { storage with ledger = new_ledger; } in
  let ops = get_owner_hook_ops (tx_descriptors, storage) in
  ops, new_storage

let fa2_main (param, storage : fa2_entry_points * single_token_storage)
    : (operation  list) * single_token_storage =
  match param with
  | Transfer txs -> 
    (* convert transfer batch into `transfer_descriptor` batch *)
    let tx_descriptors = transfers_to_descriptors txs in
    (* 
    will validate that a sender is either `from_` parameter of each transfer
    or a permitted operator for the owner `from_` address.
    *)
    fa2_transfer (tx_descriptors, default_operator_validator, storage)

  | Balance_of p ->
    let op = get_balance (p, storage.ledger) in
    [op], storage

  | Update_operators updates ->
    let new_ops = fa2_update_operators (updates, storage.operators) in
    let new_storage = { storage with operators = new_ops; } in
    ([] : operation list), new_storage



#endif
