from pathlib import Path
from decimal import *
from unittest import TestCase
import json

from pytezos import Key, MichelsonRuntimeError, pytezos

from tezos_fa2_nft_tests.ligo import (
    LigoEnv,
    PtzUtils,
    flextesa_sandbox,
)


root_dir = Path(__file__).parent.parent / "ligo"
ligo_env = LigoEnv(root_dir / "src", root_dir / "out")
ligo_client_env = LigoEnv(root_dir / "fa2_clients", root_dir / "out")


def balance_response(owner, token_id, balance):
    return {
        "balance": balance,
        "request": {
            "owner": owner,
            "token_id": token_id,
        },
    }


class TestFa2SetUp(TestCase):
    def setUp(self):
        self.util = PtzUtils(flextesa_sandbox)
        # self.util = PtzUtils(pytezos)

        self.admin_key = self.util.client.key

        self.orig_contracts()

        self.mike_key = Key.generate(export=False)
        self.kyle_key = Key.generate(export=False)

        # self.transfer_init_funds()
        print("test setup completed")

    def orig_contracts(self):
        print("loading ligo contracts...")
        ligo_fa2 = ligo_env.contract_from_file("fa2_nft_asset.mligo", "nft_asset_main")
        ligo_receiver = ligo_client_env.contract_from_file(
            "token_owner.mligo", "token_owner_main"
        )

        print("originating contracts...")
        self.fa2 = self.orig_fa2(ligo_fa2)
        print(f"FA2 address {self.fa2.address}")

        self.alice_receiver = self.orig_receiver(ligo_receiver)
        print(f"Alice address {self.alice_receiver.address}")
        self.bob_receiver = self.orig_receiver(ligo_receiver)
        print(f"Bob address {self.bob_receiver.address}")

    def orig_fa2(self, ligo_fa2):
        meta = {
            "interfaces": ["TZIP-012"],
            "name": "FA2 Non-Fungible Tokens",
            "homepage": "https://github.com/tqtezos/smart-contracts",
            "license": {"name": "MIT"},
        }
        meta_content = json.dumps(meta, indent=2).encode().hex()
        meta_uri = str.encode("tezos-storage:content").hex()

        ligo_storage = """
        {
            admin = {
              admin = ("%s" : address);
              pending_admin = (None : address option);
              paused = true;
            };
            assets = {
                ledger = (Big_map.empty : (token_id, address) big_map);
                operators = (Big_map.empty : operator_storage);
                metadata = {
                  token_defs = (Set.empty : token_def set);
                  next_token_id = 0n;
                  metadata = (Big_map.empty : (token_def, token_metadata) big_map);
                };
            };
             metadata = Big_map.literal [
              ("", 0x%s);
              ("content", 0x%s)
            ];
        } 
        """ % (
            self.admin_key.public_key_hash(),
            meta_uri,
            meta_content,
        )

        ptz_storage = ligo_fa2.compile_storage(ligo_storage)
        return ligo_fa2.originate(self.util, ptz_storage)

    def orig_receiver(self, ligo_receiver):
        return ligo_receiver.originate(self.util, balance=100000000)

    def transfer_init_funds(self):
        self.util.transfer(self.mike_key.public_key_hash(), 100000000)
        self.util.transfer(self.kyle_key.public_key_hash(), 100000000)

    def pause_fa2(self, paused: bool):
        self.fa2.pause(paused).send(min_confirmations=1)

    def assertBalances(self, expectedResponses, msg=None):
        requests = [response["request"] for response in expectedResponses]
        responses = self.fa2.balance_of(requests=requests, callback=None).view()
        print('balances:')
        print(responses)
        self.assertListEqual(expectedResponses, responses, msg)

    def assertBalance(self, owner, token_id, expected_balance, msg=None):
        self.assertBalances([balance_response(owner, token_id, expected_balance)])

    def mint_tokens(self, owner1_address, owner2_address):
        token_metadata = {
            # because of an issue with pytezos, the keys must be sorted alphabetically
            "token_id": 0,
            "token_info": {
                "0": "left".encode().hex(),
                "1": "right".encode().hex(),
                "decimals": "0".encode().hex(),
                "name": "socks token".encode().hex(),
                "symbol": "SOCK".encode().hex(),
            },
        }
        self.fa2.mint_tokens(
            {
                "metadata": token_metadata,
                "token_def": {
                    "from_": 0,
                    "to_": 2,
                },
                "owners": [owner1_address, owner2_address],
            }
        ).send(min_confirmations=1)


