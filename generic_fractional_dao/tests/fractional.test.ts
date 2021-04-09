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

import { DaoStorage, setDaoVotingThresholdParam } from "../src/lambdas";

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

  test("Set DAO voting threshold", async () => {
    const { voting_threshold } = await fractionalDao.storage<DaoStorage>();
    const lambda = await setDaoVotingThresholdParam(
      ligoEnv,
      voting_threshold.toNumber(),
      50
    );
    $log.info("LAMBDA", lambda);
  });
});
