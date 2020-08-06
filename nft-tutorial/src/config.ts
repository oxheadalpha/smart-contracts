import Conf from 'conf';
// import {Schema} from 'conf';
import * as path from 'path';
import * as fs from 'fs';
import * as kleur from 'kleur';

const userConfigFile = path.join(process.cwd(), 'tznft');
const userConfigFileWithExt = userConfigFile + '.json';

function loadUserConfig(): Conf<Record<string, string>> {
  if (fs.existsSync(userConfigFileWithExt))
    return new Conf({
      configName: 'tznft',
      cwd: process.cwd(),
      serialize: v => JSON.stringify(v, null, 2)
    });
  else {
    console.log(kleur.red('no tznft.json config file found'));
    console.log(
      `Try to run ${kleur.green(
        'tznft config init'
      )} command to create default config`
    );
    throw new Error('no tznft.json config file found');
  }
}

export function initUserConfig(): void {
  if (fs.existsSync(userConfigFileWithExt)) {
    console.log(kleur.yellow('tznft.json config file already exists'));
  } else {
    fs.copyFileSync(
      path.join(__dirname, '../tznft.json'),
      userConfigFileWithExt
    );
    console.log(`${kleur.green('tznft.json')} config file created`);
  }
}

export function showActiveNetwork(): void {
  const config = loadUserConfig();
  const network = config.get('activeNetwork', 'no network selected');
  console.log(`active network: ${kleur.green(network)}`);
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
  const c = JSON.stringify(config.store, null, 2);
  console.info(c);
}
