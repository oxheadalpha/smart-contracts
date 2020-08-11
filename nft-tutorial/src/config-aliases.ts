import Conf from 'conf';
import * as kleur from 'kleur';
import { validateAddress, ValidationResult } from '@taquito/utils';
import { InMemorySigner } from '@taquito/signer';
import { getActiveAliasesCfgKey, loadUserConfig } from './config-util';
import { stringify } from 'querystring';

export function showAlias(alias: string): void {
  const config = loadUserConfig();
  const aliasesKey = getActiveAliasesCfgKey(config, false);
  if (alias) {
    const aliasKey = `${aliasesKey}.${alias}`;
    if (config.has(aliasKey)) {
      const aliasDef: any = config.get(aliasKey);
      console.log(kleur.yellow(formatAlias(alias, aliasDef)));
    } else
      console.log(kleur.red(`alias ${kleur.yellow(alias)} is not configured`));
  } else if (config.has(aliasesKey)) {
    const allAliases = Object.getOwnPropertyNames(config.get(aliasesKey));
    for (let a of allAliases) {
      const aliasKey = `${aliasesKey}.${a}`;
      const aliasDef: any = config.get(aliasKey);
      console.log(kleur.yellow(formatAlias(a, aliasDef)));
    }
  } else console.log(kleur.yellow('there are no configured aliases'));
}

function formatAlias(alias: string, def: any): string {
  return `${alias}\t${def.address}\t${def.secret ? def.secret : ''}`;
}

export async function addAlias(
  alias: string,
  key_or_address: string
): Promise<void> {
  const config = loadUserConfig();
  const aliasKey = `${getActiveAliasesCfgKey(config, false)}.${alias}`;
  if (config.has(aliasKey)) {
    console.log(kleur.red(`alias ${kleur.yellow(alias)} already exists`));
    return;
  }
  const aliasDef = await validateKey(key_or_address);
  if (!aliasDef) {
    console.log(kleur.red('invalid address or secret key'));
    return;
  }

  config.set(aliasKey, aliasDef);
}

interface AliasDef {
  address: string;
  secret?: string;
  signer?: InMemorySigner;
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
      return { address, secret: key_or_address, signer };
    } catch {
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

export async function resolveAlias2Signer(
  alias_or_address: string,
  config: Conf<Record<string, string>>
): Promise<InMemorySigner> {
  const aliasKey = `${getActiveAliasesCfgKey(config)}.${alias_or_address}`;
  const aliasDef: any = config.get(aliasKey);
  if (aliasDef?.secret) {
    const ad = await validateKey(aliasDef.secret);
    if (ad?.signer) return ad.signer;
  }

  if (validateAddress(alias_or_address) !== ValidationResult.VALID)
    return cannotResolve(alias_or_address);

  const ad = findAlias(config, ad => ad.address === alias_or_address);
  if (!ad?.secret) return cannotResolve(alias_or_address);

  return InMemorySigner.fromSecretKey(ad.secret);
}

function findAlias(
  config: Conf<Record<string, string>>,
  predicate: (aliasDef: any) => boolean
): any {
  const aliasesKey = getActiveAliasesCfgKey(config);
  const allAliases = Object.getOwnPropertyNames(config.get(aliasesKey));
  for (let a of allAliases) {
    const aliasKey = `${aliasesKey}.${a}`;
    const aliasDef: any = config.get(aliasKey);
    if (predicate(aliasDef)) return aliasDef;
  }
  return undefined;
}

export async function resolveAlias2Address(
  alias_or_address: string,
  config: Conf<Record<string, string>>
): Promise<string> {
  if (validateAddress(alias_or_address) === ValidationResult.VALID)
    return alias_or_address;

  const aliasKey = `${getActiveAliasesCfgKey(config)}.${alias_or_address}`;
  if (!config.has(aliasKey)) return cannotResolve(alias_or_address);

  const aliasDef: any = config.get(aliasKey);
  return aliasDef.address;
}

function cannotResolve<T>(alias_or_address: string): Promise<T> {
  console.log(
    kleur.red(
      `${kleur.yellow(
        alias_or_address
      )} is not a valid address or configured alias`
    )
  );
  return Promise.reject('cannot resolve address or alias');
}
