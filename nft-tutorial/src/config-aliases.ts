import * as kleur from 'kleur';
import { getActiveAliasesCfgKey, loadUserConfig } from './config-util';

export function showAlias(alias: string): void {
  const config = loadUserConfig();
  const aliasesKey = getActiveAliasesCfgKey(config);
  if (alias) {
    const aliasKey = `${aliasesKey}.${alias}`;
    if (config.has(aliasKey)) {
      const key_or_address = config.get(aliasKey);
      console.log(kleur.yellow(`${alias}\t${key_or_address}`));
    } else
      console.log(kleur.red(`alias ${kleur.yellow(alias)} is not configured`));
  } else {
    const allAliases = Object.getOwnPropertyNames(config.get(aliasesKey));
    for (let a of allAliases) {
      const aliasKey = `${aliasesKey}.${a}`;
      const key_or_address = config.get(aliasKey);
      console.log(kleur.yellow(`${a}\t${key_or_address}`));
    }
  }
}

export function addAlias(alias: string, key_or_address: string): void {
  const config = loadUserConfig();
  const aliasKey = `${getActiveAliasesCfgKey(config)}.${alias}`;
  if (config.has(aliasKey)) {
    console.log(kleur.red(`alias ${kleur.yellow(alias)} already exists`));
    return;
  }
  if (!(key_or_address.startsWith('tz') || key_or_address.startsWith('edsk'))) {
    console.log(
      kleur.red('alias value can be either private key or tz address')
    );
    return;
  }

  config.set(aliasKey, key_or_address);
}

export function removeAlias(alias: string): void {
  const config = loadUserConfig();
  const aliasKey = `${getActiveAliasesCfgKey(config)}.${alias}`;
  if (!config.has(aliasKey)) {
    console.log(kleur.red(`alias ${kleur.yellow(alias)} does not exists`));
    return;
  }
  config.delete(aliasKey);
}
