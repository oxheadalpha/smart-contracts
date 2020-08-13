import Conf from 'conf';
import * as kleur from 'kleur';
import * as path from 'path';
import { BigNumber } from 'bignumber.js';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';
import { InMemorySigner } from '@taquito/signer';
import {
  getActiveNetworkCfg,
  getInspectorKey,
  loadUserConfig,
  loadFile
} from './config-util';
import { resolveAlias2Signer, resolveAlias2Address } from './config-aliases';
import * as fa2 from './fa2-interface';

type InspectorStorage = fa2.BalanceOfResponse[] | {};

export async function createToolkit(
  address_or_alias: string,
  config: Conf<Record<string, string>>
): Promise<TezosToolkit> {
  const signer = await resolveAlias2Signer(address_or_alias, config);
  return createToolkitFromSigner(signer, config);
}

export function createToolkitFromSigner(
  signer: InMemorySigner,
  config: Conf<Record<string, string>>
): TezosToolkit {
  const { network, configKey } = getActiveNetworkCfg(config);
  const providerUrl = config.get(`${configKey}.providerUrl`);
  if (!providerUrl) {
    const msg = `network provider for ${kleur.yellow(
      network
    )} URL is not configured`;
    console.log(kleur.red(msg));
    throw new Error(msg);
  }

  const toolkit = new TezosToolkit();
  toolkit.setProvider({
    signer,
    rpc: providerUrl,
    config: { confirmationPollingIntervalSecond: 5 }
  });
  return toolkit;
}

export async function originateInspector(tezos: TezosToolkit): Promise<string> {
  const code = await loadFile(path.join(__dirname, '../ligo/out/inspector.tz'));
  const storage = `(Left Unit)`;
  return originateContract(tezos, code, storage, 'inspector');
}

export async function mintNfts(
  owner: string,
  tokens: fa2.TokenMetadata[]
): Promise<void> {
  const config = loadUserConfig();
  const tz = await createToolkit(owner, config);
  const ownerAddress = await tz.signer.publicKeyHash();

  const code = await loadFile(
    path.join(__dirname, '../ligo/out/fa2_fixed_collection_token.tz')
  );
  const storage = createNftStorage(tokens, ownerAddress);

  console.log(kleur.yellow('originating new NFT contract'));
  const nftAddress = await originateContract(tz, code, storage, 'nft');
  console.log(
    kleur.yellow(`originated NFT collection ${kleur.green(nftAddress)}`)
  );
}

export function parseTokens(
  descriptor: string,
  tokens: fa2.TokenMetadata[]
): fa2.TokenMetadata[] {
  const [id, symbol, name] = descriptor.split(',').map(p => p.trim());
  const token: fa2.TokenMetadata = {
    token_id: new BigNumber(id),
    symbol,
    name,
    decimals: new BigNumber(0),
    extras: new MichelsonMap()
  };
  return [token].concat(tokens);
}

function createNftStorage(tokens: fa2.TokenMetadata[], owner: string) {
  const ledger = new MichelsonMap<BigNumber, string>();
  const token_metadata = new MichelsonMap<BigNumber, fa2.TokenMetadata>();
  for (let meta of tokens) {
    ledger.set(meta.token_id, owner);
    token_metadata.set(meta.token_id, meta);
  }
  return {
    ledger,
    operators: new MichelsonMap(),
    token_metadata
  };
}

export async function showBalances(
  operator: string,
  nft: string,
  owner: string,
  tokens: string[]
): Promise<void> {
  const config = loadUserConfig();

  const tz = await createToolkit(owner, config);
  const ownerAddress = await tz.signer.publicKeyHash();
  const requests: fa2.BalanceOfRequest[] = tokens.map(t => {
    return { token_id: new BigNumber(t), owner: ownerAddress };
  });

  const inspectorKey = getInspectorKey(config);
  const inspectorAddress = config.get(inspectorKey);
  if (!inspectorAddress) {
    console.log(
      kleur.red(
        'Cannot find deployed balance inspector contract.\nTry to kill and start network again.'
      )
    );
    return;
  }

  console.log(
    kleur.yellow(
      `querying NFT contract ${kleur.green(
        nft
      )} using balance inspector ${kleur.green(inspectorAddress)}`
    )
  );
  const inspector = await tz.contract.at(inspectorAddress);
  const balanceOp = await inspector.methods.query(nft, requests).send();
  await balanceOp.confirmation();
  const storage = await inspector.storage<InspectorStorage>();
  if (Array.isArray(storage)) printBalances(storage);
  else {
    console.log(kleur.red('invalid inspector storage state'));
    return Promise.reject('Invalid inspector storage state Empty.');
  }
}

