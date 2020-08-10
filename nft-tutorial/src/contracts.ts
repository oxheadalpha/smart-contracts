import Conf from 'conf';
import * as kleur from 'kleur';
import * as fs from 'fs';
import * as path from 'path';
import { BigNumber } from 'bignumber.js';
import { TezosToolkit } from '@taquito/taquito';
import { InMemorySigner } from '@taquito/signer';
import { getActiveNetworkCfg } from './config-util';

export interface Fa2TransferDestination {
  to_?: string;
  token_id: BigNumber;
  amount: BigNumber;
}

export interface Fa2Transfer {
  from_?: string;
  txs: Fa2TransferDestination[];
}

export interface BalanceOfRequest {
  owner: string;
  token_id: BigNumber;
}

export interface BalanceOfResponse {
  balance: BigNumber;
  request: BalanceOfRequest;
}

type InspectorStorage = BalanceOfResponse[] | {};

export function createToolkit(
  signer: InMemorySigner,
  config: Conf<Record<string, string>>
): TezosToolkit {
  const { network, configKey } = getActiveNetworkCfg(config);
  const providerUrl = config.get(`${configKey}.providerUrl`);
  if (!providerUrl) {
    const msg = `network provider for ${kleur.yellow(
      network
    )} URL is not configured`;
    console.log(kleur.red(msg));
    throw new Error(msg);
  }

  const toolkit = new TezosToolkit();
  toolkit.setProvider({
    signer,
    rpc: providerUrl,
    config: { confirmationPollingIntervalSecond: 5 }
  });
  return toolkit;
}

export async function originateInspector(tezos: TezosToolkit): Promise<string> {
  const code = await loadFile(path.join(__dirname, '../ligo/out/inspector.tz'));
  const storage = `(Left Unit)`;
  return originateContract(tezos, code, storage, 'inspector');
}

async function loadFile(filePath: string): Promise<string> {
  return new Promise<string>((resolve, reject) =>
    fs.readFile(filePath, (err, buff) =>
      err ? reject(err) : resolve(buff.toString())
    )
  );
}

async function originateContract(
  tz: TezosToolkit,
  code: string,
  storage: any,
  name: string
): Promise<string> {
  try {
    const originationOp = await tz.contract.originate({
      code,
      init: storage
    });

    const contract = await originationOp.contract();
    return contract.address;
  } catch (error) {
    const jsonError = JSON.stringify(error, null, 2);
    console.log(kleur.red(`${name} origination error ${jsonError}`));
    return Promise.reject(jsonError);
  }
}
