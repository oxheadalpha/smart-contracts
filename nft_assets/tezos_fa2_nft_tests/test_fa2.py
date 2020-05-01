from pathlib import Path
from decimal import *
from unittest import TestCase

from pytezos import Key, pytezos

from tezos_fa2_nft_tests.ligo import (
    LigoEnv,
    LigoContract,
    PtzUtils,
    flextesa_sandbox,
)


root_dir = Path(__file__).parent.parent
ligo_env = LigoEnv(root_dir / "impl", root_dir / "out")


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
            "fa2_single_asset.mligo", "single_asset_main"
        )
        ligo_receiver = ligo_env.contract_from_file("token_owner.mligo", "main")
        ligo_inspector = ligo_env.contract_from_file("inspector.mligo", "main")

        print("originating contracts...")
        self.fa2 = self.orig_fa2(ligo_fa2)
        print(f"FA2 address {self.fa2.address}")

        self.alice_receiver = self.orig_receiver(ligo_receiver)
        print(f"Alice address {self.alice_receiver.address}")
        self.bob_receiver = self.orig_receiver(ligo_receiver)
        print(f"Bob address {self.bob_receiver.address}")
        self.inspector = self.orig_inspector(ligo_inspector)

    def orig_fa2(self, ligo_fa2):

        ligo_storage = (
            """
        {
            admin = {
              admin = ("%s" : address);
              paused = true;
            };
            assets = {
                ledger = (Big_map.empty : (address, nat) big_map);
                operators = (Big_map.empty : ((address * address), bool) big_map);
                metadata = {
                    token_id = 0n;
                    symbol = "TK1";
                    name = "Test Token";
                    decimals = 0n;
                    extras = (Map.empty : (string, string) map);
                };
                total_supply = 0n;
                permissions_descriptor = {
                  operator = Owner_or_operator_transfer;
                  sender = Owner_no_op;
                  receiver = Owner_no_op;
                  custom = (None : custom_permission_policy option);
                };
            };
        }
        """
            % self.admin_key.public_key_hash()
        )

        ptz_storage = ligo_fa2.compile_storage(ligo_storage)
        return ligo_fa2.originate(self.util, ptz_storage)

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

    def assertBalance(self, owner_address, expected_balance, msg=None):
        op = self.inspector.query(fa2=self.fa2.address, owner=owner_address).inject()
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

    def get_balance(self, owner_address):
        op = self.inspector.query(fa2=self.fa2.address, owner=owner_address).inject()
        self.util.wait_for_ops(op)
        b = self.inspector.storage()["state"]
        return b["balance"]


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
        mint_op = self.fa2.mint_tokens(
            [{"amount": 10, "owner": owner_address}]
        ).inject()
        self.util.wait_for_ops(mint_op)
        self.assertBalance(owner_address, 10, "invalid mint balance")

        print("burning")
        burn_op = self.fa2.burn_tokens([{"amount": 3, "owner": owner_address}]).inject()
        self.util.wait_for_ops(burn_op)

        self.assertBalance(owner_address, 7, "invalid balance after burn")


class TestOperator(TestFa2SetUp):
    def setUp(self):
        super().setUp()
        self.pause_fa2(False)

    def test_add_operator_to_receiver(self):

        op_add = self.alice_receiver.owner_add_operator(
            fa2=self.fa2.address, operator=self.admin_key.public_key_hash()
        ).inject()
        self.util.wait_for_ops(op_add)

        op_check = self.inspector.assert_is_operator(
            fa2=self.fa2.address,
            request={
                "owner": self.alice_receiver.address,
                "operator": self.admin_key.public_key_hash(),
                "tokens": {"all_tokens": None},
            },
        ).inject()

        self.util.wait_for_ops(op_check)


class TestTransfer(TestFa2SetUp):
    def setUp(self):
        super().setUp()
        self.pause_fa2(False)

        op_op = self.alice_receiver.owner_add_operator(
            fa2=self.fa2.address, operator=self.admin_key.public_key_hash()
        ).inject()
        self.util.wait_for_ops(op_op)
        print("transfer test setup completed")

    def test_transfer_to_receiver(self):
        self.transfer(self.alice_receiver.address, self.bob_receiver.address)

    def test_transfer_to_implicit(self):
        self.transfer(self.alice_receiver.address, self.mike_key.public_key_hash())

    def transfer(self, from_address, to_address):

        mint_op = self.fa2.mint_tokens([{"amount": 10, "owner": from_address}]).inject()
        self.util.wait_for_ops(mint_op)

        from_bal = self.get_balance(from_address)

        print("transfering")
        op_tx = self.fa2.transfer(
            [{"from_": from_address, "to_": to_address, "token_id": 0, "amount": 3}]
        ).inject()
        self.util.wait_for_ops(op_tx)

        self.assertBalance(to_address, 3, "invalid recipient balance")
        self.assertBalance(from_address, from_bal - 3, "invalid source balance")
