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
