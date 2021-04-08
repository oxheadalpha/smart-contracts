import { $log } from "@tsed/logger";
import { BigNumber } from "bignumber.js";
import { TezosToolkit } from "@taquito/taquito";

import { bootstrap, TestTz } from "smart-contracts-common/bootstrap-sandbox";
import { Contract, address, nat } from "smart-contracts-common/type-aliases";
import { defaultLigoEnv } from "smart-contracts-common/ligo";

import {
  originateNftCollection,
  // originateFractionalDao,
} from "../src/origination";

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
    // fractionalDao = await originateFractionalDao(ligoEnv, tezos.bob);
  });

  test("Hello", () => {});
});
