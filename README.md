# FA2 Contracts Implementation

This repository contains multiple sub-projects implementing different flavors of
the FA2 token standard.

## Shared LIGO code

[shared](shared) directory contains common code shared by all sub-project.
The FA2-related LIGO artifacts are:

- [shared/fa2](shared/fa2) - FA2 interface and standard errors definition.
- [shared/fa2/lib](shared/fa2/lib) - Helpers, various bits and pieces
  used by the FA2 implementation.
  - [shared/fa2/lib/fa2_convertors.mligo](shared/fa2/lib/fa2_convertors.mligo) -
    functions to convert the FA2 entry points input parameters to and from the Michelson
    right-comb representation, required by the FA2 interface, and LIGO internal types.
  - [shared/fa2/lib/fa2_operator_lib.mligo](shared/fa2/lib/fa2_operator_lib.mligo) -
    helper functions to manage and validate FA2 operators.
  - [shared/fa2/lib/fa2_owner_hook_lib.mligo](shared/fa2/lib/fa2_owner_hook_lib.mligo) -
    helper functions to support sender/receiver hooks.
- [shared/fa2_modules](shared/fa2_modules) - modules implementing additional contract
  functionality to be mixed into the final FA2 contract.
  - [shared/fa2_modules/simple_admin.mligo](shared/fa2_modules/simple_admin.mligo) -
    implementation of the admin entry points that let to pause/unpause the contract
    and change the admin.
- [shared/fa2_clients](shared/fa2_clients) - FA2 client contracts used for testing.

## Sub-Projects Structure

The sub-projects symlink shared code into their respective directories. Each
sub-project has `ligo` directory that contains all LIGO-related files:

- symlinked shared common code.
- `src` directory with the LIGO implementation of the particular FA2 contract(s).
- `out` directory with the contracts compiled to Michelson.

The design of each FA2 contract follows the same pattern and consists of the following
source files:

- `fa2_xxx_token.mligo` - implementation of the FA2 entry points and FA2 core logic.
- `token_manager.mligo` - implementation of mint, burn, create token(s) entry points.
- `fa2_xxx_asset.mligo` - assembly of different modules into a complete FA2 contract.
  The assembly includes FA2 entry points and core logic (`fa2_xxx_token.mligo`),
  mint/burn entry points (`token_manager.mligo`)
  and the administrator entry points
  ([shared/fa2_modules/simple_admin.mligo](shared/fa2_modules/simple_admin.mligo)).

## Implemented FA2 Contracts

### [single_asset](single_asset)

[fa2_single_asset.mligo](single_asset/ligo/src/fa2_single_asset.mligo) implementation
of the FA2 contract that supports single fungible tokens (a.k.a ERC-20).

[fa2_single_asset_with_hooks.mligo](single_asset/ligo/src/fa2_single_asset_with_hooks.mligo)
implementation of the FA2 contract that supports single fungible tokens (a.k.a ERC-20)
and sender/receiver hooks.

### [multi_asset](multi_asset)

[fa2_multi_asset.mligo](multi_asset/ligo/src/fa2_multi_asset.mligo) implementation
of the FA2 contract that supports multiple fungible tokens (a.k.a. ERC-1155).

### [fa2_hooks](fa2_hooks)

[fa2_multi_asset.mligo](fa2_hooks/ligo/src/fa2_multi_asset.mligo) implementation
of the FA2 contract that supports multiple fungible tokens (a.k.a. ERC-1155) and
sender/receiver hooks.

### [nft_asset](nft_asset)

[fa2_nft_asset.mligo](nft_asset/ligo/src/fa2_nft_asset.mligo) implementation
of the NFT FA2 contract (a.k.a. ERC-721). The contract supports multiple "families"
of NFT tokens that share the same token metadata.

### [collectibles](collectibles)

[fa2_fixed_collection_asset.mligo](collectibles/ligo/src/fa2_fixed_collection_asset.mligo)
implementation of the fixed collection of NFT tokens (a.k.a. ERC-721). The FA2
contract is originated with the predefined set of NFT tokens. Tokens cannot be
minted or burned.

### [nft-tutorial](nft-tutorial)

[fa2_fixed_collection_token.mligo](nft-tutorial/ligo/src/fa2_fixed_collection_token.mligo)
simplified implementation of the he fixed collection of NFT tokens (does not include
administrator).
The project also includes CLI tool to mint, transfer inspect NFTs.
