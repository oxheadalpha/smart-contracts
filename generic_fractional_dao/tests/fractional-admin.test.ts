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
  DaoStorage,
  setDaoVotingThresholdParam,
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

  test("Set DAO voting threshold", async () => {
    const storage0 = await fractionalDao.storage<DaoStorage>();
    const lambda = await setDaoVotingThresholdParam(
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

    const signature = await signPermit(
      tezos.alice,
      fractionalDao,
      lambda.lambdaMichelson
    );
    const aliceKey = await tezos.alice.signer.publicKey();
    $log.info("Alice votes with permit...");
    const op2 = await fractionalDao.methods
      .vote(lambda.lambdaExp, aliceKey, signature)
      .send();
    await op2.confirmation();
    $log.info("Alice voted");

    const storage2 = await fractionalDao.storage<DaoStorage>();
    expect(storage2.voting_threshold.toNumber()).toBe(50);
  });
});
