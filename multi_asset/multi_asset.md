# Tezos multi-asset smart contract specification

## Abstract

This document describes specification for Tezos multi-asset contract adapted from
the corresponding specification for [Ethereum](https://eips.ethereum.org/EIPS/eip-1155).
Token standards like ERC-20 and ERC-721 require a separate contract to be deployed
for each token type or collection. Multi-asset contract manages multiple token types.
A new token can be created and configured without redeploying the contract. Both
fungible and non-fungible tokens can be stored in the same smart-contract.

This design enables new functionality, such as the transfer of multiple
token types at once, saving on transaction costs. Trading (escrow / atomic swaps)
of multiple tokens can be built on top of this standard as it removes the need
to “approve” individual token contracts separately. It is also easy to describe
and mix multiple fungible or non-fungible token types within a single contract.

## Multi-asset contract overview

**Token type** - a specific token represented by its ID. Non-fungible tokens can
be represented as ID ranges.

**Owner** - Tezos address which can hold tokens.

**Operator** - Tezos address which initiates token transfer operation.
**Operator** MUST be approved to manage all tokens held by the owner to make a
transfer from the owner account.

The destination address for a token transfer operation MUST implement
`multi_token_receiver` interface and/or be a whitelisted address before it can
receive any tokens. If destination address implements `multi_token_receiver`
interface, it MAY reject receiving tokens by generating a failure when called.
This is considered a safety feature ("safe transfer") to prevent unrecoverable
tokens if sent to an address that does not expect to receive tokens.

Multi-asset contract supports atomic batch transfer of multiple tokens between
two accounts. Either all transfers in a batch are successful or all of the transfers
are discarded.

Administrative operations to create new token types, mint and burn tokens are not
part of the multi-asset contract specification. Their implementation may differ
depending on the particular business use-case. This specification focuses on token
transfer logic only.

## Specification

Specification is given as definition of Michelson entry points defined in
[cameLIGO language](https://ligolang.org). Multi-asset specification consists of
two interfaces: `multi_token` and `multi_token_receiver`.

**Smart contracts implementing multi-asset standard protocol MUST implement all
of the entry points in the `multi_token` interface.**

**All addresses which can be a target destination for the token transfers
MUST be contracts which implement all of the entry points in the `multi_token_receiver`
interface and/or be whitelisted addresses.**

### `multi_token` entry points

```ocaml
type tx = {
  token_id : nat; (* ID of the token type *)
  amount : nat;   (* Transfer amount *)
}

type transfer_param = {
  (* Source address *)
  from_ : address;
  (* 
    Target address. Target smart contract MUST implement entry points from
    `multi_token_receiver` interface or be a whitelisted implicit account.
  *)
  to_ : address;
  (* Batch of tokens and their amounts to be transferred *)
  batch : tx list;
  (* 
    Additional data with no specified format, MUST be sent unaltered in call to
    `On_multi_tokens_received` on `to_` contract.
  *)
  data : bytes;
}

type balance_request = {
  owner : address; (* The address of the token holder *)
  token_id : nat;  (* ID of the  token *)
}

type balance_of_param = {
  balance_request : balance_request list;
  balance_view : ((balance_request * nat) list) contract;
}

type is_operator_request = {
  owner : address;    (* The owner of the tokens *)
  operator : address; (* Address of authorized operator *)
}
type is_operator_param = {
  is_operator_request : is_operator_request;
  is_operator_view : (is_operator_request * bool) contract
}

(* `multi-token` entry points *)
type multi_token =
  (*
    Transfers specified `amount`(s) of `token_id`(s) from the `from_` address to
    the `to_` address (with safety call).
    Caller must be approved to manage the tokens being transferred out of the
    `from_` account (see "Approval" section of the standard).
    MUST revert if any of the balance(s) of the holder for token(s) is lower
    than the respective amount(s) in amounts to be sent to the recipient.
    If `to_` contract does not implement `multi_token_receiver` interface or
    is not a whitelisted implicit account, the transaction MUST fail.
    MUST call `On_multi_tokens_received` hook defined by `multi_token_receiver`
    on `to_` and act appropriately (see "Safe Transfer Rules" section of the
    standard).
  *)
  | Transfer of transfer_param
  (* Gets the balance of multiple account/token pairs *)
  | Balance_of of balance_of_param
  (* Approves third party ("operator") to manage all of the caller's tokens. *)
  | Add_operator of address
  (* 
    Withdraws approval for the  third party ("operator") to manage all of 
    the caller's tokens. 
  *)
  | Remove_operator of address
  (* Queries the approval status of an operator for a given owner. *)
  | Is_operator of is_operator_param
```

#### LIGO generated Michelson

```
{ parameter
    (or (or (or (address %add_operator)
                (pair %balance_of
                   (list %balance_request (pair (address %owner) (nat %token_id)))
                   (contract %balance_view (list (pair (pair (address %owner) (nat %token_id)) nat)))))
            (or (pair %is_operator
                   (pair %is_operator_request (address %operator) (address %owner))
                   (contract %is_operator_view (pair (pair (address %operator) (address %owner)) bool)))
                (address %remove_operator)))
        (pair %transfer
           (pair (list %batch (pair (nat %amount) (nat %token_id))) (bytes %data))
           (pair (address %from_) (address %to_)))) ;
```

#### Safe Transfer Rules

Transfers amounts specified in the batch between two given addresses. Transfers
should happen atomically: if at least one specified transfer cannot be completed,
the whole transaction MUST fail.

Sender MUST be approved to manage the tokens being transferred out of the `from_`
account or be the same address as `from_` address (see "Approval" section of the
standard). Otherwise the transaction MUST fail.

The transaction MUST fail if any of the balance(s) of the holder for token(s) in
the batch is lower than the respective amount(s) sent. If holder does not hold any
tokens of type `token_id`, holder's balance is interpreted as zero.

`to_` address MUST be either a whitelisted account and/or a smart contract
implementing `multi_token_receiver` interface. If `to_` is not whitelisted and
does not implement `multi_token_receiver` interface, the transaction MUST fail.

If `to_` is a smart contract which implements `multi_token_receiver` interface,
the transaction MUST call entry point `On_multi_tokens_received` of that
contract and MUST return call `operation` among other operations it might create.
`data` argument MUST be passed unaltered to a receiver hook entry point.

The following table demonstrates the required actions depending on `from_` address
properties.

| `from_` is whitelisted | `from_` implements `multi_token_receiver` interface | Action |
| ------ | ----- | ----------|
| No  | No  | Transaction MUST fail |
| Yes | No  | Continue transfer |
| No  | Yes | Continue transfer, MUST call `On_multi_tokens_received` |
| Yes | Yes | Continue transfer, MUST call `On_multi_tokens_received` |

`On_multi_tokens_received` MAY be called multiple times from the transaction in
any combination and the following requirements MUST be met:

* The set of all calls to `On_multi_tokens_received` describes all balance changes
that occurred during the transaction in the order submitted.
* Receiver MUST be notified of each individual transfer only once.
* A contract MAY skip calling the `On_multi_tokens_received` hook function if the
transfer operation is transferring the token to itself.

When `On_multi_tokens_received` is invoked, the receiver can either accept tokens
by successfully finishing execution or reject tokens by failing. If at least one
receiver rejects tokens, the whole transaction fails.

This specification does not put any restrictions on what receiver can do when
`On_multi_tokens_received` is invoked. It can update its storage and/or initiate
calls to other contracts, including initiation of another transfer(s) by
`multi_token` contract.

#### Whitelisting accounts

In order to receive tokens, the address needs to be either whitelisted or
implement `multi_token_receiver` interface.  Entry points `Register_owner`/`Unregister_owner`
let an implicit account or a contract to add itself to the whitelist.
Those entry points do not accept any parameters and are using `SENDER` address.

Unregistering an address from the whitelist does not change any existing token
balances. It just prevents future transfers from this address.

The concrete implementation of multi asset contract MAY implement additional
entry points to allow contract administrator to manage whitelist on behalf of
token owners.

#### `Balance_of`

Get the balance of multiple account/token pairs. Accepts a list of `balance_request`s
and callback contract `balance_view` which accepts a list of pairs of `balance_request`
and balance.

#### Approval

The entry points `Add_operator`/`Remove_operator` allow an operator to manage
one’s entire set of tokens on behalf of the owner. To approve management of a
subset of token IDs, an interface such as
[ERC-1761 Scoped Approval Interface](https://eips.ethereum.org/EIPS/eip-1761)
is suggested. The counterpart `Is_operator` provides introspection into
any status set by ``Add_operator`/`Remove_operator`.

Only token owner can invoke `Add_operator`/`Remove_operator` entry points on
multi asset contract and manage its operators. Token owner contract MUST implement
`multi_token_receiver` interface or be whitelisted. If the owner does not implement
`multi_token_receiver` interface or not whitelisted, `Add_operator` SHOULD fail.

The concrete implementation of multi asset contract MAY implement custom entry points
which allow administrator of the contract to manage operators for token owners.

An owner SHOULD be assumed to always be able to operate on their own tokens
regardless of approval status, so SHOULD NOT have to call `Add_operator`
to approve themselves as an operator before they can operate on own tokens.

#### Minting/creating and burning/destroying rules

A mint/create operation is essentially a specialized transfer and MUST follow safe
transfer rules in regard of invoking `On_multi_tokens_received` and whitelisting
requirements for the address which receives minted tokens.

### `multi_token_receiver` entry points

```ocaml
type on_multi_tokens_received_param = {
  operator : address;     (* The address which initiated the transfer (i. e. sender) *)
  from_ : address option; (* Source address. None for minting operation *)
  batch : tx list;        (* Batch of tokens and their amounts which are transferred *)
  data : bytes;           (* Additional data with no specified format *)
}

(* multi_token_receiver entry points *)
type multi_token_receiver =
  (*
    Handle the receipt of multiple token types.
    A  multi-asset compliant smart contract MUST call this function on the token
    recipient contract from `Transfer`.
    MUST fail if it rejects the transfer(s).
  *)
  | On_multi_tokens_received of on_multi_tokens_received_param
```

#### `Multi_token_receiver` Rules

If an implementation specific API function is used to transfer token(s) to a contract,
`transfer` (as appropriate) rules MUST still be followed and the receiver MUST
implement the `multi_token_receiver` or be a whitelisted address.

Only non-standard transfer functions MAY allow tokens to be sent to a recipient
contract that does NOT implement the necessary `multi_token_receiver` hook functions
or whitelisted.

#### Token owner contract implementation guidelines

This specification focuses on token transfer logic only. Implementation of the
actual token receiver contract may differ depending on the particular business
use-case. However, potential locking of tokens on the receiver account should be
taken into consideration.

Token owner MUST implement `multi_token_receiver` interface to receive
tokens or be a whitelisted address.

By default, transfer **from_** a token owner to another contract can be
initiated only by the owner itself. If the owner contract implementation does
not allow to initiate such transfer and/or add operators (which also can be
performed only by the owner), tokens will remain locked on such contract forever.

There are a few possible ways to enable transferring tokens from a token owner
contract. The concrete implementation of the multi asset contract and/or owner
contract may use the following strategies or their combination:

  1. Add administrative entry points to the multi asset contract to allow burn
  tokens for any token owner.
  2. Add other entry points to the owner contract which can initiate transfer
  operation from the owner.
  3. Add other entry points to the owner contract which can add operators on
  behalf of the owner.
  4. Implement forwarding token receiver contract. `On_multi_tokens_received`
  implementation should initiate another transfer operation which will forward
  all received tokens to another owner. Another owner needs to address token
  locking issue as well.

## Difference between Ethereum ERC-1155 and the Tezos Multi-asset Contract

Since Tezos and Michelson differ from Ethereum/Solidity, the following modifications
are made:

1. Tezos multi-asset contract does not emit events (the feature is not supported
by Tezos).
2. Tezos multi-asset contract does not implement ERC-165 `supportsInterface` entry
point.
3. Ethereum specification says that if destination transfer address is not a smart
contract (Externally Owned Account),then safety check is not performed. Otherwise,
if destination contract does not implement `multi_token_receiver` interface, the
transaction should fail. Tezos specification requires that target MUST be a
whitelisted address and/or be a contract which MUST implement `multi_token_receiver`
interface. Safety check MUSTbe performed for ALL targets either by checking against
the white list or by invoking `multi_token_receiver`.
4. Ordering requirements for batch transfers is relaxed. Since Tezos smart contracts
are referentially transparent and do not allow calls to other contracts from the
executing contract, batch order MUST be preserved only for invocation
of `On_multi_tokens_received` entry point of `multi_token_receiver` interface.
5. Tezos multi-asset contract implements only batch entry points. Original ERC-1155
has both single and batch entry points. The motivation was gas use optimization:
single entry points *may* be implemented more efficiently. With Tezos multi-asset
contract more favor was given to simplicity.
6. Optional `ERC1155Metadata_URI` interface is not part of Tezos multi-asset contract
specification.
7. Tezos multi-asset contract use interfaces/entry point names (see next
section) which are different from Ethereum ECR-1155. We believe that the new names
better convey meaning of the operations.
8. Tezos does not have equivalent of Ethereum view function (although there is a
[proposal](https://forum.tezosagora.org/t/adding-read-only-calls/1227) to add
one to Tezos/Michelson). `Balance_of` entry point is specified using continuation
style view pattern, but can be converted into a view in future.
9. ERC-1155 `safeBatchTransferFrom` entry point receives two separate arrays of
token ids and transfer amounts. Both caller and implementor of the contract are
responsible to match values from those arrays and enforce their consistency. Tezos
multi-asset contract uses single array of `tx` records which have all the
attributes specifying single transfer.

### Interfaces/entry point names

Interface names

|  Ethereum ERC-1155 | Tezos multi-asset |
| :--- | :--- |
| `ERC1155` | `multi_token` |
| `ERC1155TokenReceiver` | `multi_token_receiver` |

`multi_asset` entry points

|  Ethereum ERC-1155 | Tezos multi-asset |
| :--- | :--- |
| `safeTransferFrom` | N/A |
| `safeBatchTransferFrom` | `Transfer` |
| `balanceOf` | N/A |
| `balanceOfBatch` | `Balance_of` |
| `setApprovalForAll` | `Add_operator` \ `Remove_operator` |
| `isApprovedForAll` | `Is_operator` |

`multi_token_receiver` entry points

|  Ethereum ERC-1155 | Tezos multi-asset |
| :--- | :--- |
| `onERC1155Received` | N/A |
| `onERC1155BatchReceived` | `On_multi_tokens_received` |
