import { $log } from "@tsed/logger";
import { bootstrap, TestTz } from "smart-contracts-common/bootstrap-sandbox";
import { Contract, address, nat } from "smart-contracts-common/type-aliases";
import { defaultLigoEnv } from "smart-contracts-common/ligo";

import { originateFractionalDao } from "../src/origination";

import {
  DaoStorage,
  setDaoVotingPeriodLambda,
  setDaoVotingThresholdLambda,
  vote,
  voteWithPermit,
} from "../src/dao";

import { transfer } from "smart-contracts-common/fa2-interface";
import BigNumber from "bignumber.js";

jest.setTimeout(240000);

const ligoEnv = defaultLigoEnv("../../", "ligo");

describe("fractional ownership admin entry points test", () => {
  let tezos: TestTz;
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
    const lambda = await setDaoVotingThresholdLambda(
      ligoEnv,
      storage0.voting_threshold.toNumber(),
      50
    );

    $log.info("Bob votes...");
    await vote(fractionalDao, lambda);
    $log.info("Bob voted");

    const storage1 = await fractionalDao.storage<DaoStorage>();
    expect(storage1.vote_count.toNumber()).toBe(
      storage0.vote_count.toNumber() + 1
    );
    expect(storage1.voting_threshold.toNumber()).toBe(
      storage0.voting_threshold.toNumber()
    );

    $log.info("Alice votes with permit...");
    await voteWithPermit(fractionalDao, tezos.alice, lambda);
    $log.info("Alice voted");

    const storage2 = await fractionalDao.storage<DaoStorage>();
    expect(storage2.voting_threshold.toNumber()).toBe(50);
  });

  test("Set DAO voting period", async () => {
    const storage0 = await fractionalDao.storage<DaoStorage>();
    const lambda = await setDaoVotingPeriodLambda(
      ligoEnv,
      storage0.voting_period.toNumber(),
      600
    );

    $log.info("Bob votes...");
    await vote(fractionalDao, lambda);
    $log.info("Bob voted");

    const storage1 = await fractionalDao.storage<DaoStorage>();
    expect(storage1.vote_count.toNumber()).toBe(
      storage0.vote_count.toNumber() + 1
    );
    expect(storage1.voting_period.toNumber()).toBe(
      storage0.voting_period.toNumber()
    );

    $log.info("Alice votes with permit...");
    await voteWithPermit(fractionalDao, tezos.alice, lambda);
    $log.info("Alice voted");

    const storage2 = await fractionalDao.storage<DaoStorage>();
    expect(storage2.voting_period.toNumber()).toBe(600);
  });

  test("DAO transfer ownership tokens", async () => {
    $log.info("Bob transfers ownership tokens to Alice");
    const bobAddress = await tezos.bob.signer.publicKeyHash();
    const aliceAddress = await tezos.alice.signer.publicKeyHash();
    await transfer(fractionalDao.address, tezos.bob, [
      {
        from_: bobAddress,
        txs: [
          {
            to_: aliceAddress,
            token_id: new BigNumber(0),
            amount: new BigNumber(25),
          },
        ],
      },
    ]);
    $log.info("Transferred Bob's ownership tokens");

    const storage0 = await fractionalDao.storage<DaoStorage>();
    const lambda = await setDaoVotingThresholdLambda(
      ligoEnv,
      storage0.voting_threshold.toNumber(),
      50
    );
    $log.info("Alice voting");
    await voteWithPermit(fractionalDao, tezos.alice, lambda);
    $log.info("Alice voted");

    const storage1 = await fractionalDao.storage<DaoStorage>();
    expect(storage1.voting_threshold.toNumber()).toBe(50);
  });
});
