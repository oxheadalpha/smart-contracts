import { $log } from "@tsed/logger";
import { TezosToolkit } from "@taquito/taquito";
import { bootstrap, TestTz } from "smart-contracts-common/bootstrap-sandbox";
import { Contract, address, nat } from "smart-contracts-common/type-aliases";
import { defaultLigoEnv } from "smart-contracts-common/ligo";

import {
  originateFractionalDao,
  originateNftCollection,
} from "../src/origination";

import { hasNftTokens } from "smart-contracts-common/fa2-balance-inspector";
import { transfer } from "smart-contracts-common/fa2-interface";

import {
  DaoStorage,
  transferFA2TokensLambda,
  updateOperatorsLambda,
  vote,
  voteWithPermit,
} from "../src/dao";

import BigNumber from "bignumber.js";

jest.setTimeout(240000);

const ligoEnv = defaultLigoEnv("../../", "ligo");

describe("fractional ownership FA2 NFT tests", () => {
  let tezos: TestTz;
  let nftFa2: Contract;
  let fractionalDao: Contract;

  beforeAll(async () => {
    tezos = await bootstrap();
  });

  beforeEach(async () => {
    nftFa2 = await originateNftCollection(ligoEnv, tezos.bob);
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();
    fractionalDao = await originateFractionalDao(
      ligoEnv,
      tezos.bob,
      bobAddress,
      aliceAddress
    );
  });

  async function hasNft(owner: address, token_id: nat): Promise<boolean> {
    const [hasIt] = await hasNftTokens(
      nftFa2,
      [{ owner, token_id }],
      tezos.lambdaView
    );
    return hasIt;
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
        txs: [{ to_, token_id, amount: new BigNumber(1) }],
      },
    ]);
  }

  test("Transfer NFT from DAO", async () => {
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();
    const nftTokenId = new BigNumber(5);

    $log.info("Transferring NFT from Bob to DAO");
    await transferNFT(tezos.bob, nftTokenId, bobAddress, fractionalDao.address);
    const daoHasNft = await hasNft(fractionalDao.address, nftTokenId);
    expect(daoHasNft).toBe(true);
    $log.info("Transferred NFT to DAO");

    const lambda = await transferFA2TokensLambda(ligoEnv, nftFa2.address, [
      {
        from_: fractionalDao.address,
        txs: [
          {
            to_: aliceAddress,
            token_id: nftTokenId,
            amount: new BigNumber(1),
          },
        ],
      },
    ]);

    $log.info("Bob voting to transfer NFT from DAO to Alice");
    await vote(fractionalDao, lambda);
    $log.info("Bob voted");
    const aliceHasNft1 = await hasNft(aliceAddress, nftTokenId);
    expect(aliceHasNft1).toBe(false);

    $log.info("Alice voting to transfer NFT from DAO to Alice");
    await voteWithPermit(fractionalDao, tezos.alice, lambda);
    $log.info("Alice voted");

    const aliceHasNft2 = await hasNft(aliceAddress, nftTokenId);
    expect(aliceHasNft2).toBe(true);
    $log.info("NFT transferred from DAO to Alice");
  });

  test("FA2 update operators from DAO", async () => {
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();
    const nftTokenId = new BigNumber(5);

    $log.info("Transferring NFT from Bob to DAO");
    await transferNFT(tezos.bob, nftTokenId, bobAddress, fractionalDao.address);
    const daoHasNft = await hasNft(fractionalDao.address, nftTokenId);
    expect(daoHasNft).toBe(true);
    $log.info("Transferred NFT to DAO");

    const lambda = await updateOperatorsLambda(ligoEnv, nftFa2.address, [
      {
        add_operator: {
          owner: fractionalDao.address,
          operator: aliceAddress,
          token_id: nftTokenId,
        },
      },
    ]);
    $log.info("Bob voting to make Alice an NFT operator");
    await vote(fractionalDao, lambda);
    $log.info("Bob voted");

    $log.info("Alice voting to make Alice an NFT operator");
    await voteWithPermit(fractionalDao, tezos.alice, lambda);
    $log.info("Alice voted");

    $log.info("Alice transferring NFT token from DAO as an operator");
    await transferNFT(
      tezos.alice,
      nftTokenId,
      fractionalDao.address,
      aliceAddress
    );
    const aliceOwnNft = await hasNft(aliceAddress, nftTokenId);
    $log.info("Alice transferred NFT token");
  });
});
