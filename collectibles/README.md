# Collectibles Promotion Auction

## Abstract

Implementation of the FA2 NFT collectibles promotion auction. The promoter, who
owns collectible NFT tokens can create a promotion auction contract with the set
price per collectible token. Auction participant transfer money tokens to the auction
amd receive collectible tokens in exchange.

Since the `permissions_descriptor` for FA2 contracts is represented on-chain as
a contract storage field, it is not duplicated in the contract metadata as
required by TZIP-12/TZIP-16.

## Description

A promoter who owns some collectible NFT tokens can create an instance of promotion.
The promotion definition contains FA2 address of the NFT collection, FA2 fungible
"money" token used to pay for collectibles and a price per collectible token.

The promotion starts when the promoter transfers one or more collectible NFT tokens
to the promotion contract.

Once promotion is in progress, other participants can transfer money tokens to the
promotion contract. The promotion allocates promoted tokens to the participants and
keeps remaining money balances.

The promotion stops if all promotion tokens are allocated or if the promoter explicitly
stopped it.

At any time when the promotion is in progress or stopped, any participant may request
refund (transfer back) the remaining unspent money balance and/or to disburse
already allocated collectible tokens.

If the promotion has been stopped and not all collectible tokens are allocated, the
promoter should request to disburse remaining collectibles.
