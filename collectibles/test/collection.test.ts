import { $log } from '@tsed/logger';
import { bootstrap, TestTz } from './bootstrap-sandbox';
// import { Contract, address, nat } from './type-aliases';
// import {
//   originateInspector,
//   InspectorStorage,
//   queryBalances
// } from './fa2-balance-inspector';

describe('collectibles test', () => {
  let tezos: TestTz;
  // let inspector: Contract;

  beforeAll(async () => {
    tezos = await bootstrap();
    // inspector = await originateInspector(tezos.bob);
  });

  test('test', () => {
    $log.info('test');
  });
});
