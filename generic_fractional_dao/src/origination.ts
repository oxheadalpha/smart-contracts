import * as _ from "lodash";
import { TezosToolkit } from "@taquito/taquito";
import { char2Bytes } from "@taquito/tzip16";
import { address, Contract, nat } from "smart-contracts-common/type-aliases";
import {
  compileAndLoadContract,
  originateContract,
  LigoEnv,
  token_meta_literal,
} from "smart-contracts-common/ligo";
import { $log } from "@tsed/logger";

export async function originateNftCollection(
  env: LigoEnv,
  tz: TezosToolkit
): Promise<Contract> {
  const code = await compileAndLoadContract(
    env,
    "fa2_fixed_collection_asset.mligo",
    "collection_asset_main",
    "fa2_fixed_collection_asset.tz"
  );
  const owner = await tz.signer.publicKeyHash();

  const meta_uri = char2Bytes("tezos-storage:content");
  const meta = {
    interfaces: ["TZIP-012"],
    name: "Rainbow Token",
    description: "NFT collection of rainbow tokens",
    homepage: "https://github.com/tqtezos/smart-contracts",
    license: { name: "MIT" },
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
                        { Elt 0 (Pair 0 ${token_meta_literal(
                          "RED",
                          "RAINBOW_TOKEN"
                        )}) ;
                        Elt 1 (Pair 1 ${token_meta_literal(
                          "ORANGE",
                          "RAINBOW_TOKEN"
                        )}) ;
                        Elt 2 (Pair 2 ${token_meta_literal(
                          "YELLOW",
                          "RAINBOW_TOKEN"
                        )}) ;
                        Elt 3 (Pair 3 ${token_meta_literal(
                          "GREEN",
                          "RAINBOW_TOKEN"
                        )}) ;
                        Elt 4 (Pair 4 ${token_meta_literal(
                          "BLUE",
                          "RAINBOW_TOKEN"
                        )}) ;
                        Elt 5 (Pair 5 ${token_meta_literal(
                          "INDIGO",
                          "RAINBOW_TOKEN"
                        )}) ;
                        Elt 6 (Pair 6 ${token_meta_literal(
                          "VIOLET",
                          "RAINBOW_TOKEN"
                        )}) 
                        })))
      { Elt "" 0x${meta_uri} ; Elt "content" 0x${meta_content} })
  `;
  return originateContract(tz, code, rainbow_storage, "NFT collection");
}

export async function originateFractionalDao(
  env: LigoEnv,
  tz: TezosToolkit,
  owner1: address,
  owner2: address
): Promise<Contract> {
  const code = await compileAndLoadContract(
    env,
    "fractional_dao.mligo",
    "main",
    "fractional_dao.tz"
  );
  const admin = await tz.signer.publicKeyHash();

  const meta_uri = char2Bytes("tezos-storage:content");
  const meta = {
    interfaces: ["TZIP-012"],
    name: "Generic Fractional DAO",
    description:
      "DAO that manages fractional ownership of a generic FA2 NFT tokens and other operations",
    homepage: "https://github.com/tqtezos/smart-contracts",
    license: { name: "MIT" },
  };
  const meta_content = char2Bytes(JSON.stringify(meta, null, 2));

  const owner1_share = 50;
  const owner2_share = 50;
  const total_supply = owner1_share + owner2_share;
  const voting_threshold = 75;
  const voting_period = 10000000;

  const ledger = generateMapLiteral([
    { key: `"${owner1}"`, value: owner1_share.toString() },
    { key: `"${owner2}"`, value: owner2_share.toString() },
  ]);

  const storage = `
  (Pair (Pair (Pair { Elt "" 0x${meta_uri} ;
                    Elt "content" 0x${meta_content} }
                  (Pair ${ledger}
                        {})
                  { Elt 0
                        (Pair 0
                              { Elt "decimals" 0x30 ;
                                Elt "name" 0x5465737420546f6b656e ;
                                Elt "symbol" 0x544b31 }) }
                  ${total_supply})
            {}
            0)
      ${voting_period}
      ${voting_threshold})
  `;
  return originateContract(tz, code, storage, "fractional DAO");
}

const generateMapLiteral = (
  elements: { key: string; value: string }[]
): string => {
  const elts = _.chain(elements)
    .sortBy((e) => e.key)
    .map((e) => `Elt ${e.key} ${e.value}`)
    .join(" ; ");
  return `{ ${elts} }`;
};
