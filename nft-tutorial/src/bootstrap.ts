import * as child from 'child_process';
import * as kleur from 'kleur';
import { getActiveNetworkCfg, loadUserConfig } from './config-util';
import { Tezos } from '@taquito/taquito';

export async function start(): Promise<void> {
  const config = loadUserConfig();
  const { network, configKey } = getActiveNetworkCfg(config);
  if (network === 'sandbox') {
    //start and wait
    await new Promise<void>((resolve, reject) =>
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
    Tezos.rpc.getBlockHeader({ block: '1' });
    console.log(kleur.green('sandbox started'));
  }
}

export async function kill(): Promise<void> {
  const config = loadUserConfig();
  const { network, configKey } = getActiveNetworkCfg(config);
  if (network === 'sandbox') {
    //start and wait
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
}
