from pathlib import Path
from decimal import *
from unittest import TestCase

from pytezos import Key, pytezos

from tezos_mac_tests.ligo import (
    LigoEnv,
    LigoContract,
    PtzUtils,
    flextesa_sandbox,
)


root_dir = Path(__file__).parent.parent / "ligo"
ligo_env = LigoEnv(root_dir / "impl", root_dir / "out")


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
            "fa2_single_asset.mligo", "single_asset_main"
        )
        ligo_receiver = ligo_env.contract_from_file("token_owner.mligo", "main")
        ligo_inspector = ligo_env.contract_from_file("inspector.mligo", "main")

        print("originating contracts...")
        self.fa2 = self.orig_mac(ligo_fa2)
        print(f"FA2 address {self.fa2.address}")

        self.alice_receiver = self.orig_receiver(ligo_receiver)
        print(f"Alice address {self.alice_receiver.address}")
        self.bob_receiver = self.orig_receiver(ligo_receiver)
        print(f"Bob address {self.bob_receiver.address}")
        self.inspector = self.orig_inspector(ligo_inspector)

    def orig_mac(self, ligo_mac):

        ligo_storage = (
            """
        {
            admin = {
                admin = ("%s" : address);
                pending_admin = (None : address option);
                paused = true;
            };
            assets = {
                ledger = (Big_map.empty : ((address * token_id), nat) big_map);
                operators = (Big_map.empty : ((address * address), unit) big_map);
                tokens = (Big_map.empty : (token_id, token_info) big_map);
            };
        }
        """
            % self.admin_key.public_key_hash()
        )

        ptz_storage = ligo_mac.compile_storage(ligo_storage)
        return ligo_mac.originate(self.util, ptz_storage)

    def orig_inspector(self, ligo_inspector):
        ligo_storage = "Empty unit"
        ptz_storage = ligo_inspector.compile_storage(ligo_storage)
        return ligo_inspector.originate(self.util, ptz_storage)

    def orig_receiver(self, ligo_receiver):
        return ligo_receiver.originate(self.util, balance=100000000)

    def transfer_init_funds(self):
        self.util.transfer(self.mike_key.public_key_hash(), 100000000)
        self.util.transfer(self.kyle_key.public_key_hash(), 100000000)

    def pause_fa2(self, paused: bool):
        op = self.fa2.pause(paused).inject()
        self.util.wait_for_ops(op)

    def assertBalance(self, owner_address, token_id, expected_balance, msg=None):
        op = self.inspector.query(
            fa2=self.fa2.address, token_id=token_id, owner=owner_address
        ).inject()
        self.util.wait_for_ops(op)
        b = self.inspector.storage()["state"]
        print(b)
        self.assertEqual(
            {
                "balance": expected_balance,
                "request": {"token_id": 0, "owner": owner_address},
            },
            b,
            msg,
        )

    def create_token(self, id, symbol):
        op = self.fa2.create_token(
            token_id=id, symbol=symbol, name=symbol, decimals=0, extra={}
        ).inject()
        self.util.wait_for_ops(op)


class TestMintBurn(TestMacSetUp):
    def setUp(self):
        super().setUp()
        print("creating token TK1")
        self.create_token(1, "TK1")
        # needed to check balances which is guarded
        print("unpausing")
        self.pause_fa2(False)

    def test_mint_burn_to_receiver(self):
        self.mint_burn(self.alice_receiver.address)

    def test_mint_burn_implicit(self):
        self.mint_burn(self.mike_key.public_key_hash())

    def mint_burn(self, owner_address):
        print("minting")
        mint_op = self.fa2.mint_tokens(
            owner=owner_address, batch=[{"amount": 10, "token_id": 1}]
        ).inject()
        self.util.wait_for_ops(mint_op)
        self.assertBalance(owner_address, 1, 10, "invalid mint balance")

        print("burning")
        burn_op = self.fa2.burn_tokens(
            owner=owner_address, batch=[{"amount": 3, "token_id": 1}]
        ).inject()
        self.util.wait_for_ops(burn_op)

        self.assertBalance(owner_address, 1, 7, "invalid balance after burn")


class TestOperator(TestMacSetUp):
    def setUp(self):
        super().setUp()
        self.pause_fa2(False)

    def test_add_operator_to_receiver(self):

        op_add = self.alice_receiver.add_operator(
            mac=self.fa2.address, operator=self.admin_key.public_key_hash()
        ).inject()
        self.util.wait_for_ops(op_add)

        op_check = self.inspector.assert_is_operator(
            fa2=self.fa2.address, operator=self.admin_key.public_key_hash()
        ).inject()

        self.util.wait_for_ops(op_check)


class TestTransfer(TestMacSetUp):
    def setUp(self):
        super().setUp()
        self.pause_fa2(False)

        op_op = self.alice_receiver.add_operator(
            fa2=self.fa2.address, operator=self.admin_key.public_key_hash()
        ).inject()
        self.util.wait_for_ops(op_op)
        print("transfer test setup completed")

    def test_transfer_to_receiver(self):
        self.create_token(1, "TK1")
        self.transfer(1, self.alice_receiver.address, self.bob_receiver.address)

    def test_transfer_to_implicit(self):
        self.create_token(2, "TK2")
        self.util.wait_for_ops(op)
        self.transfer(2, self.alice_receiver.address, self.mike_key.public_key_hash())

    def transfer(self, token_id, from_address, to_address):

        mint_op = self.fa2.mint_tokens(
            owner=from_address, batch=[{"amount": 10, "token_id": token_id}], data="00",
        ).inject()
        self.util.wait_for_ops(mint_op)

        op_tx = self.fa2.transfer(
            [
                {
                    "from_": from_address,
                    "txs": [{"to_": to_address, "token_id": token_id, "amount": 3}],
                }
            ]
        ).inject()
        self.util.wait_for_ops(op_tx)

        self.assertBalance(to_address, token_id, 3, "invalid recipient balance")
        self.assertBalance(from_address, token_id, 7, "invalid source balance")
