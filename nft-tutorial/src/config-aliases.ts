import * as kleur from 'kleur';
import { validateAddress, ValidationResult } from '@taquito/utils';
import { InMemorySigner } from '@taquito/signer';
import { getActiveAliasesCfgKey, loadUserConfig } from './config-util';

export function showAlias(alias: string): void {
  const config = loadUserConfig();
  const aliasesKey = getActiveAliasesCfgKey(config);
  if (alias) {
    const aliasKey = `${aliasesKey}.${alias}`;
    if (config.has(aliasKey)) {
      const aliasDef: any = config.get(aliasKey);
      console.log(kleur.yellow(formatAlias(alias, aliasDef)));
    } else
      console.log(kleur.red(`alias ${kleur.yellow(alias)} is not configured`));
  } else {
    const allAliases = Object.getOwnPropertyNames(config.get(aliasesKey));
    for (let a of allAliases) {
      const aliasKey = `${aliasesKey}.${a}`;
      const aliasDef: any = config.get(aliasKey);
      console.log(kleur.yellow(formatAlias(a, aliasDef)));
    }
  }
}

function formatAlias(alias: string, def: any): string {
  return `${alias}\t${def.address}\t${def.secret ? def.secret : ''}`;
}

export async function addAlias(
  alias: string,
  key_or_address: string
): Promise<void> {
  const config = loadUserConfig();
  const aliasKey = `${getActiveAliasesCfgKey(config)}.${alias}`;
  if (config.has(aliasKey)) {
    console.log(kleur.red(`alias ${kleur.yellow(alias)} already exists`));
    return;
  }
  const aliasDef = await validateKey(key_or_address);
  if (!aliasDef) return;

  config.set(aliasKey, aliasDef);
}

interface AliasDef {
  address: string;
  secret?: string;
}
async function validateKey(
  key_or_address: string
): Promise<AliasDef | undefined> {
  if (validateAddress(key_or_address) === ValidationResult.VALID)
    return { address: key_or_address };
  else
    try {
      const signer = await InMemorySigner.fromSecretKey(key_or_address);
      const address = await signer.publicKeyHash();
      return { address, secret: key_or_address };
    } catch {
      console.log(kleur.red('invalid address or secret key'));
      return undefined;
    }
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
