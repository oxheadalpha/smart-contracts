# Tutorial Scripts (Draft)

## Prerequisites

- Docker must be installed

- LIGO must be installed.

- Node.js and npm must be installed.

- Flextesa sandbox docker image will be installed when sandbox is used first time.

## Initial Setup

1. To install the tutorial run
   `npm install -g https://github.com/tqtezos/smart-contracts/tree/master/nft-tutorial`
   command.

2. Select Tezos network. Either testnet `tznft set-network testnet` or a local sandbox
   (Flextesa) `tznft set-network sandbox`. You can always inspect selected net by running
   command `tznft show-network`.

3. Each network comes with two preconfigured accounts `Bob` and `Alice`. The user
   can manage the accounts by directly editing `tznft.json` or using
   the following commands:

   - `tznft show-alias <alias>`, `npx show-alias --all`

   - `tznft add-alias <alias> <pk>`
   - `tznft remove-alias <alias>`

4. You need to start a sandbox before you can originate the contracts:
   `tznft start`

## Originate NFT Collection(s)

To originate a new NFT collection you need to provide tokens metadata.
`tznft mint <owner_alias> <token_meta_list>`.

Example:

`tznft mint bob --tokens '0, T1, My Token' '1, T2, My Token'`

output:
`nft contract created: KT1SFWBwUSwmk2xd148Ws6gWUeASwK4UpFfP`

## Inspecting the NFT Contract

1. Check token ownership:
   `tznft show-balance --nft <nft> --owner <owner> --tokens <list_of_token_ids>`

Example:
`tznft --show-balance --nft KT1SFWBwUSwmk2xd148Ws6gWUeASwK4UpFfP --owner bob --tokens 0`

output:
`owner: tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU token: 0 balance: 1`

2. Get token metadata: `tznft show-meta --nft <nft> --tokens <list_of_token_ids>`

Example:
`tznft show-meta --nft KT1SFWBwUSwmk2xd148Ws6gWUeASwK4UpFfP --tokens 0`

output: `token_id: 0 symbol: TZ0 name: token zero extras: { }`

## Transferring Tokens

1. Bob can transfer his own token to Alice:
   `tznft transfer --nft <nft> --operator <operator> --batch <batch_list>`

Example:
`tznft transfer --nft KT1SFWBwUSwmk2xd148Ws6gWUeASwK4UpFfP --operator bob --batch 'bob, alice, 0'`

2. It is also possible to transfer tokens on behalf of the owner.

- Alice adds Bob as an operator:
  `tznft update-operator <owner> --nft <nft> --add [add_list] --remove [remove_list]`

Example:
`tznft update-ops --nft KT1SFWBwUSwmk2xd148Ws6gWUeASwK4UpFfP alice -a bob`

- Now Bob can transfer Alice's token
  `tznft transfer --nft KT1SFWBwUSwmk2xd148Ws6gWUeASwK4UpFfP --operator bob --batch 'alice, bob, 0`

## Modifying NFT Contract Code

TBD

Customizing existing NFT contract
