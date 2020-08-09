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
    console.log(kleur.red('no tznft.json config file found'));
    console.log(
      `Try to run ${kleur.green(
        'tznft config init'
      )} command to create default config`
    );
    throw new Error('no tznft.json config file found');
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
    console.log(
      kleur.red(
        `Try to run ${kleur.yellow(
          'tznft config set-network <network>'
        )} command`
      )
    );
    throw new Error('No active network selected');
  }

  const configKey = `availableNetworks.${network}`;
  if (!config.has(configKey)) {
    const msg = `Currently active network ${kleur.yellow(
      network
    )}  is not configured`;
    console.log(kleur.red(msg));
    console.log(
      kleur.red(
        `Try to select configured network by running ${kleur.yellow(
          'tznft config set-network <network>'
        )} command`
      )
    );
    throw new Error(msg);
  }

  return { network, configKey };
}

export function getActiveAliasesCfgKey(
  config: Conf<Record<string, string>>,
  validate: boolean = true
): string {
  const { network, configKey } = getActiveNetworkCfg(config);

  const aliasesConfigKey = `${configKey}.aliases`;
  if (!config.has(aliasesConfigKey) && validate) {
    const msg = 'there are no configured account aliases';
    console.log(kleur.red(msg));
    throw new Error(msg);
  }

  return aliasesConfigKey;
}