class TestMintBurn(TestFa2SetUp):
    def setUp(self):
        super().setUp()
        print("unpausing")
        self.pause_fa2(False)

    def test_mint_burn_to_receiver(self):
        self.mint_burn(self.alice_receiver.address, self.bob_receiver.address)

    def test_mint_burn_implicit(self):
        self.mint_burn(self.mike_key.public_key_hash(), self.kyle_key.public_key_hash())

    def mint_burn(self, owner1_address, owner2_address):
        print("minting")
        self.mint_tokens(owner1_address, owner2_address)

        self.assertBalances(
            [
                balance_response(owner1_address, 0, 1),
                balance_response(owner1_address, 1, 0),
                balance_response(owner2_address, 1, 1),
            ],
            "invalid mint balances",
        )

        print("burning")
        self.fa2.burn_tokens(from_=0, to_=2).send(min_confirmations=1)

        with self.assertRaises(MichelsonRuntimeError) as cm:
            self.fa2.balance_of(
                requests=[{"owner": owner1_address, "token_id": 0}],
                callback=None
            ).view()

        failed_with = PtzUtils.extract_runtime_failwith(cm.exception)
        self.assertEqual("FA2_TOKEN_UNDEFINED", failed_with)


class TestOperator(TestFa2SetUp):
    def setUp(self):
        super().setUp()
        self.pause_fa2(False)

    def test_add_operator_to_receiver(self):

        print("adding operator")
        self.alice_receiver.owner_add_operator(
            fa2=self.fa2.address, operator=self.admin_key.public_key_hash(), token_id=0
        ).send(min_confirmations=1)

class TestTransfer(TestFa2SetUp):
    def setUp(self):
        super().setUp()
        self.pause_fa2(False)

        self.alice_receiver.owner_add_operator(
            fa2=self.fa2.address, operator=self.admin_key.public_key_hash(), token_id=0
        ).send(min_confirmations=1)

        self.bob_receiver.owner_add_operator(
            fa2=self.fa2.address, operator=self.admin_key.public_key_hash(), token_id=1
        ).send(min_confirmations=1)
        print("transfer test setup completed")

    def test_transfer(self):

        alice_a = self.alice_receiver.address
        bob_a = self.bob_receiver.address
        mike_a = self.mike_key.public_key_hash()
        left_sock = 0
        right_sock = 1

        self.mint_tokens(alice_a, bob_a)

        self.assertBalances(
            [
                balance_response(alice_a, left_sock, 1),
                balance_response(bob_a, right_sock, 1),
                balance_response(mike_a, left_sock, 0),
                balance_response(mike_a, right_sock, 0),
            ],
            "invalid mint balance",
        )

        print("transferring")
        self.fa2.transfer(
            [
                {
                    "from_": alice_a,
                    "txs": [{"to_": mike_a, "token_id": left_sock, "amount": 1}],
                },
                {
                    "from_": bob_a,
                    "txs": [{"to_": mike_a, "token_id": right_sock, "amount": 1}],
                },
            ]
        ).send(min_confirmations=1)

        self.assertBalances(
            [
                balance_response(alice_a, left_sock, 0),
                balance_response(bob_a, right_sock, 0),
                balance_response(mike_a, left_sock, 1),
                balance_response(mike_a, right_sock, 1),
            ],
            "invalid mint balance",
        )
