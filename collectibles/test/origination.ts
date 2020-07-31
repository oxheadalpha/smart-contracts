import { $log } from '@tsed/logger';

import { TezosToolkit } from '@taquito/taquito';
import { address, Contract } from 'smart-contracts-common/type-aliases';
import {
  compileAndLoadContract,
  originateContract,
  LigoEnv
} from 'smart-contracts-common/ligo';

export async function originateCollection(
  env: LigoEnv,
  tz: TezosToolkit
): Promise<Contract> {
  const code = await compileAndLoadContract(
    env,
    'fa2_fixed_collection_asset.mligo',
    'collection_asset_main',
    'fa2_fixed_collection_asset.tz'
  );
  const owner = await tz.signer.publicKeyHash();

  const rainbow_storage = `(Pair (Pair (Pair "${owner}" True) None)
  (Pair (Pair { Elt 0 "${owner}" ;
                Elt 1 "${owner}" ;
                Elt 2 "${owner}" ;
                Elt 3 "${owner}" ;
                Elt 4 "${owner}" ;
                Elt 5 "${owner}" ;
                Elt 6 "${owner}" }
              {})
        (Pair (Pair (Pair None (Left (Right Unit))) (Pair (Left (Left Unit)) (Left (Left Unit))))
              { Elt 0 (Pair 0 (Pair "RED" (Pair "RAINBOW_TOKEN" (Pair 0 {})))) ;
                Elt 1 (Pair 1 (Pair "ORANGE" (Pair "RAINBOW_TOKEN" (Pair 0 {})))) ;
                Elt 2 (Pair 2 (Pair "YELLOW" (Pair "RAINBOW_TOKEN" (Pair 0 {})))) ;
                Elt 3 (Pair 3 (Pair "GREEN" (Pair "RAINBOW_TOKEN" (Pair 0 {})))) ;
                Elt 4 (Pair 4 (Pair "BLUE" (Pair "RAINBOW_TOKEN" (Pair 0 {})))) ;
                Elt 5 (Pair 5 (Pair "INDIGO" (Pair "RAINBOW_TOKEN" (Pair 0 {})))) ;
                Elt 6 (Pair 6 (Pair "VIOLET" (Pair "RAINBOW_TOKEN" (Pair 0 {})))) })))`;
  return originateContract(tz, code, rainbow_storage, 'collection');
}
