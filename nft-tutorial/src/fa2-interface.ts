import * as kleur from 'kleur';
import { BigNumber } from 'bignumber.js';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';

type address = string;
type nat = BigNumber;

export interface Fa2TransferDestination {
  to_: address;
  token_id: nat;
  amount: nat;
}

export interface Fa2Transfer {
  from_: address;
  txs: Fa2TransferDestination[];
}

export interface BalanceOfRequest {
  owner: address;
  token_id: nat;
}

export interface BalanceOfResponse {
  balance: nat;
  request: BalanceOfRequest;
}

export interface TokenMetadata {
  token_id: nat;
  symbol: string;
  name: string;
  decimals: nat;
  extras: MichelsonMap<string, string>;
}

export async function transfer(
  fa2: address,
  operator: TezosToolkit,
  txs: Fa2Transfer[]
): Promise<void> {
  console.log(kleur.yellow('transferring tokens...'));
  const nftWithOperator = await operator.contract.at(fa2);

  const op = await nftWithOperator.methods.transfer(txs).send();

  const hash = await op.confirmation();
  console.log(kleur.green('tokens transferred'));
}

export async function addOperator(
  fa2: address,
  owner: TezosToolkit,
  operator: address
): Promise<void> {
  console.log(kleur.yellow('adding operator...'));
  const fa2WithOwner = await owner.contract.at(fa2);
  const ownerAddress = await owner.signer.publicKeyHash();
  const op = await fa2WithOwner.methods
    .update_operators([
      {
        add_operator: {
          owner: ownerAddress,
          operator
        }
      }
    ])
    .send();
  await op.confirmation();
  console.log(kleur.green('added operator'));
}
