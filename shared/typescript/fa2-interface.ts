import { $log } from '@tsed/logger';
import { TezosToolkit } from '@taquito/taquito';
import { Contract, address, nat } from './type-aliases';

export interface Fa2TransferDestination {
  to_: address;
  token_id: nat;
  amount: nat;
}

export interface Fa2Transfer {
  from_?: address;
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

export async function transfer(
  fa2: address,
  operator: TezosToolkit,
  txs: Fa2Transfer[]
): Promise<void> {
  $log.info('transferring');
  const nftWithOperator = await operator.contract.at(fa2);

  const op = await nftWithOperator.methods.transfer(txs).send();

  const hash = await op.confirmation(3);
  $log.info(`consumed gas: ${op.consumedGas}`);
}

export type OperatorParam = {
  owner: address;
  operator: address;
  token_id: nat;
};
export type AddOperator = { add_operator: OperatorParam };
export type RemoveOperator = { remove_operator: OperatorParam };
export type UpdateOperator = AddOperator | RemoveOperator;

export const isAddOperator = (op: UpdateOperator): op is AddOperator =>
  op.hasOwnProperty('add_operator');

export const isRemoveOperator = (op: UpdateOperator): op is RemoveOperator =>
  op.hasOwnProperty('remove_operator');

export async function updateOperators(
  fa2: address,
  owner: TezosToolkit,
  operators: UpdateOperator[]
): Promise<void> {
  $log.info('adding operator');
  const fa2WithOwner = await owner.contract.at(fa2);
  const ownerAddress = await owner.signer.publicKeyHash();
  const op = await fa2WithOwner.methods.update_operators(operators).send();
  await op.confirmation(3);
  $log.info(`consumed gas: ${op.consumedGas}`);
}
