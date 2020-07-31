import * as path from 'path';
import { $log } from '@tsed/logger';

import { TezosToolkit } from '@taquito/taquito';

import {
  compileAndLoadContract,
  originateContract,
  defaultEnv,
  LigoEnv
} from './ligo';
import { address, Contract } from './type-aliases';
import { BalanceOfRequest, BalanceOfResponse } from './fa2-interface';

export type InspectorStorage = BalanceOfResponse[] | {};

export async function originateInspector(tz: TezosToolkit): Promise<Contract> {
  const inspectorSrcDir = path.join(defaultEnv.cwd, 'fa2_clients');
  const env = new LigoEnv(defaultEnv.cwd, inspectorSrcDir, defaultEnv.outDir);

  const code = await compileAndLoadContract(
    env,
    'inspector.mligo',
    'main',
    'inspector.tz'
  );
  const storage = `(Left Unit)`;
  return originateContract(tz, code, storage, 'inspector');
}

export async function queryBalances(
  inspector: Contract,
  fa2: address,
  requests: BalanceOfRequest[]
): Promise<BalanceOfResponse[]> {
  $log.info('checking token balance');

  const op = await inspector.methods.query(fa2, requests).send();
  const hash = await op.confirmation(3);
  $log.info(`consumed gas: ${op.consumedGas}`);

  const storage = await inspector.storage<InspectorStorage>();
  if (Array.isArray(storage)) return storage;
  else return Promise.reject('Invalid inspector storage state Empty.');
}
