import { $log } from '@tsed/logger';
import { BigNumber } from 'bignumber.js';
import { bootstrap, TestTz } from 'smart-contracts-common/bootstrap-sandbox';
import { Contract, address, nat } from 'smart-contracts-common/type-aliases';
import { defaultLigoEnv } from 'smart-contracts-common/ligo';
import {
  originateInspector,
  queryBalances,
  hasNftTokens
} from 'smart-contracts-common/fa2-balance-inspector';
import {
  BalanceOfRequest,
  BalanceOfResponse
} from 'smart-contracts-common/fa2-interface';

import {
  originateCollection,
  originatePromo,
  originateMoney
} from './origination';
import { TezosToolkit } from '@taquito/taquito';

jest.setTimeout(180000);

const ligoEnv = defaultLigoEnv('../../', '../ligo');

describe('collectibles test', () => {
  let tezos: TestTz;
  let inspector: Contract;

  let collection: Contract;
  let money: Contract;

  const moneyTokenId: nat = new BigNumber(0);

  beforeAll(async () => {
    tezos = await bootstrap();
    inspector = await originateInspector(ligoEnv, tezos.bob);
  });

  beforeEach(async () => {
    collection = await originateCollection(ligoEnv, tezos.bob);
    money = await originateMoney(ligoEnv, tezos.bob);

    //setup promotion
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();

    const promotion = await originatePromo(ligoEnv, tezos.bob, {
      promoter: bobAddress,
      money_token: { fa2: money.address, id: new BigNumber(0) },
      collectible_fa2: collection.address,
      price: new BigNumber(5)
    });

    await mintMoney(tezos.bob, aliceAddress, new BigNumber(100));
  });

  async function mintMoney(
    admin: TezosToolkit,
    owner: address,
    amount: nat
  ): Promise<void> {
    const op = await money.methods.mint_tokens([{ owner, amount }]).send();
    await op.confirmation();
    $log.info(`minted money. Consumed gas: ${op.consumedGas}`);
  }

  async function getCollectiblesOwnershipFor(
    owner: address
  ): Promise<boolean[]> {
    return hasNftTokens(inspector, collection.address, [
      { owner: owner, token_id: new BigNumber(0) },
      { owner: owner, token_id: new BigNumber(1) },
      { owner: owner, token_id: new BigNumber(2) },
      { owner: owner, token_id: new BigNumber(3) },
      { owner: owner, token_id: new BigNumber(4) },
      { owner: owner, token_id: new BigNumber(5) },
      { owner: owner, token_id: new BigNumber(6) }
    ]);
  }

  interface MoneyBalance {
    owner: address;
    balance: nat;
  }

  async function assertMoneyBalances(
    expectedBalances: MoneyBalance[]
  ): Promise<void> {
    const expectedResponses = expectedBalances.map(b => {
      return {
        request: {
          owner: b.owner,
          token_id: new BigNumber(0)
        },
        balance: b.balance
      };
    });

    const balances = await queryBalances(
      inspector,
      money.address,
      expectedResponses.map(r => r.request)
    );
    expect(balances).toEqual(expectedResponses);
  }

  test('check initial promotion setup', async () => {
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();

    //check collectibles ownership
    const bobsRainbowTokens = await getCollectiblesOwnershipFor(bobAddress);
    expect(bobsRainbowTokens).toEqual(expect.arrayContaining([true]));
    const aliceRainbowTokens = await getCollectiblesOwnershipFor(aliceAddress);
    expect(aliceRainbowTokens).toEqual(expect.arrayContaining([false]));

    //check money
    await assertMoneyBalances([
      { owner: bobAddress, balance: new BigNumber(0) },
      { owner: aliceAddress, balance: new BigNumber(100) }
    ]);
  });
});
