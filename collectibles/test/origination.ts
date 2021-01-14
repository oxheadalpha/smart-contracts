import { $log } from '@tsed/logger';

import { TezosToolkit } from '@taquito/taquito';
import { char2Bytes } from '@taquito/tzip16';
import { address, Contract, nat } from 'smart-contracts-common/type-aliases';
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

  const meta_uri = char2Bytes('tezos-storage:content');
  const meta = {
    interfaces: ['TZIP-12'],
    name: 'Rainbow Token',
    description: 'NFT collection of rainbow tokens',
    homepage: 'https://github.com/tqtezos/smart-contracts',
    license: { name: 'MIT' }
  };
  const meta_content = char2Bytes(JSON.stringify(meta, null, 2));

  const rainbow_storage = `
  (Pair (Pair (Pair (Pair "${owner}" False) None)
            (Pair (Pair { Elt 0 "${owner}" ;
                          Elt 1 "${owner}" ;
                          Elt 2 "${owner}" ;
                          Elt 3 "${owner}" ;
                          Elt 4 "${owner}" ;
                          Elt 5 "${owner}" ;
                          Elt 6 "${owner}" }
                        {})
                  (Pair (Pair (Right (Right Unit)) (Pair (Right (Left Unit)) (Pair (Left Unit) None)))
                        { Elt 0 (Pair 0 (Pair "RED" (Pair "RAINBOW_TOKEN" (Pair 0 {})))) ;
                          Elt 1 (Pair 1 (Pair "ORANGE" (Pair "RAINBOW_TOKEN" (Pair 0 {})))) ;
                          Elt 2 (Pair 2 (Pair "YELLOW" (Pair "RAINBOW_TOKEN" (Pair 0 {})))) ;
                          Elt 3 (Pair 3 (Pair "GREEN" (Pair "RAINBOW_TOKEN" (Pair 0 {})))) ;
                          Elt 4 (Pair 4 (Pair "BLUE" (Pair "RAINBOW_TOKEN" (Pair 0 {})))) ;
                          Elt 5 (Pair 5 (Pair "INDIGO" (Pair "RAINBOW_TOKEN" (Pair 0 {})))) ;
                          Elt 6 (Pair 6 (Pair "VIOLET" (Pair "RAINBOW_TOKEN" (Pair 0 {})))) })))
      { Elt "" 0x${meta_uri} ; Elt "content" 0x${meta_content} })
  `;
  return originateContract(tz, code, rainbow_storage, 'collection');
}

export async function originateMoney(
  env: LigoEnv,
  tz: TezosToolkit
): Promise<Contract> {
  const code = await compileAndLoadContract(
    env,
    'fa2_single_asset_with_hooks.mligo',
    'single_asset_main',
    'fa2_single_asset_with_hooks.tz'
  );
  const owner = await tz.signer.publicKeyHash();

  const meta_uri = char2Bytes('tezos-storage:content');
  const meta = {
    interfaces: ['TZIP-12'],
    name: 'FA2 Single Fungible (Money) Token',
    homepage: 'https://github.com/tqtezos/smart-contracts',
    license: { name: 'MIT' }
  };
  const meta_content = char2Bytes(JSON.stringify(meta, null, 2));

  const storage = `(Pair (Pair (Pair (Pair "${owner}" False) None)
        (Pair (Pair (Pair {} {})
                    (Pair (Pair (Right (Right Unit)) (Pair (Right (Left Unit)) (Pair (Right (Left Unit)) None)))
                          { Elt 0 (Pair 0 (Pair "TK1" (Pair "Test Token" (Pair 0 {})))) }))
              0))
  { Elt "" 0x${meta_uri} ;
    Elt "content" 0x${meta_content} })`;

  return originateContract(tz, code, storage, 'money');
}

interface GlobalTokenId {
  fa2: address;
  id: nat;
}

interface PromotionDef {
  promoter: address;
  money_token: GlobalTokenId;
  collectible_fa2: address;
  price: nat;
}

export async function originatePromo(
  env: LigoEnv,
  tz: TezosToolkit,
  promotion: PromotionDef
): Promise<Contract> {
  const code = await compileAndLoadContract(
    env,
    'collectibles_promo.mligo',
    'main',
    'collectibles_promo.tz'
  );
  const owner = await tz.signer.publicKeyHash();
  const storage = `(Right
    (Pair (Pair "${promotion.collectible_fa2}"
                (Pair "${promotion.money_token.fa2}" ${promotion.money_token.id}))
          (Pair ${promotion.price} "${owner}")))`;

  return originateContract(tz, code, storage, 'promo');
}
