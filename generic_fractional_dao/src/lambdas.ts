import * as _ from "lodash";
import { TezosToolkit } from "@taquito/taquito";
import { MichelsonV1Expression } from "@taquito/rpc";
import {
  Expr,
  MichelsonData,
  MichelsonType,
  packData,
  Parser,
} from "@taquito/michel-codec";
import { address, Contract, nat } from "smart-contracts-common/type-aliases";
import { compileExpression, LigoEnv } from "smart-contracts-common/ligo";
import { $log } from "@tsed/logger";

export interface DaoStorage {
  voting_threshold: nat;
  voting_period: nat;
  vote_count: nat;
}

export const setDaoVotingThresholdParam = async (
  env: LigoEnv,
  oldThreshold: number,
  newThreshold: number
) => {
  const lambdaMichelson = await compileExpression(
    env,
    "fractional_dao_lambdas.mligo",
    `set_dao_voting_threshold (${oldThreshold}n, ${newThreshold}n)`
  );
  const p = new Parser();
  const lambdaExp = p.parseMichelineExpression(lambdaMichelson);
  if (!lambdaExp)
    throw new Error(`Cannot parse lambda Michelson \n${lambdaMichelson}`);
  return { lambdaExp, lambdaMichelson };
};

export const signPermit = async (
  signer: TezosToolkit,
  dao: Contract,
  lambda: string
) => {
  const chainId = await signer.rpc.getChainId();
  const { vote_count } = await dao.storage<DaoStorage>();
  /*
  Bytes.pack (
    (Tezos.chain_id, Tezos.self_address),
    (vote_count, lambda)
  )
  */

  const michData = `
  (Pair
    (Pair
      "${chainId}"
      "${dao.address}"
    )
    (Pair
      ${vote_count}
      ${lambda}
    )
  )
  `;

  const michType = `
  (pair
    (pair chain_id address)
    (pair nat (lambda unit (list operation)))
  )
  `;

  const p = new Parser();
  const dat = p.parseMichelineExpression(michData);
  const typ = p.parseMichelineExpression(michType);
  // const pack = packData(dat as MichelsonData, typ as MichelsonType);
  const pack = await signer.rpc.packData({
    data: dat as MichelsonV1Expression,
    type: typ as MichelsonV1Expression,
  });
  const signature = await signer.signer.sign(pack.packed);
  return signature;
};