function printBalances(balances: fa2.BalanceOfResponse[]): void {
  console.log(kleur.green('requested NFT balances:'));
  for (let b of balances) {
    console.log(
      kleur.yellow(
        `owner: ${kleur.green(b.request.owner)}\ttoken: ${kleur.green(
          b.request.token_id.toString()
        )}\tbalance: ${kleur.green(b.balance.toString())}`
      )
    );
  }
}

export async function showMetadata(
  operator: string,
  nft: string,
  tokens: string[]
): Promise<void> {
  const config = loadUserConfig();

  const tz = await createToolkit(operator, config);
  const nftContract = await tz.contract.at(nft);
  const storage = await nftContract.storage<any>();
  const meta: MichelsonMap<BigNumber, fa2.TokenMetadata> =
    storage.token_metadata;

  const tokensMetaP = tokens
    .map(t => new BigNumber(t))
    .map(async tid => {
      return { tid, meta: await meta.get(tid) };
    });
  const tokensMeta = await Promise.all(tokensMetaP);

  tokensMeta.forEach(m => {
    if (m.meta) printTokenMetadata(m.meta);
    else console.log(kleur.red(`token ${m.tid} is missing`));
  });
}

function printTokenMetadata(m: fa2.TokenMetadata) {
  console.log(
    kleur.yellow(
      `token_id: ${kleur.green(m.token_id.toString())}\tsymbol: ${kleur.green(
        m.symbol
      )}\tname: ${kleur.green(m.name)}\textras: ${formatMichelsonMap(m.extras)}`
    )
  );
}

function formatMichelsonMap(m: MichelsonMap<string, string>): string {
  let result = '{ ';
  m.forEach((v, k) => (result += `${kleur.dim().green(k)}=${kleur.green(v)} `));
  result += '}';
  return result;
}

export function parseTransfers(
  description: string,
  batch: fa2.Fa2Transfer[]
): fa2.Fa2Transfer[] {
  const [from_, to_, token_id] = description.split(',').map(p => p.trim());
  const tx: fa2.Fa2Transfer = {
    from_,
    txs: [
      {
        to_,
        token_id: new BigNumber(token_id),
        amount: new BigNumber(1)
      }
    ]
  };
  if (batch.length > 0 && batch[0].from_ === from_) {
    //merge last two transfers if their from_ addresses are the same
    batch[0].txs = batch[0].txs.concat(tx.txs);
    return batch;
  }

  return batch.concat(tx);
}

export async function transfer(
  operator: string,
  nft: string,
  batch: fa2.Fa2Transfer[]
): Promise<void> {
  const config = loadUserConfig();
  const txs = await resolveTxAddresses(batch, config);
  const tz = await createToolkit(operator, config);
  await fa2.transfer(nft, tz, txs);
}

async function resolveTxAddresses(
  transfers: fa2.Fa2Transfer[],
  config: Conf<Record<string, string>>
): Promise<fa2.Fa2Transfer[]> {
  const resolved = transfers.map(async t => {
    return {
      from_: await resolveAlias2Address(t.from_, config),
      txs: await resolveTxDestinationAddresses(t.txs, config)
    };
  });
  return Promise.all(resolved);
}

async function resolveTxDestinationAddresses(
  txs: fa2.Fa2TransferDestination[],
  config: Conf<Record<string, string>>
): Promise<fa2.Fa2TransferDestination[]> {
  const resolved = txs.map(async t => {
    return {
      to_: await resolveAlias2Address(t.to_, config),
      amount: t.amount,
      token_id: t.token_id
    };
  });
  return Promise.all(resolved);
}

export async function updateOperators(
  owner: string,
  nft: string,
  addOperators: string[],
  removeOperators: string[]
): Promise<void> {
  const config = loadUserConfig();
  const tz = await createToolkit(owner, config);
  const resolvedAdd = await resolveOperators(addOperators, config);
  const resolvedRemove = await resolveOperators(removeOperators, config);
  await fa2.updateOperators(nft, tz, resolvedAdd, resolvedRemove);
}

async function resolveOperators(
  operators: string[],
  config: Conf<Record<string, string>>
): Promise<string[]> {
  const resolved = operators.map(async o => resolveAlias2Address(o, config));
  return Promise.all(resolved);
}

async function originateContract(
  tz: TezosToolkit,
  code: string,
  storage: string | object,
  name: string
): Promise<string> {
  const origParam =
    typeof storage === 'string' ? { code, init: storage } : { code, storage };
  try {
    const originationOp = await tz.contract.originate(origParam);
    const contract = await originationOp.contract();
    return contract.address;
  } catch (error) {
    const jsonError = JSON.stringify(error, null, 2);
    console.log(kleur.red(`${name} origination error ${jsonError}`));
    return Promise.reject(jsonError);
  }
}
