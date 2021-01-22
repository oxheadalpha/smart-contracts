import { $log } from '@tsed/logger';
import { BigNumber } from 'bignumber.js';
import { TezosToolkit } from '@taquito/taquito';

import { bootstrap, TestTz } from 'smart-contracts-common/bootstrap-sandbox';
import { Contract, address, nat } from 'smart-contracts-common/type-aliases';
import { defaultLigoEnv } from 'smart-contracts-common/ligo';
import {
  queryBalances,
  hasNftTokens
} from 'smart-contracts-common/fa2-balance-inspector';
import { transfer } from 'smart-contracts-common/fa2-interface';

import {
  originateCollection,
  originatePromo,
  originateMoney
} from './origination';
import * as promo from './promotion';

// jest.setTimeout(180000);
jest.setTimeout(240000);

const ligoEnv = defaultLigoEnv('../../', '../ligo');

interface TokenBalances {
  collectibles: Set<number>;
  money: number;
}

interface GlobalTokenBalances {
  bob: TokenBalances;
  alice: TokenBalances;
  promo: TokenBalances;
}

interface MoneyBalance {
  owner: address;
  balance: nat;
}

describe('collectibles test', () => {
  let tezos: TestTz;

  let collection: Contract;
  let money: Contract;
  let promotion: Contract;

  const moneyTokenId: nat = new BigNumber(0);

  beforeAll(async () => {
    tezos = await bootstrap();
  });

  beforeEach(async () => {
    collection = await originateCollection(ligoEnv, tezos.bob);
    money = await originateMoney(ligoEnv, tezos.bob);

    //setup promotion
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();

    promotion = await originatePromo(ligoEnv, tezos.bob, {
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

  const initialBalances: GlobalTokenBalances = {
    bob: { collectibles: new Set([0, 1, 2, 3, 4, 5, 6]), money: 0 },
    alice: { collectibles: new Set(), money: 100 },
    promo: { collectibles: new Set(), money: 0 }
  };

  async function getOwnedCollectibles(owner: address): Promise<Set<number>> {
    const responses = await queryBalances(
      collection,
      [
        { owner: owner, token_id: new BigNumber(0) },
        { owner: owner, token_id: new BigNumber(1) },
        { owner: owner, token_id: new BigNumber(2) },
        { owner: owner, token_id: new BigNumber(3) },
        { owner: owner, token_id: new BigNumber(4) },
        { owner: owner, token_id: new BigNumber(5) },
        { owner: owner, token_id: new BigNumber(6) }
      ],
      tezos.lambdaView
    );
    return responses
      .filter(r => r.balance.eq(1))
      .reduce(
        (acc, r) => acc.add(r.request.token_id.toNumber()),
        new Set<number>()
      );
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
      money,
      expectedResponses.map(r => r.request),
      tezos.lambdaView
    );
    expect(balances).toEqual(expectedResponses);
  }

  async function assertGlobalState(state: GlobalTokenBalances): Promise<void> {
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();

    //check collectibles ownership
    const bobsRainbowTokens = await getOwnedCollectibles(bobAddress);
    expect(bobsRainbowTokens).toEqual(state.bob.collectibles);

    const aliceRainbowTokens = await getOwnedCollectibles(aliceAddress);
    expect(aliceRainbowTokens).toEqual(state.alice.collectibles);

    const promoTokens = await getOwnedCollectibles(promotion.address);
    expect(promoTokens).toEqual(state.promo.collectibles);

    //check money
    await assertMoneyBalances([
      { owner: bobAddress, balance: new BigNumber(state.bob.money) },
      { owner: aliceAddress, balance: new BigNumber(state.alice.money) },
      { owner: promotion.address, balance: new BigNumber(state.promo.money) }
    ]);
  }

  test('check initial promotion setup', async () => {
    return assertGlobalState(initialBalances);
  });

  test('refund money to promoter', async () => {
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();

    await transfer(collection.address, tezos.bob, [
      {
        from_: bobAddress,
        txs: [
          {
            to_: promotion.address,
            token_id: new BigNumber(0),
            amount: new BigNumber(1)
          },
          {
            to_: promotion.address,
            token_id: new BigNumber(1),
            amount: new BigNumber(1)
          }
        ]
      }
    ]);
    $log.info('collectibles are transferred to promo');

    await transfer(money.address, tezos.alice, [
      {
        from_: aliceAddress,
        txs: [
          {
            to_: promotion.address,
            token_id: moneyTokenId,
            amount: new BigNumber(7)
          }
        ]
      }
    ]);
    $log.info('alice sent some money to promo');
    await assertGlobalState({
      bob: { collectibles: new Set([2, 3, 4, 5, 6]), money: 0 },
      alice: { collectibles: new Set(), money: 93 },
      promo: { collectibles: new Set([0, 1]), money: 7 }
    });

    await promo.refundMoney(tezos.bob, promotion.address);

    $log.info('checking balances after bob refunded');

    await assertMoneyBalances([
      { owner: bobAddress, balance: new BigNumber(5) },
      { owner: aliceAddress, balance: new BigNumber(93) },
      { owner: promotion.address, balance: new BigNumber(2) }
    ]);
  });

  test('refund money to buyer', async () => {
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();

    await transfer(collection.address, tezos.bob, [
      {
        from_: bobAddress,
        txs: [
          {
            to_: promotion.address,
            token_id: new BigNumber(0),
            amount: new BigNumber(1)
          },
          {
            to_: promotion.address,
            token_id: new BigNumber(1),
            amount: new BigNumber(1)
          }
        ]
      }
    ]);
    $log.info('collectibles are transferred to promo');

    await transfer(money.address, tezos.alice, [
      {
        from_: aliceAddress,
        txs: [
          {
            to_: promotion.address,
            token_id: moneyTokenId,
            amount: new BigNumber(7)
          }
        ]
      }
    ]);
    $log.info('alice sent some money to promo');
    await assertGlobalState({
      bob: { collectibles: new Set([2, 3, 4, 5, 6]), money: 0 },
      alice: { collectibles: new Set(), money: 93 },
      promo: { collectibles: new Set([0, 1]), money: 7 }
    });

    await promo.refundMoney(tezos.alice, promotion.address);

    $log.info('checking balances after alice refunded');

    await assertMoneyBalances([
      { owner: bobAddress, balance: new BigNumber(0) },
      { owner: aliceAddress, balance: new BigNumber(95) },
      { owner: promotion.address, balance: new BigNumber(5) }
    ]);
  });

  test('cancel promotion', async () => {
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();

    await transfer(collection.address, tezos.bob, [
      {
        from_: bobAddress,
        txs: [
          {
            to_: promotion.address,
            token_id: new BigNumber(0),
            amount: new BigNumber(1)
          },
          {
            to_: promotion.address,
            token_id: new BigNumber(1),
            amount: new BigNumber(1)
          }
        ]
      }
    ]);
    $log.info('collectibles are transferred to promo');

    await transfer(money.address, tezos.alice, [
      {
        from_: aliceAddress,
        txs: [
          {
            to_: promotion.address,
            token_id: moneyTokenId,
            amount: new BigNumber(3)
          }
        ]
      }
    ]);
    $log.info('alice sent some money to promo');

    await promo.stopPromotion(tezos.bob, promotion.address);

    $log.info('checking balances after promotion has being stopped');
    await assertGlobalState({
      bob: { collectibles: new Set([2, 3, 4, 5, 6]), money: 0 },
      alice: { collectibles: new Set(), money: 97 },
      promo: { collectibles: new Set([0, 1]), money: 3 }
    });

    await promo.disburseCollectibles(tezos.bob, promotion.address);
    await promo.refundMoney(tezos.alice, promotion.address);

    $log.info('checking balances after money/collectibles being disbursed');
    await assertGlobalState(initialBalances);
  });

  test('stop promotion in progress', async () => {
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();

    await transfer(collection.address, tezos.bob, [
      {
        from_: bobAddress,
        txs: [
          {
            to_: promotion.address,
            token_id: new BigNumber(0),
            amount: new BigNumber(1)
          },
          {
            to_: promotion.address,
            token_id: new BigNumber(1),
            amount: new BigNumber(1)
          }
        ]
      }
    ]);
    $log.info('collectibles are transferred to promo');

    await transfer(money.address, tezos.alice, [
      {
        from_: aliceAddress,
        txs: [
          {
            to_: promotion.address,
            token_id: moneyTokenId,
            amount: new BigNumber(7)
          }
        ]
      }
    ]);
    $log.info('alice sent some money to promo');

    $log.info('checking balances');
    await assertGlobalState({
      bob: { collectibles: new Set([2, 3, 4, 5, 6]), money: 0 },
      alice: { collectibles: new Set(), money: 93 },
      promo: { collectibles: new Set([0, 1]), money: 7 }
    });

    await promo.disburseCollectibles(tezos.alice, promotion.address);
    await promo.refundMoney(tezos.alice, promotion.address);

    $log.info(
      'checking balances after money/collectibles being disbursed to alice'
    );
    await assertGlobalState({
      bob: { collectibles: new Set([2, 3, 4, 5, 6]), money: 0 },
      alice: { collectibles: new Set([0]), money: 95 },
      promo: { collectibles: new Set([1]), money: 5 }
    });

    await promo.stopPromotion(tezos.bob, promotion.address);
    await promo.disburseCollectibles(tezos.bob, promotion.address);
    await promo.refundMoney(tezos.bob, promotion.address);

    $log.info(
      'checking balances after money/collectibles being disbursed to bob'
    );
    await assertGlobalState({
      bob: { collectibles: new Set([1, 2, 3, 4, 5, 6]), money: 5 },
      alice: { collectibles: new Set([0]), money: 95 },
      promo: { collectibles: new Set(), money: 0 }
    });
  });

  test('sold out promotion', async () => {
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();

    await transfer(collection.address, tezos.bob, [
      {
        from_: bobAddress,
        txs: [
          {
            to_: promotion.address,
            token_id: new BigNumber(0),
            amount: new BigNumber(1)
          },
          {
            to_: promotion.address,
            token_id: new BigNumber(1),
            amount: new BigNumber(1)
          }
        ]
      }
    ]);
    $log.info('collectibles are transferred to promo');

    await transfer(money.address, tezos.alice, [
      {
        from_: aliceAddress,
        txs: [
          {
            to_: promotion.address,
            token_id: moneyTokenId,
            amount: new BigNumber(20)
          }
        ]
      }
    ]);
    $log.info('alice sent some money to promo');

    $log.info('checking balances');
    await assertGlobalState({
      bob: { collectibles: new Set([2, 3, 4, 5, 6]), money: 0 },
      alice: { collectibles: new Set(), money: 80 },
      promo: { collectibles: new Set([0, 1]), money: 20 }
    });

    await promo.disburseCollectibles(tezos.alice, promotion.address);
    await promo.refundMoney(tezos.alice, promotion.address);

    $log.info(
      'checking balances after money/collectibles being disbursed to alice'
    );
    await assertGlobalState({
      bob: { collectibles: new Set([2, 3, 4, 5, 6]), money: 0 },
      alice: { collectibles: new Set([0, 1]), money: 90 },
      promo: { collectibles: new Set(), money: 10 }
    });

    await promo.disburseCollectibles(tezos.bob, promotion.address);
    await promo.refundMoney(tezos.bob, promotion.address);

    $log.info(
      'checking balances after money/collectibles being disbursed to bob'
    );
    await assertGlobalState({
      bob: { collectibles: new Set([2, 3, 4, 5, 6]), money: 10 },
      alice: { collectibles: new Set([0, 1]), money: 90 },
      promo: { collectibles: new Set(), money: 0 }
    });
  });
});
