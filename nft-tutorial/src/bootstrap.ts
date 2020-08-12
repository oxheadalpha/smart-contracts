import * as child from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as kleur from 'kleur';
import Conf from 'conf';
import { Tezos } from '@taquito/taquito';
import {
  getActiveNetworkCfg,
  loadUserConfig,
  getInspectorKey
} from './config-util';
import { createToolkit, originateInspector } from './contracts';

export async function start(bootstrap: string): Promise<void> {
  try {
    const config = loadUserConfig();
    const { network, configKey } = getActiveNetworkCfg(config);
    if (network === 'sandbox') await startSandbox();

    await originateBalanceInspector(config, configKey, bootstrap);
  } catch (err) {
    console.log(kleur.red('failed to start. ' + JSON.stringify(err)));
    return;
  }
}

export async function kill(): Promise<void> {
  const config = loadUserConfig();
  const { network, configKey } = getActiveNetworkCfg(config);
  if (network === 'sandbox') await killSandbox();
}

async function startSandbox(): Promise<void> {
  await new Promise<void>((resolve, reject) =>
    //start and wait
    child.exec(
      'sh ../flextesa/start-sandbox.sh',
      { cwd: __dirname },
      (err, stdout, errout) => {
        if (err) {
          console.log(kleur.red('failed to start sandbox'));
          console.log(kleur.red().dim(errout));
          reject();
        } else {
          console.log(kleur.yellow().dim(stdout));
          resolve();
        }
      }
    )
  );
  console.log(kleur.yellow('starting sandbox...'));
  await Tezos.rpc.getBlockHeader({ block: '1' });
  console.log(kleur.green('sandbox started'));
}

async function killSandbox(): Promise<void> {
  await new Promise<void>((resolve, reject) =>
    child.exec(
      'sh ../flextesa/kill-sandbox.sh',
      { cwd: __dirname },
      (err, stdout, errout) => {
        if (err) {
          console.log(kleur.red('failed to stop sandbox'));
          console.log(kleur.red().dim(errout));
          reject();
        } else {
          console.log(kleur.yellow().dim(stdout));
          resolve();
        }
      }
    )
  );
  console.log(kleur.yellow('killed sandbox.'));
}

async function originateBalanceInspector(
  config: Conf<Record<string, string>>,
  networkKey: string,
  orig_alias: string
): Promise<void> {
  console.log(kleur.yellow(`originating balance inspector contract...`));

  const tezos = await createToolkit(orig_alias, config);
  const inspectorAddress = await originateInspector(tezos);

  config.set(getInspectorKey(config), inspectorAddress);

  console.log(
    kleur.yellow(
      `originated balance inspector ${kleur.green(inspectorAddress)}`
    )
  );
}
