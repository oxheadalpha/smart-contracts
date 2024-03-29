from pathlib import Path
from decimal import *
from unittest import TestCase
import json

from pytezos import Key, pytezos

from tezos_fa2_single_tests.ligo import (
    LigoEnv,
    LigoContract,
    PtzUtils,
    flextesa_sandbox,
    token_metadata_literal,
)


root_dir = Path(__file__).parent.parent / "ligo"
ligo_env = LigoEnv(root_dir / "src", root_dir / "out")
ligo_client_env = LigoEnv(root_dir / "fa2_clients", root_dir / "out")


def balance_response(owner, balance):
    return {
        "balance": balance,
        "request": {
            "owner": owner,
            "token_id": 0,
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
        ligo_fa2 = ligo_env.contract_from_file(
            "fa2_single_asset.mligo", "SingleAsset"
        )
        ligo_receiver = ligo_client_env.contract_from_file(
            "token_owner.mligo", "TokenOwner"
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
            "name": "Single Asset FA2 Fungible Token",
            "homepage": "https://github.com/tqtezos/smart-contracts",
            "license": {"name": "MIT"},
        }
        meta_content = json.dumps(meta, indent=2).encode().hex()
        meta_uri = str.encode("tezos-storage:content").hex()

        token_id = 0
        token_meta = token_metadata_literal(token_id, "TK1", "Test Token", 0)

        ligo_storage = """
        {
            admin = {
              admin = ("%s" : address);
              pending_admin = (None : address option);
              paused = true;
            };
            assets = {
                ledger = (Big_map.empty : (address, nat) big_map);
                operators = (Big_map.empty : operator_storage);
                token_metadata = Big_map.literal [
                 (%sn, %s);
                ];
                total_supply = 0n;
            };
            metadata = Big_map.literal [
              ("", 0x%s);
              ("content", 0x%s)
            ];
        }
        """ % (
            self.admin_key.public_key_hash(),
            token_id,
            token_meta,
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

    def assertBalance(self, owner, expected_balance, msg=None):
        self.assertBalances([balance_response(owner, expected_balance)])


class TestMintBurn(TestFa2SetUp):
    def setUp(self):
        super().setUp()
        print("unpausing")
        self.pause_fa2(False)

    def test_mint_burn_to_receiver(self):
        self.mint_burn(self.alice_receiver.address)

    def test_mint_burn_implicit(self):
        self.mint_burn(self.mike_key.public_key_hash())

    def mint_burn(self, owner_address):
        print("minting")
        self.fa2.mint_tokens(
            [{"amount": 10, "owner": owner_address}]
        ).send(min_confirmations=1)
        self.assertBalance(owner_address, 10, "invalid mint balance")

        print("burning")
        self.fa2.burn_tokens(
            [{"amount": 3, "owner": owner_address}]
        ).send(min_confirmations=1)

        self.assertBalance(owner_address, 7, "invalid balance after burn")


class TestOperator(TestFa2SetUp):
    def setUp(self):
        super().setUp()
        self.pause_fa2(False)

    def test_add_operator_to_receiver(self):

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
        print("transfer test setup completed")

    def test_transfer_to_receiver(self):
        self.transfer(self.alice_receiver.address, self.bob_receiver.address)

    def test_transfer_to_implicit(self):
        self.transfer(self.alice_receiver.address, self.mike_key.public_key_hash())

    def transfer(self, from_address, to_address):

        self.fa2.mint_tokens(
            [{"amount": 10, "owner": from_address}]
        ).send(min_confirmations=1)

        print("transferring")
        self.fa2.transfer(
            [
                {
                    "from_": from_address,
                    "txs": [{"to_": to_address, "token_id": 0, "amount": 3}],
                },
            ]
        ).send(min_confirmations=1)

        self.assertBalances(
            [
                balance_response(to_address, 3),
                balance_response(from_address, 7),
            ]
        )
