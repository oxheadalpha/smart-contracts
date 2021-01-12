import * as path from 'path';
import { $log } from '@tsed/logger';

import { address, Contract } from './type-aliases';
import { BalanceOfRequest, BalanceOfResponse } from './fa2-interface';

export const queryBalances = async (
  fa2: Contract,
  requests: BalanceOfRequest[],
  lambdaView?: address
): Promise<BalanceOfResponse[]> =>
  fa2.views.balance_of(requests).read(lambdaView);

export async function hasNftTokens(
  nft: Contract,
  requests: BalanceOfRequest[],
  lambdaView?: address
): Promise<boolean[]> {
  const responses = await queryBalances(nft, requests, lambdaView);
  const results = responses.map(r => {
    if (r.balance.eq(1)) return true;
    else if (r.balance.eq(0)) return false;
    else throw new Error(`Invalid NFT balance ${r.balance}`);
  });
  return results;
}
