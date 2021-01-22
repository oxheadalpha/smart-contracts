import { $log } from '@tsed/logger';
import { BigNumber } from 'bignumber.js';
import { TezosToolkit } from '@taquito/taquito';

import { bootstrap, TestTz } from 'smart-contracts-common/bootstrap-sandbox';
import { Contract, address, nat } from 'smart-contracts-common/type-aliases';
import { defaultLigoEnv } from 'smart-contracts-common/ligo';
import { originateNftCollection, originateFractionalDao } from './origination';
import {
  queryBalances,
  hasNftTokens
} from 'smart-contracts-common/fa2-balance-inspector';
import { transfer } from 'smart-contracts-common/fa2-interface';

jest.setTimeout(240000);

const ligoEnv = defaultLigoEnv('../../', '../ligo');

describe('fractional ownership test', () => {
  let tezos: TestTz;
  let nftFa2: Contract;
  let fractionalDao: Contract;

  beforeAll(async () => {
    tezos = await bootstrap();
  });

  beforeEach(async () => {
    nftFa2 = await originateNftCollection(ligoEnv, tezos.bob);
    fractionalDao = await originateFractionalDao(ligoEnv, tezos.bob);
  });

  async function assertHasNft(owner: address, token_id: nat): Promise<void> {
    const [hasIt] = await hasNftTokens(
      nftFa2,
      [{ owner, token_id }],
      tezos.lambdaView
    );
    expect(hasIt).toBe(true);
  }

  async function transferNFT(
    tz: TezosToolkit,
    token_id: nat,
    from_: address,
    to_: address
  ): Promise<void> {
    await transfer(nftFa2.address, tz, [
      {
        from_,
        txs: [{ to_, token_id, amount: new BigNumber(1) }]
      }
    ]);
  }

  test('direct transfer', async () => {
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();
    const tokenId = new BigNumber(1);
    await assertHasNft(bobAddress, tokenId);
    $log.info('bob owns the NFT');

    await transferNFT(tezos.bob, tokenId, bobAddress, fractionalDao.address);
    await assertHasNft(fractionalDao.address, tokenId);
    $log.info('DAO owns the NFT');

    const ownershipOp = await fractionalDao.methods
      .set_ownership(
        nftFa2.address,
        tokenId,
        [
          { owner: bobAddress, amount: 50 },
          { owner: aliceAddress, amount: 50 }
        ],
        75, //voting_threshold
        10000000 // voting_period
      )
      .send({ source: bobAddress });
    await ownershipOp.confirmation();
    $log.info('DAO ownership parameters are set');

    const bobVoteOp = await fractionalDao.methods
      .vote_transfer(
        aliceAddress, //to_
        nftFa2.address,
        tokenId
      )
      .send();
    await bobVoteOp.confirmation();
    await assertHasNft(fractionalDao.address, tokenId);
    $log.info(`Bob voted. Consumed gas ${bobVoteOp.consumedGas}`);

    const aliceFractionalDao = await tezos.alice.contract.at(
      fractionalDao.address
    );
    const aliceVoteOp = await aliceFractionalDao.methods
      .vote_transfer(
        aliceAddress, //to_
        nftFa2.address,
        tokenId
      )
      .send();
    await aliceVoteOp.confirmation();
    $log.info(`Alice voted. Consumed gas ${aliceVoteOp.consumedGas}`);

    await assertHasNft(aliceAddress, tokenId);
    $log.info('NFT is transferred from DAO to Alice');
  });
});
