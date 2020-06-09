# Tezos FA2 Multi-Asset Smart Contract Implementation

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

Administrative operations to create new token types, mint and burn tokens are not
part of the multi-asset contract specification. Their implementation may differ
depending on a particular business use-case.
