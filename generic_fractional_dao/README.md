# Generic Fractional Ownership DAO

Existing [fractional ownership DAO](../fractional/README.md) controls FA2 token
transfer operation using fractional ownership voting. However, token management
may involve other operations with the token (like putting it for sale on some
marketplace or auction contract). The set of operations, that can be performed
with the NFT and require fractional ownership control, is not predefined and can
be extended in the future.

The proposed generic DAO uses fractional voting to control any generic operation
represented by a lambda function. Such lambda can transfer tokens, buy/sell tokens
on market place or auction or perform any other generic operation. Strictly speaking,
generic fractional ownership DAO is not explicitly tied to any NFTs. Fractional
owners can vote on any lambda representing the operation; if they try to transfer
some token which is not owned by the DAO, such operation will fail, when the
transfer is validated by FA2 contract.

## Entities

**NFT token** - any generic implementation of an FA2 NFT token that can be
transferred between any addresses.

**Ownership DAO** - a contract that can own any generic NFT token and control
any operation with owned NFTs using fractional ownership logic.

**Ownership token** - a fungible FA2 token embedded within the ownership DAO.
Token balances are allocated to fractional owners. Such allocations can be changed
by transferring ownership tokens.

**Fractional owner** - an address which owns a fraction of all NFTs managed by
the DAO. Fraction of ownership is represented by the balance of the ownership token
allocated to the fractional owner. Fractional owner can vote on any operation lambda
that manipulates managed NFTs.

**Operation lambda** - any operation that manipulates owned NFT tokens or DAO itself.
Fractional owners can vote on execution of the operation lambda.

## DAO operations

**Transfer ownership tokens** - Since the ownership token managed by the DAO is
a regular FA2 fungible token, fractional owners can transfer it using standard
FA2 transfer.

**Vote on operation lambda** - any fractional owner can submit a vote consisting
of a lambda (`unit -> operation list`) and a nonce.
The vote weight is proportional to a balance of the ownership token allocated
to a fractional owner. Once predefined voting threshold is met, DAO executes the
lambda and returns produced operation.

## DAO Entry Points

### Standard FA2 entry points for ownership token

`%transfer`

`balance_of`

`update_operators`

### `%vote`

```ocaml
%vote {
  lambda: unit -> operation list;
  nonce: nat;
}
```

## Miscellaneous

Providing lambda "templates" or some high-level client API to create and sign
lambda functions for generic operations should be considered.

1. NFT `transfer` and `update_operators`.
2. Interaction with market place and auction contracts.
3. DAO administration.

## What's Next

- Create tests for the fractional DAO contract
- Create helper Typescript API to generate DAO lambdas for the most common operations

  - Transfer governed token(s)
  - Update operators for governed token(s)
  - Change DAO voting threshold
  - Change DAO voting period

- Migrate DAO contract to minter-sdk
