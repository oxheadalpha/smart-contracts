import { $log } from '@tsed/logger';
import { bootstrap, TestTz } from 'smart-contracts-common/bootstrap-sandbox';
import { Contract, address, nat } from 'smart-contracts-common/type-aliases';
import { defaultLigoEnv } from 'smart-contracts-common/ligo';
import {
  originateInspector,
  InspectorStorage,
  queryBalances
} from 'smart-contracts-common/fa2-balance-inspector';

import { originateCollection } from './origination';

jest.setTimeout(180000);

const ligoEnv = defaultLigoEnv('../../', '../ligo');

describe('collectibles test', () => {
  let tezos: TestTz;
  let inspector: Contract;

  let collection: Contract;

  beforeAll(async () => {
    tezos = await bootstrap();
    inspector = await originateInspector(ligoEnv, tezos.bob);
  });

  beforeEach(async () => {
    collection = await originateCollection(ligoEnv, tezos.bob);
  });

  test('test', () => {
    $log.info('test');
  });
});
