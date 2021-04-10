import * as child from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import { $log } from '@tsed/logger';

import { TezosToolkit } from '@taquito/taquito';
import { char2Bytes } from '@taquito/tzip16';
import { Contract } from './type-aliases';

const ligoVersion = '0.12.0';
const ligoCmd = `docker run --rm -v "$PWD":"$PWD" -w "$PWD" ligolang/ligo:${ligoVersion} "$@"`;

export class LigoEnv {
  readonly cwd: string;
  readonly srcDir: string;
  readonly outDir: string;

  constructor(cwd: string, srcDir: string, outDir: string) {
    this.cwd = cwd;
    this.srcDir = srcDir;
    this.outDir = outDir;
  }

  srcFilePath(srcFileName: string): string {
    return path.join(this.srcDir, srcFileName);
  }

  outFilePath(outFileName: string): string {
    return path.join(this.outDir, outFileName);
  }
}

export function defaultLigoEnv(cwd: string, ligoDir: string = 'ligo'): LigoEnv {
  const src = path.join(ligoDir, 'src');
  const out = path.join(ligoDir, 'out');
  return new LigoEnv(path.resolve(cwd), path.resolve(src), path.resolve(out));
}

export async function compileAndLoadContract(
  env: LigoEnv,
  srcFile: string,
  main: string,
  dstFile: string
): Promise<string> {
  const src = env.srcFilePath(srcFile);
  const out = env.outFilePath(dstFile);
  await compileContract(env.cwd, src, main, out);

  return new Promise<string>((resolve, reject) =>
    fs.readFile(out, (err, buff) =>
      err ? reject(err) : resolve(buff.toString())
    )
  );
}

async function compileContract(
  cwd: string,
  srcFilePath: string,
  main: string,
  dstFilePath: string
): Promise<void> {
  const cmd = `${ligoCmd} compile-contract ${srcFilePath} ${main} --output=${dstFilePath}`;
  await runCmd(cwd, cmd);
}

export async function compileExpression(
  env: LigoEnv,
  srcFile: string,
  expression: string
): Promise<string> {
  const srcFilePath = env.srcFilePath(srcFile);
  const cmd = `${ligoCmd} compile-expression --init-file=${srcFilePath} 'cameligo' '${expression}'`;
  return runCmd(env.cwd, cmd);
}

async function runCmd(cwd: string, cmd: string): Promise<string> {
  return new Promise<string>((resolve, reject) =>
    child.exec(cmd, { cwd }, (err, stdout, errout) => {
      if (stdout && (errout || err)) {
        $log.info(stdout);
      }
      if (errout) {
        $log.error(errout);
      }
      if (err) {
        reject(err);
      } else {
        resolve(stdout);
      }
    })
  );
}

export async function originateContract(
  tz: TezosToolkit,
  code: string,
  storage: any,
  name: string
): Promise<Contract> {
  try {
    const originationOp = await tz.contract.originate({
      code,
      init: storage
    });

    const contract = await originationOp.contract();
    $log.info(`originated contract ${name} with address ${contract.address}`);
    $log.info(`consumed gas: ${originationOp.consumedGas}`);
    return Promise.resolve(contract);
  } catch (error) {
    const jsonError = JSON.stringify(error, null, 2);
    $log.fatal(`${name} origination error ${jsonError}`);
    return Promise.reject(error);
  }
}

export function token_meta_literal(
  symbol: string,
  name: string,
  decimals: number = 0
): string {
  return `{
    Elt "decimals" 0x${char2Bytes(decimals.toString())};
    Elt "name" 0x${char2Bytes(name)};
    Elt "symbol" 0x${char2Bytes(symbol)};
  }`;
}
