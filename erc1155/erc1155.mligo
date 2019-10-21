

type token_id = nat
(*
  Token transfer
*)
type tx = {
  from: address;      (* source address *)
  to_:   address;     (* target address. Target smart contract must implement entry points from `erc1155_receiver` interface *)
  token_id: token_id; (* ID of the token type *)
  amount: nat;        (* transfer amount *)
}

type safe_transfer_from_param = {
  tx: tx;       (* transfer definition *)
  data: bytes;  (* Additional data with no specified format, MUST be sent unaltered in call to `OnERC1155Received` on `to_` *)
}

type safe_batch_transfer_from_param = {
  txs: tx list; (* batch of transaction definitions *)
  data: bytes;  (* Additional data with no specified format, MUST be sent unaltered in call to `OnERC1155BatchReceived` on `to_` *)
}

type balance_request = {
  owner: address;
  token_id: token_id;
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
  operator: address;
  approved: bool;
}

type is_approved_for_all = {
  owner: address;
  operator: address;
  approved_view: address*address*bool -> operation
}

(* ERC1155 entry points *)
type erc1155 =
  | SafeTransferFrom of safe_transfer_from_param
  | SafeBatchTransferFrom of safe_batch_transfer_from_param
  | BalanceOf of balance_of_param
  | BalanceOfBatch of balance_of_batch_param
  | SetApprovalForAll of set_approval_for_all_param
  | IsApprovedForAll of is_approved_for_all
  | Default of unit


type on_erc1155_received_param = {
  operator: address;
  tx: tx;
  data: bytes;
}

type on_erc1155_batch_received_param = {
  operator: address;
  txs: tx list;
  data: bytes;
}

(* ERC1155Receiver entry points *)
type erc1155_token_receiver =
  | OnERC1155Received of on_erc1155_received_param
  | OnERC1155BatchReceived of on_erc1155_batch_received_param
  | Default of unit


let test(u: unit) = 77
