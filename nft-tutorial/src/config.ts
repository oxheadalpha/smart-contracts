import Conf from 'conf';
import * as path from 'path';
import * as fs from 'fs';
import * as kleur from 'kleur';

const userConfigFile = path.join(process.cwd(), 'tznft');
const userConfigFileWithExt = userConfigFile + '.json';

function loadUserConfig(): Conf {
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
    return fs.copyFileSync(
      path.join(__dirname, '../tznft.json'),
      userConfigFileWithExt
    );
  }
}

export function showConfig(): void {
  const config = new Conf({
    configName: 'tznft',
    cwd: path.join(__dirname, '../'),
    serialize: v => JSON.stringify(v, null, 2)
  });
  const j = JSON.stringify(config.store, null, 2);
  console.info(j);
}
