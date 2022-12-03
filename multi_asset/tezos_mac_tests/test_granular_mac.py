from pathlib import Path
from unittest import TestCase
import json

from pytezos import Key, pytezos
from pytezos.rpc.errors import MichelsonError

from tezos_mac_tests.ligo import (
    LigoEnv,
    LigoContract,
    PtzUtils,
    flextesa_sandbox,
    token_metadata_object,
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


class TestMacSetUp(TestCase):
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
            "fa2_granular_multi_asset.mligo", "multi_asset_main"
        )
        ligo_receiver = ligo_client_env.contract_from_file(
            "token_owner.mligo", "token_owner_main"
        )

        print("originating contracts...")
        self.fa2 = self.orig_mac(ligo_fa2)
        print(f"FA2 address {self.fa2.address}")

        self.alice_receiver = self.orig_receiver(ligo_receiver)
        print(f"Alice address {self.alice_receiver.address}")
        self.bob_receiver = self.orig_receiver(ligo_receiver)
        print(f"Bob address {self.bob_receiver.address}")

    def orig_mac(self, ligo_mac):
        meta = {
            "interfaces": ["TZIP-012"],
            "name": "Multiple FA2 Pausable Fungible Tokens",
            "homepage": "https://github.com/tqtezos/smart-contracts",
            "license": {"name": "MIT"},
            "permissions": {
                "operator": "owner-or-operator-transfer",
                "receiver": "owner-no-hook",
                "sender": "owner-no-hook",
                "custom": {"tag": "PAUSABLE_TOKENS"},
            },
        }
        meta_content = json.dumps(meta, indent=2).encode().hex()
        meta_uri = str.encode("tezos-storage:content").hex()

        ligo_storage = """
        {
            admin = {
                admin = ("%s" : address);
                pending_admin = (None : address option);
                paused = (Big_map.empty : paused_tokens_set);
            };
            assets = {
                ledger = (Big_map.empty : ledger);
                operators = (Big_map.empty : operator_storage);
                token_total_supply = (Big_map.empty : token_total_supply);
                token_metadata = (Big_map.empty : token_metadata_storage);
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

        ptz_storage = ligo_mac.compile_storage(ligo_storage)
        return ligo_mac.originate(self.util, ptz_storage)

    def orig_receiver(self, ligo_receiver):
        return ligo_receiver.originate(self.util, balance=100000000)

    def transfer_init_funds(self):
        self.util.transfer(self.mike_key.public_key_hash(), 100000000)
        self.util.transfer(self.kyle_key.public_key_hash(), 100000000)

    # def pause_fa2(self, paused: bool):
    #     op = self.fa2.pause(paused).send(min_confirmations=1)

    def assertBalances(self, expectedResponses, msg=None):
        requests = [response["request"] for response in expectedResponses]
        responses = self.fa2.balance_of(requests=requests, callback=None).view()
        print('balances:')
        print(responses)
        self.assertListEqual(expectedResponses, responses, msg)

    def assertBalance(self, owner, token_id, expected_balance, msg=None):
        self.assertBalances([balance_response(owner, token_id, expected_balance)])

    def create_token(self, id, symbol):
        param = token_metadata_object(id, symbol, symbol, 0)
        print(param)
        self.fa2.create_token(param).send(min_confirmations=1)

class TestTransfer(TestMacSetUp):
    def setUp(self):
        super().setUp()

        self.alice_receiver.owner_add_operator(
            fa2=self.fa2.address, operator=self.admin_key.public_key_hash(), token_id=1
        ).send(min_confirmations=1)

        self.alice_receiver.owner_add_operator(
            fa2=self.fa2.address, operator=self.admin_key.public_key_hash(), token_id=2
        ).send(min_confirmations=1)

        print("creating tokens...")
        self.create_token(1, "TK1")
        self.create_token(2, "TK2")

        print("minting tokens...")
        alice_address = self.alice_receiver.address
        self.fa2.mint_tokens(
            [
                {"owner": alice_address, "amount": 10, "token_id": 1},
                {"owner": alice_address, "amount": 10, "token_id": 2},
            ]
        ).send(min_confirmations=1)

        print("transfer test setup completed")

    def test_unpaused_transfer(self):
        self.transfer_batch()

    def test_paused_transfer(self):
        print("pausing...")
        self.fa2.pause([{"token_id": 2, "paused": True}]).send(min_confirmations=1)
        print("paused token")

        with self.assertRaises(MichelsonError) as cm:
            self.transfer_batch()

        failed_with = PtzUtils.extract_failwith(cm.exception)
        self.assertEqual("TOKEN_PAUSED", failed_with)

    def transfer_batch(self):
        alice_address = self.alice_receiver.address
        bob_address = self.bob_receiver.address
        mike_address = self.mike_key.public_key_hash()

        print("transferring...")
        self.fa2.transfer(
            [
                {
                    "from_": alice_address,
                    "txs": [
                        {"to_": bob_address, "token_id": 1, "amount": 3},
                        {"to_": mike_address, "token_id": 2, "amount": 5},
                    ],
                }
            ]
        ).send(min_confirmations=1)
        print("batch transferred")

        self.assertBalances(
            [
                balance_response(alice_address, 1, 7),
                balance_response(alice_address, 2, 5),
                balance_response(bob_address, 1, 3),
                balance_response(bob_address, 2, 0),
                balance_response(mike_address, 1, 0),
                balance_response(mike_address, 2, 5),
            ]
        )
