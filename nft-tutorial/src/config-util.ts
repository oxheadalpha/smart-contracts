// import Conf from 'conf';
import Configstore from 'configstore';
import * as path from 'path';
import * as fs from 'fs';
import * as kleur from 'kleur';
const packageJson = require('../package.json');

const userConfigFile = path.join(process.cwd(), 'tznft');
export const userConfigFileWithExt = userConfigFile + '.json';

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

export function loadUserConfig(): Configstore {
  if (fs.existsSync(userConfigFileWithExt)) {
    return new Configstore(
      packageJson.name,
      {},
      { configPath: userConfigFileWithExt }
    );
  } else {
    const msg = 'no tznft.json config file found';
    console.log(kleur.red(msg));
    suggestCommand('config-int');
    throw new Error(msg);
  }
}

interface ActiveNetworkCfg {
  network: string;
  configKey: string;
}

export function activeNetworkKey(config: Configstore): string {
  const network = config.get('activeNetwork');
  if (typeof network === 'string') {
    return `availableNetworks.${network}`;
  } else {
    const msg = 'no active network selected';
    console.log(kleur.red(msg));
    suggestCommand('set-network');
    throw new Error(msg);
  }
}

export const allAliasesKey = (config: Configstore) =>
  `${activeNetworkKey(config)}.aliases`;

export const aliasKey = (alias: string, config: Configstore) =>
  `${allAliasesKey(config)}.${alias}`;

export const inspectorKey = (config: Configstore) =>
  `${activeNetworkKey(config)}.inspector`;

export async function loadFile(filePath: string): Promise<string> {
  return new Promise<string>((resolve, reject) => {
    if (!fs.existsSync(filePath)) reject(`file ${filePath} does not exist`);
    else
      fs.readFile(filePath, (err, buff) =>
        err ? reject(err) : resolve(buff.toString())
      );
  });
}

function suggestCommand(cmd: string) {
  console.log(
    `Try to run ${kleur.green(`tznft ${cmd}`)} command to create default config`
  );
}
