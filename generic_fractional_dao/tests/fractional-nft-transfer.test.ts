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

import { DaoStorage, vote, voteWithPermit } from "../src/dao";

import BigNumber from "bignumber.js";

jest.setTimeout(240000);

const ligoEnv = defaultLigoEnv("../../", "ligo");

describe("fractional ownership admin entry points test", () => {
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
        txs: [{ to_, token_id, amount: new BigNumber(1) }],
      },
    ]);
  }
});
