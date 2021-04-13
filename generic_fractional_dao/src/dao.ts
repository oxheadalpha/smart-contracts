import * as _ from "lodash";
import { TezosToolkit } from "@taquito/taquito";
import {
  Expr,
  isMichelsonData,
  isMichelsonType,
  MichelsonData,
  MichelsonType,
  packDataBytes,
  Parser,
} from "@taquito/michel-codec";
import { address, Contract, nat } from "smart-contracts-common/type-aliases";
import { compileExpression, LigoEnv } from "smart-contracts-common/ligo";
import { $log } from "@tsed/logger";
import {
  Fa2Transfer,
  Fa2TransferDestination,
  isAddOperator,
  isRemoveOperator,
  OperatorParam,
  UpdateOperator,
} from "smart-contracts-common/fa2-interface";

export interface DaoStorage {
  voting_threshold: nat;
  voting_period: nat;
  vote_count: nat;
}

export type DaoLambda = { lambdaMichelson: string; lambdaExp: Expr };

export const voteWithPermit = async (
  dao: Contract,
  voter: TezosToolkit,
  lambda: DaoLambda
) => {
  // const signature = await signPermitV2(voter, dao, lambda.lambdaExp);
  const signature = await signPermit(voter, dao, lambda.lambdaMichelson);
  const voterKey = await voter.signer.publicKey();
  const op = await dao.methods
    .vote(lambda.lambdaExp, voterKey, signature)
    .send();
  await op.confirmation();
  $log.info(`Consumed gas ${op.consumedGas}`);
};

export const vote = async (dao: Contract, lambda: DaoLambda) => {
  const op = await dao.methods.vote(lambda.lambdaExp).send();
  await op.confirmation();
  $log.info(`Consumed gas ${op.consumedGas}`);
};

export const setDaoVotingThresholdLambda = async (
  env: LigoEnv,
  oldThreshold: number,
  newThreshold: number
): Promise<DaoLambda> => {
  const lambdaMichelson = await compileExpression(
    env,
    "fractional_dao_lambdas.mligo",
    `set_dao_voting_threshold (${oldThreshold}n, ${newThreshold}n)`
  );
  return michelsonToDaoLambda(lambdaMichelson);
};

export const setDaoVotingPeriodLambda = async (
  env: LigoEnv,
  oldPeriod: number,
  newPeriod: number
): Promise<DaoLambda> => {
  const lambdaMichelson = await compileExpression(
    env,
    "fractional_dao_lambdas.mligo",
    `set_dao_voting_period (${oldPeriod}n, ${newPeriod}n)`
  );
  return michelsonToDaoLambda(lambdaMichelson);
};

export const transferFA2TokensLambda = async (
  env: LigoEnv,
  fa2: address,
  txs: Fa2Transfer[]
): Promise<DaoLambda> => {
  // prettier-ignore
  const destinations = (txs: Fa2TransferDestination[]): string =>
    _.chain(txs)
    .map((t) =>
      `{ to_ = ("${t.to_}" : address); token_id=${t.token_id.toNumber()}n; amount=${t.amount.toNumber()}n; }`
    )
    .join(", ")
    .value();
  //prettier-ignore
  const txsArg = 
    _.chain(txs)
    .map((t) =>
      `{from_ = ("${t.from_}" : address); txs=[${destinations(t.txs)}];}\n`
    )
    .join(", ")
    .value();
  const lambdaMichelson = await compileExpression(
    env,
    "fractional_dao_lambdas.mligo",
    `dao_transfer_fa2_tokens (("${fa2}": address), [${txsArg}])`
  );
  return michelsonToDaoLambda(lambdaMichelson);
};

export const updateOperatorsLambda = async (
  env: LigoEnv,
  fa2: address,
  operators: UpdateOperator[]
) => {
  //prettier-ignore
  const formatOperatorParam = (op: OperatorParam): string =>
    `{ owner = ("${op.owner}" : address); operator = ("${op.operator}" : address); token_id = ${op.token_id.toNumber()}n; }`

  const ops = _.chain(operators)
    .map((o) => {
      if (isAddOperator(o))
        return `Add_operator ${formatOperatorParam(o.add_operator)}`;
      if (isRemoveOperator(o))
        return `Remove_operator ${formatOperatorParam(o.remove_operator)}`;
      throw new Error("Unknown UpdateOperator variant");
    })
    .join(" ; ");

  const lambdaMichelson = await compileExpression(
    env,
    "fractional_dao_lambdas.mligo",
    `dao_update_fa2_operators (("${fa2}": address), [${ops}])`
  );
  return michelsonToDaoLambda(lambdaMichelson);
};

const michelsonToDaoLambda = (lambdaMichelson: string): DaoLambda => {
  const p = new Parser();
  const lambdaExp = p.parseMichelineExpression(lambdaMichelson);
  if (!lambdaExp)
    throw new Error(`Cannot parse lambda Michelson \n${lambdaMichelson}`);
  return { lambdaExp, lambdaMichelson };
};

const signPermit = async (
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
  const data = p.parseMichelineExpression(michData);
  const dataType = p.parseMichelineExpression(michType);
  if (data === null || !isMichelsonData(data))
    throw new Error("Invalid parsed Michelson data");
  if (dataType === null || !isMichelsonType(dataType))
    throw new Error("Invalid parsed Michelson type");
  const pack = packDataBytes(data, dataType);
  const signature = await signer.signer.sign(pack.bytes);
  return signature.sig;
};

const signPermitV2 = async (
  signer: TezosToolkit,
  dao: Contract,
  lambda: Expr
) => {
  const chainId = await signer.rpc.getChainId();
  const { vote_count } = await dao.storage<DaoStorage>();
  /*
  Bytes.pack (
    (Tezos.chain_id, Tezos.self_address),
    (vote_count, lambda)
  )
  */
  const lambdaType: MichelsonType = {
    prim: "lambda",
    args: [{ prim: "unit" }, { prim: "list", args: [{ prim: "operation" }] }],
  };
  if (!isMichelsonData(lambda)) throw new Error("Malformed lambda data");

  const countLambdaType: MichelsonType = {
    prim: "pair",
    args: [{ prim: "nat" }, lambdaType],
  };
  const countLambdaData: MichelsonData = {
    prim: "Pair",
    args: [{ int: vote_count.toString() }, lambda],
  };

  const chainAddressType: MichelsonType = {
    prim: "pair",
    args: [{ prim: "chain_id" }, { prim: "address" }],
  };

  const chainAddressData: MichelsonData = {
    prim: "Pair",
    args: [{ string: chainId }, { string: dao.address }],
  };

  const data: MichelsonData = {
    prim: "Pair",
    args: [chainAddressData, countLambdaData],
  };

  const dataType: MichelsonType = {
    prim: "pair",
    args: [chainAddressType, countLambdaType],
  };

  const pack = packDataBytes(data, dataType);
  const signature = await signer.signer.sign(pack.bytes);
  return signature.sig;
};
