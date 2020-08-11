import Conf from 'conf';
import * as path from 'path';
import * as fs from 'fs';
import * as kleur from 'kleur';

const userConfigFile = path.join(process.cwd(), 'tznft');
export const userConfigFileWithExt = userConfigFile + '.json';

export function loadUserConfig(): Conf<Record<string, string>> {
  if (fs.existsSync(userConfigFileWithExt))
    return new Conf({
      configName: 'tznft',
      cwd: process.cwd(),
      serialize: v => JSON.stringify(v, null, 2)
    });
  else {
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

export function getActiveNetworkCfg(
  config: Conf<Record<string, string>>
): ActiveNetworkCfg {
  const network = config.get('activeNetwork');
  if (!network) {
    console.log(kleur.red('No active network selected'));
    suggestCommand('set-network <network>');
    throw new Error('No active network selected');
  }

  const configKey = `availableNetworks.${network}`;
  if (!config.has(configKey)) {
    const msg = `Currently active network ${kleur.yellow(
      network
    )}  is not configured`;
    console.log(kleur.red(msg));
    suggestCommand('set-network <network>');
    throw new Error(msg);
  }

  return { network, configKey };
}

export function getActiveAliasesCfgKey(
  config: Conf<Record<string, string>>,
  validate: boolean = true
): string {
  const { configKey } = getActiveNetworkCfg(config);

  const aliasesConfigKey = `${configKey}.aliases`;
  if (!config.has(aliasesConfigKey) && validate) {
    const msg = 'there are no configured account aliases';
    console.log(kleur.red(msg));
    throw new Error(msg);
  }

  return aliasesConfigKey;
}

export function getInspectorKey(config: Conf<Record<string, string>>): string {
  const { configKey } = getActiveNetworkCfg(config);
  return `${configKey}.inspector`;
}

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
