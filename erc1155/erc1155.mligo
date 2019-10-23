type token_id = nat

type safe_transfer_from_param = {
  from: address;      (* Source address *)
  to_:   address;     (* Target address. Target smart contract must implement entry points from `erc1155_receiver` interface *)
  token_id: token_id; (* ID of the token type *)
  amount: nat;        (* Transfer amount *)
  data: bytes;        (* Additional data with no specified format, MUST be sent unaltered in call to `On_erc1155_received` on `to_` *)
}

type tx = {
  token_id: token_id; (* ID of the token type *)
  amount: nat;        (* Transfer amount *)
}

type safe_batch_transfer_from_param = {
  from: address;      (* Source address *)
  to_:   address;     (* Target address. Target smart contract must implement entry points from `erc1155_receiver` interface *)
  batch: tx list;     (* Batch of tokens and their amounts to be transfered *)
  data: bytes;        (* Additional data with no specified format, MUST be sent unaltered in call to `On_erc1155_batch_received` on `to_` *)
}

type balance_request = {
  owner: address;     (* The address of the token holder *)
  token_id: token_id; (* ID of the  token *)
}

type balance_of_param = {
  balance_request: balance_request;
  balance_view: balance_request * nat -> operation;
}

type balance_of_batch_param = {
  balance_request: balance_request list;
  balance_view: balance_request * nat list -> operation;
}

type set_approval_for_all_param = {
  operator: address;  (* Address to add or remove from the set of authorized operators for sender *)
  approved: bool;     (* True if the operator is approved, false to revoke approval *)
}

type is_approved_for_all_request = {
  owner: address;     (* The owner of the tokens *)
  operator: address;  (* Address of authorized operator *)
}
type is_approved_for_all_param = {
  is_approved_for_all_request: is_approved_for_all_request;
  approved_view: is_approved_for_all_request * bool -> operation
}

(* ERC1155 entry points *)
type erc1155 =
  (*
    Transfers specified `amount` of an `token_id` from the `from` address to the `to_` address specified (with safety call).
    Caller must be approved to manage the tokens being transferred out of the `from` account (see "Approval" section of the standard).
    MUST revert if balance of holder for token `token_id` is lower than the `amount` sent.
    MUST revert of `to_` contract does not implement entry point for `erc1155_token_receiver`.
    MUST call `On_erc1155_received` on `to_` and act appropriately (see "Safe Transfer Rules" section of the standard).
  *)
  | Safe_transfer_from of safe_transfer_from_param
  (*
    Transfers specified `amount`(s) of `token_id`(s) from the `from` address to the `to_` address specified (with safety call).
    Caller must be approved to manage the tokens being transferred out of the `from` account (see "Approval" section of the standard).
    MUST revert if any of the balance(s) of the holder(s) for token(s) is lower than the respective amount(s) in `_values` sent to the recipient.
    MUST revert of `to_` contract does not implement entry point for `erc1155_token_receiver`.
    MUST call the relevant `erc1155_token_receiver` hook(s) on `to_` and act appropriately (see "Safe Transfer Rules" section of the standard).    
  *)
  | Safe_batch_transfer_from of safe_batch_transfer_from_param
  (* Get the balance of an account's tokens. *)
  | Balance_of of balance_of_param
  (* Get the balance of multiple account/token pairs *)
  | Balance_of_batch of balance_of_batch_param
  (* Enable or disable approval for a third party ("operator") to manage all of the caller's tokens. *)
  | Set_approval_for_all of set_approval_for_all_param
  (* Queries the approval status of an operator for a given owner. *)
  | Is_approved_for_all of is_approved_for_all_param


type on_erc1155_received_param = {
  operator: address;    (* The address which initiated the transfer (i. e. sender) *)
  from: address option; (* Source address. None for minting operation *)
  token_id: token_id;   (* ID of the token type *)
  amount: nat;          (* Transfer amount *)
  data: bytes;          (* Additional data with no specified format *)
}

type on_erc1155_batch_received_param = {
  operator: address;    (* The address which initiated the transfer (i. e. sender) *)
  from: address option; (* Source address. None for minting operation *)
  batch: tx list;       (* Batch of tokens and their amounts which are transferred *)
  data: bytes;          (* Additional data with no specified format *)
}

(* ERC1155TokenReceiver entry points *)
type erc1155_token_receiver =
  (*
    Handle the receipt of a single ERC1155 token type.
    An ERC1155-compliant smart contract MUST call this function on the token recipient
    contract from a `Safe_transfer_from`.
    MUST revert if it rejects the transfer.
  *)
  | On_erc1155_received of on_erc1155_received_param
  (*
    Handle the receipt of multiple ERC1155 token types.
    An ERC1155-compliant smart contract MUST call this function on the token recipient 
    contract from a `Safe_batch_transfer_from`.
    MUST revert if it rejects the transfer(s).
  *)
  | On_erc1155_batch_received of on_erc1155_batch_received_param


let test(u: unit) = 77
