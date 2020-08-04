# Tutorial Scripts (Draft)

## Prerequisites

- Docker must be installed

- LIGO must be installed.

- Node.js and Npm must be installed.

- Flextesa sandbox docker image will be installed when sandbox is used first time.

## Initial Setup

1. To install the tutorial run
   `npm install https://github.com/tqtezos/smart-contracts/tree/master/nft-tutorial`
   command.

2. Select Tezos network. Either testnet `npx set-network testnet` or a local sandbox
   (Flextesa) `npx set-network sandbox`. You can always inspect selected net by running
   command `npx show-network`.

3. Each network comes with two preconfigured accounts `Bob` and `Alice`. The user
   can manage the accounts by directly editing `tutorial.config.json` or using
   the following commands:

   - `npx show-account <alias>`, `npx show-account --all`

   - `npx add-account <alias> <pk>`
   - `npx remove-account <alias>`

4. You need to start a sandbox before you can originate the contracts:
   `npx start`

## Originate NFT Collection(s)

To originate a new NFT collection you need to provide tokens metadata.
`npx mint-nfts <owner_alias> <token_meta_list>`.

Example:

```sh
npx mint-nfts Bob [
  {id : 0, symbol : 'T1', description : 'My Token', extras : {"tokenUrl" : "http://..."} },
  {id : 2, symbol : 'T2', description : 'My Token', extras : {"tokenUrl" : "http://..."} }
  ]
```

output:
`nft contract created: KT1SFWBwUSwmk2xd148Ws6gWUeASwK4UpFfP`

## Inspecting the NFT Contract

1. Check token ownership: `npx has-token <nft> <owner> <token_id>`

Example:
`npx has-token KT1SFWBwUSwmk2xd148Ws6gWUeASwK4UpFfP Bob 0`

output:
`True`

2. Get token metadata: `npx show-token-meta <nft> <token_id>`

Example:
`npx show-token-meta KT1SFWBwUSwmk2xd148Ws6gWUeASwK4UpFfP 0`

output:

```typescript
{
  id : 0,
  symbol : 'T1',
  description : 'My Token',
  extras : {
    "tokenUrl" : "http://..."
  }
}
```

## Transferring Tokens

1. Bob can transfer his own token to Alice:
   `npx transfer <nft> <from_alias> <to_alias> <token_list>`

Example:
`npx transfer KT1SFWBwUSwmk2xd148Ws6gWUeASwK4UpFfP Bob Alice [0]`

2. It is also possible to transfer tokens on behalf of the owner.

- Alice adds Bob as an operator: `npx update-operator <nft> add={owner, operator}`

Example: `npx update-operator KT1SFWBwUSwmk2xd148Ws6gWUeASwK4UpFfP Alice Bob`

- Now Bob can transfer Alice's token
  `npx --operator=Bob transfer KT1SFWBwUSwmk2xd148Ws6gWUeASwK4UpFfP Alice Bob [0]`
