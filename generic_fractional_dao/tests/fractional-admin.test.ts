import { $log } from "@tsed/logger";
import { BigNumber } from "bignumber.js";
import { TezosToolkit } from "@taquito/taquito";

import { bootstrap, TestTz } from "smart-contracts-common/bootstrap-sandbox";
import { Contract, address, nat } from "smart-contracts-common/type-aliases";
import { defaultLigoEnv } from "smart-contracts-common/ligo";

import {
  originateNftCollection,
  originateFractionalDao,
} from "../src/origination";

import {
  DaoLambda,
  DaoStorage,
  setDaoVotingPeriod,
  setDaoVotingThreshold,
  signPermit,
} from "../src/lambdas";

jest.setTimeout(240000);

const ligoEnv = defaultLigoEnv("../../", "ligo");

describe("fractional ownership test", () => {
  let tezos: TestTz;
  let nftFa2: Contract;
  let fractionalDao: Contract;

  beforeAll(async () => {
    tezos = await bootstrap();
  });

  beforeEach(async () => {
    // nftFa2 = await originateNftCollection(ligoEnv, tezos.bob);
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();
    fractionalDao = await originateFractionalDao(
      ligoEnv,
      tezos.bob,
      bobAddress,
      aliceAddress
    );
  });

  const voteWithPermit = async (voter: TezosToolkit, lambda: DaoLambda) => {
    const signature = await signPermit(
      voter,
      fractionalDao,
      lambda.lambdaMichelson
    );
    const voterKey = await voter.signer.publicKey();
    const op = await fractionalDao.methods
      .vote(lambda.lambdaExp, voterKey, signature)
      .send();
    await op.confirmation();
    $log.info(`Consumed gas ${op.consumedGas}`);
  };

  test("Set DAO voting threshold", async () => {
    const storage0 = await fractionalDao.storage<DaoStorage>();
    const lambda = await setDaoVotingThreshold(
      ligoEnv,
      storage0.voting_threshold.toNumber(),
      50
    );

    $log.info("Bob votes...");
    const op1 = await fractionalDao.methods.vote(lambda.lambdaExp).send();
    await op1.confirmation();
    $log.info("Bob voted");

    const storage1 = await fractionalDao.storage<DaoStorage>();
    expect(storage1.vote_count.toNumber()).toBe(
      storage0.vote_count.toNumber() + 1
    );
    expect(storage1.voting_threshold.toNumber()).toBe(
      storage0.voting_threshold.toNumber()
    );

    $log.info("Alice votes with permit...");
    await voteWithPermit(tezos.alice, lambda);
    $log.info("Alice voted");

    const storage2 = await fractionalDao.storage<DaoStorage>();
    expect(storage2.voting_threshold.toNumber()).toBe(50);
  });

  test("Set DAO voting period", async () => {
    const storage0 = await fractionalDao.storage<DaoStorage>();
    const lambda = await setDaoVotingPeriod(
      ligoEnv,
      storage0.voting_period.toNumber(),
      600
    );

    $log.info("Bob votes...");
    const op1 = await fractionalDao.methods.vote(lambda.lambdaExp).send();
    await op1.confirmation();
    $log.info("Bob voted");

    const storage1 = await fractionalDao.storage<DaoStorage>();
    expect(storage1.vote_count.toNumber()).toBe(
      storage0.vote_count.toNumber() + 1
    );
    expect(storage1.voting_period.toNumber()).toBe(
      storage0.voting_period.toNumber()
    );

    $log.info("Alice votes with permit...");
    await voteWithPermit(tezos.alice, lambda);
    $log.info("Alice voted");

    const storage2 = await fractionalDao.storage<DaoStorage>();
    expect(storage2.voting_period.toNumber()).toBe(600);
  });
});
