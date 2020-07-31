import { $log } from '@tsed/logger';
import { BigNumber } from 'bignumber.js';
import { bootstrap, TestTz } from 'smart-contracts-common/bootstrap-sandbox';
import { Contract, address, nat } from 'smart-contracts-common/type-aliases';
import { defaultLigoEnv } from 'smart-contracts-common/ligo';
import {
  originateInspector,
  queryBalances
} from 'smart-contracts-common/fa2-balance-inspector';

import {
  originateCollection,
  originatePromo,
  originateMoney
} from './origination';

jest.setTimeout(180000);

const ligoEnv = defaultLigoEnv('../../', '../ligo');

describe('collectibles test', () => {
  let tezos: TestTz;
  let inspector: Contract;

  let collection: Contract;
  let money: Contract;

  beforeAll(async () => {
    tezos = await bootstrap();
    inspector = await originateInspector(ligoEnv, tezos.bob);
  });

  beforeEach(async () => {
    collection = await originateCollection(ligoEnv, tezos.bob);
    money = await originateMoney(ligoEnv, tezos.bob);
  });

  test('test', async () => {
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const promotion = await originatePromo(ligoEnv, tezos.bob, {
      promoter: bobAddress,
      money_token: { fa2: money.address, id: new BigNumber(0) },
      collectible_fa2: collection.address,
      price: new BigNumber(5)
    });
    $log.info('test');
  });
});
