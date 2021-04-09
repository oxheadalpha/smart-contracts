import * as _ from "lodash";
import { TezosToolkit } from "@taquito/taquito";
import { Parser } from "@taquito/michel-codec";
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
  return p.parseMichelineExpression(lambdaMichelson);
};
