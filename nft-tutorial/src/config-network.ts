import * as kleur from 'kleur';
import { loadUserConfig } from './config-util';

export function showActiveNetwork(all: boolean): void {
  const config = loadUserConfig();
  const network = config.get('activeNetwork');
  if (!all)
    console.log(
      `active network: ${
        network ? kleur.green(network) : kleur.red('not selected')
      }`
    );
  else {
    const allNetworks = Object.getOwnPropertyNames(
      config.all.availableNetworks
    );
    for (let n of allNetworks) {
      if (n === network) console.log(kleur.bold().green(`* ${n}`));
      else console.log(kleur.yellow(`  ${n}`));
    }
    if (!network) console.log(`active network: ${kleur.red('not selected')}`);
  }
}

export function setNetwork(network: string): void {
  const config = loadUserConfig();
  if (!config.has(`availableNetworks.${network}`))
    console.log(
      kleur.red(
        `network ${kleur.yellow(network)} is not available in configuration`
      )
    );
  else {
    config.set('activeNetwork', network);
    console.log(`network ${kleur.green(network)} is selected`);
  }
}

export function showConfig(): void {
  const config = loadUserConfig();
  const c = JSON.stringify(config.all, null, 2);
  console.info(c);
}
