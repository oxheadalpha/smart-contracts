# Tezos multi-asset smart contract specification

## Abstract

This document describes the implementation of the Tezos multi-asset contract
conforming FA2 financial assets standard.
Token standards like ERC-20 and ERC-721 require a separate contract to be deployed
for each token type or collection. The multi-asset contract manages multiple token
types. A new token can be created and configured without redeploying the contract.
Both fungible and non-fungible tokens can be stored in the same smart contract.

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

Transfer permission policy particular implementation is to be implemented as a
separate pluggable contract using transfer hook design pattern as recommended by
the FA2 standard.

Multi-asset contract supports an atomic batch transfer of multiple tokens.
Either all the transfers in a batch are successful or all of the transfers
are discarded.

Administrative operations to create new token types, mint and burn tokens are not
part of the multi-asset contract specification. Their implementation may differ
depending on a particular business use-case.

## Safe Transfer Rules

Transfers specified in the batch MUST happen atomically: if at least one specified
transfers cannot be completed, the whole transaction MUST fail.

The transaction MUST fail if any of the balance(s) of the holder for token(s) in
the batch is lower than the respective amount(s) sent. If the holder does not hold
any tokens of type `token_id`, holder's balance is interpreted as zero.

If transfer hook is not set, the transaction MUST fail. The transaction must invoke
transfer hook which implements some permission policy. If the transaction is not
permitted, transfer hook MUST fail and the whole transaction MUST fail as well.

There is no restrictions on what transfer hook can do when it is invoked. It can
update its storage and/or initiate calls to other contracts, including initiation
of another transfer(s) by `multi_token` contract.

### `Set_transfer_hook`

Transfer hook is not a part of FA2 standard specification, but a recommended design
pattern to combine core transfer logic with a permission policy implemented as a
separate smart contract. This implementation provides additional entry point
`Set_transfer_hook` used to set transfer hook before any token transfer becomes
possible.

```ocaml
type hook_transfer = {
  from_ : address option;
  to_ : address option;
  token_id : token_id;
  amount : nat;
}

type hook_param = {
  batch : hook_transfer list;
  operator : address;
}

type set_hook_param = {
  hook : address;
  config : permission_policy_config list;
}

Set_transfer_hook of set_hook_param
```

## Minting/creating and burning/destroying rules

Mint/create and/or burn/destroy operations are essentially specialized transfers
and MUST follow safe transfer rules in regard of invoking the transfer hook.

## Permission policy implementation guidelines

The core implementation focuses on token transfer logic only. Implementation of
the actual token contract and permission policy contract may differ depending on
the particular business use-case. However, potential locking of tokens on the
receiver account should be taken into consideration.

If particular permission policy does not allow token owner to initiate token
transfer and/or add operators (who can transfer tokens on behalf of the owner),
tokens will remain locked on such account forever. There is also a possibility
to transfer tokens to an address which is not aware of the token contract and thus
cannot initiate a transfer.

There are a few possible ways to mitigate the risk of token locking. The concrete
implementation of the multi asset contract, permission policy contract and/or owner
contract may use the following strategies or their combination:

  1. Add administrative entry points to the multi asset contract to allow burn
  tokens for any token owner.
  2. Add other entry points to the owner contract which can initiate transfer
  operation from the owner.
  3. Add other entry points to the owner contract which can add permissions to
  operators on behalf of the owner.
  4. Implement receiver hook for the token owner contract and permission policy
  which must invoke such hook. Receiver hook may reject a transfer or forward tokens
  to other contract.
  5. Implement white list permission policy which would require all token owners
  to be whitelisted before they can receive any tokens.
