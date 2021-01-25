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

  async function bobTransfersNftToDao(nftTokenId: nat): Promise<void> {
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();

    await assertHasNft(bobAddress, nftTokenId);
    $log.info('bob owns the NFT');

    await transferNFT(tezos.bob, nftTokenId, bobAddress, fractionalDao.address);
    await assertHasNft(fractionalDao.address, nftTokenId);
    $log.info('DAO owns the NFT');

    const ownershipOp = await fractionalDao.methods
      .set_ownership(
        nftFa2.address,
        nftTokenId,
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
  }

  async function voteTransferFromDao(
    tz: TezosToolkit,
    to_: address,
    nftFa2: address,
    nftTokenId: nat
  ): Promise<void> {
    const dao = await tz.contract.at(fractionalDao.address);
    const voteOp = await dao.methods
      .vote_transfer(to_, nftFa2, nftTokenId)
      .send();
    await voteOp.confirmation();
    $log.info(`Vote consumed gas ${voteOp.consumedGas}`);
  }

  async function voteTransferFromDaoWithPermit(
    tz: TezosToolkit,
    signer: TezosToolkit,
    to_: address,
    nftFa2: address,
    nftTokenId: nat
  ): Promise<void> {
    const dao = await tz.contract.at(fractionalDao.address);
    const key = await signer.signer.publicKey();
    const signature = await signPermit(signer, to_, nftFa2, nftTokenId);
    const voteOp = await dao.methods
      .vote_transfer(to_, nftFa2, nftTokenId, key, signature)
      .send();
    await voteOp.confirmation();
    $log.info(`Vote with permit consumed gas ${voteOp.consumedGas}`);
  }

  async function signPermit(
    signer: TezosToolkit,
    to_: address,
    nftFa2: address,
    nftTokenId: nat
  ): Promise<string> {
    const chain_id = await signer.rpc.getChainId();
    const { vote_nonce } = await fractionalDao.storage();
    const targetContractAddress = fractionalDao.address;

    const voteD = {
      prim: 'Pair',
      args: [
        { string: to_ },
        {
          prim: 'Pair',
          args: [{ string: nftFa2 }, { int: nftTokenId.toString() }]
        }
      ]
    };
    const voteT = {
      prim: 'pair',
      args: [
        { prim: 'address' },
        {
          prim: 'pair',
          args: [{ prim: 'address' }, { prim: 'nat' }]
        }
      ]
    };

    const nonceVoteD = {
      prim: 'Pair',
      args: [{ int: vote_nonce.toString() }, voteD]
    };
    const nonceVoteT = {
      prim: 'pair',
      args: [{ prim: 'nat' }, voteT]
    };

    const chainTargetD = {
      prim: 'Pair',
      args: [{ string: chain_id }, { string: targetContractAddress }]
    };
    const chainTargetT = {
      prim: 'pair',
      args: [{ prim: 'chain_id' }, { prim: 'address' }]
    };

    const data = {
      prim: 'Pair',
      args: [chainTargetD, nonceVoteD]
    };
    const type = {
      prim: 'pair',
      args: [chainTargetT, nonceVoteT]
    };

    const pack = await signer.rpc.packData({ data, type });
    const sign = await signer.signer.sign(pack.packed);

    return sign.sig;
  }

  test('direct transfer', async () => {
    const aliceAddress = await tezos.alice.signer.publicKeyHash();
    const tokenId = new BigNumber(1);
    await bobTransfersNftToDao(tokenId);

    await voteTransferFromDao(tezos.bob, aliceAddress, nftFa2.address, tokenId);
    await assertHasNft(fractionalDao.address, tokenId);
    $log.info('Bob voted.');

    await voteTransferFromDao(
      tezos.alice,
      aliceAddress,
      nftFa2.address,
      tokenId
    );
    $log.info('Alice voted.');

    await assertHasNft(aliceAddress, tokenId);
    $log.info('NFT is transferred from DAO to Alice');
  });

  test('permit transfer', async () => {
    const aliceAddress = await tezos.alice.signer.publicKeyHash();
    const tokenId = new BigNumber(1);
    await bobTransfersNftToDao(tokenId);

    await voteTransferFromDao(tezos.bob, aliceAddress, nftFa2.address, tokenId);
    await assertHasNft(fractionalDao.address, tokenId);
    $log.info('Bob voted.');

    await voteTransferFromDaoWithPermit(
      tezos.bob,
      tezos.alice,
      aliceAddress,
      nftFa2.address,
      tokenId
    );
    $log.info('Alice voted.');

    await assertHasNft(aliceAddress, tokenId);
    $log.info('NFT is transferred from DAO to Alice');
  });

  test('ownership transfer', async () => {
    const aliceAddress = await tezos.alice.signer.publicKeyHash();
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const tokenId = new BigNumber(1);
    await bobTransfersNftToDao(tokenId);

    const ownershipTokenId = await fractionalDao.views
      .ownership_token(nftFa2.address, tokenId)
      .read(tezos.lambdaView);

    await transfer(fractionalDao.address, tezos.alice, [
      {
        from_: aliceAddress,
        txs: [
          {
            to_: bobAddress,
            token_id: ownershipTokenId,
            amount: new BigNumber(30)
          }
        ]
      }
    ]);
    $log.info('Alice transferred some ownership tokens to Bob.');

    await voteTransferFromDao(tezos.bob, aliceAddress, nftFa2.address, tokenId);
    $log.info('Bob voted.');

    await assertHasNft(aliceAddress, tokenId);
    $log.info('NFT is transferred from DAO to Alice');
  });
});
