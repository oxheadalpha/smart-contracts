# Tezos multi-asset smart contract specification

## Abstract

This document describes implementation of the Tezos multi-asset contract conforming
FA2 financial assets standard.
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

Transfer permission policy articular implementation is to be implemented as a
separate plugable contract using transfer hook design pattern as recommended by
FA2 standard.

Multi-asset contract supports atomic batch transfer of multiple tokens.
Either all transfers in a batch are successful or all of the transfers
are discarded.

Administrative operations to create new token types, mint and burn tokens are not
part of the multi-asset contract specification. Their implementation may differ
depending on the particular business use-case. This specification focuses on token
transfer logic only.

## Safe Transfer Rules

TTransfers specified in the batch MUST happen atomically: if at least one specified
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

A mint/create and/or burn/destroy operations are essentially specialized transfers
and MUST follow safe transfer rules in regard of invoking transfer hook.

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

## Difference between Ethereum ERC-1155 and the Tezos Multi-asset Contract

Since Tezos and Michelson differ from Ethereum/Solidity, the following modifications
are made:

1. Tezos multi-asset contract does not emit events (the feature is not supported
by Tezos).
2. Tezos multi-asset contract does not implement ERC-165 `supportsInterface` entry
point.
3. Tezos multi-asset contract implementation does not force any particular permission
policy, such as Ethereum token receiver interface. Permission policy must be implemented
as a separate contract which is invoked as transfer hook.
4. Ordering requirements for batch transfers is relaxed. Since Tezos smart contracts
are referentially transparent and do not allow calls to other contracts from the
executing contract.
5. Tezos multi-asset contract implements only batch entry points. Original ERC-1155
has both single and batch entry points. The motivation was gas use optimization:
single entry points *may* be implemented more efficiently. With Tezos multi-asset
contract more favor was given to simplicity.
6. Optional `ERC1155Metadata_URI` interface is not part of Tezos multi-asset contract
specification.
7. Tezos multi-asset contract use interfaces/entry point names which are different
from Ethereum ECR-1155. We believe that the new names better convey the meaning
of the operations.
8. Tezos does not have equivalent of Ethereum view function (although there is a
[proposal](https://forum.tezosagora.org/t/adding-read-only-calls/1227) to add
one to Tezos/Michelson). `Balance_of` entry point is specified using continuation
style view pattern, but can be converted into a view in future.
9. ERC-1155 `safeBatchTransferFrom` entry point receives two separate arrays of
token ids and transfer amounts. Both caller and implementor of the contract are
responsible to match values from those arrays and enforce their consistency. Tezos
multi-asset contract uses single array of `transfer` records which have all the
attributes specifying a single transfer.
