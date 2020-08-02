import { $log } from '@tsed/logger';

import { TezosToolkit } from '@taquito/taquito';
import { address, Contract, nat } from 'smart-contracts-common/type-aliases';

export async function stopPromotion(
  tz: TezosToolkit,
  promotionAddress: address
): Promise<void> {
  $log.info('stopping promotion.');
  const promotion = await tz.contract.at(promotionAddress);
  const op = await promotion.methods.stop_promotion(undefined).send();
  await op.confirmation();
  $log.info(`promotion stopped. Consumed gas: ${op.consumedGas}`);
}

export async function refundMoney(
  tz: TezosToolkit,
  promotionAddress: address
): Promise<void> {
  $log.info('refunding money');
  const promotion = await tz.contract.at(promotionAddress);
  const op = await promotion.methods.refund_money(undefined).send();
  await op.confirmation();
  $log.info(`refunded money. Consumed gas: ${op.consumedGas}`);
}

export async function disburseCollectibles(
  tz: TezosToolkit,
  promotionAddress: address
): Promise<void> {
  $log.info('disbursing collectibles');
  const promotion = await tz.contract.at(promotionAddress);
  const op = await promotion.methods.disburse_collectibles(undefined).send();
  await op.confirmation();
  $log.info(`disbursed collectibles. Consumed gas: ${op.consumedGas}`);
}
