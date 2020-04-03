from pathlib import Path
from decimal import *
from unittest import TestCase

from pytezos import Key, pytezos

from tezos_mac_tests.ligo import LigoEnv, LigoContract, PtzUtils, flextesa_sandbox


root_dir = Path(__file__).parent.parent
ligo_env = LigoEnv(root_dir / "impl", root_dir / "out")


class TestFa2SetUp(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sandbox = flextesa_sandbox
        cls.util = PtzUtils(cls.sandbox, block_time=8)
        # cls.sandbox = pytezos
        # cls.util = PtzUtils(cls.sandbox, block_time=60, num_blocks_wait=4)
        cls.admin_key = cls.sandbox.key

        cls.orig_contracts()

        cls.mike_key = Key.generate(export=False)
        cls.kyle_key = Key.generate(export=False)

        # cls.transfer_init_funds()
        print("test setup completed")

    @classmethod
    def orig_contracts(cls):
        print("loading ligo contracts...")
        cls.ligo_fa2 = ligo_env.contract_from_file(
            "fa2_single_asset.mligo", "single_asset_main"
        )
        cls.ligo_hook = ligo_env.contract_from_file("fa2_default_hook.mligo", "main")
        cls.ligo_receiver = ligo_env.contract_from_file("token_owner.mligo", "main")
        cls.ligo_inspector = ligo_env.contract_from_file("inspector.mligo", "main")

        print("originating contracts...")
        cls.fa2 = cls.orig_fa2(cls.ligo_fa2)
        print(f"FA2 address {cls.fa2.address}")

        cls.alice_receiver = cls.orig_receiver(cls.ligo_receiver)
        print(f"Alice address {cls.alice_receiver.address}")
        cls.bob_receiver = cls.orig_receiver(cls.ligo_receiver)
        print(f"Bob address {cls.bob_receiver.address}")
        cls.inspector = cls.orig_inspector(cls.ligo_inspector)

    @classmethod
    def orig_fa2(cls, ligo_fa2):

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
                  self = Self_transfer_permitted;
                  operator = Operator_transfer_permitted;
                  sender = Owner_no_op;
                  receiver = Owner_no_op;
                  custom = (None : custom_permission_policy option);
                };
            };
        }
        """
            % cls.admin_key.public_key_hash()
        )

        ptz_storage = ligo_fa2.compile_storage(ligo_storage)
        return ligo_fa2.originate(cls.util, ptz_storage)

    @classmethod
    def orig_inspector(cls, ligo_inspector):
        ligo_storage = "Empty unit"
        ptz_storage = ligo_inspector.compile_storage(ligo_storage)
        return ligo_inspector.originate(cls.util, ptz_storage)

    @classmethod
    def orig_receiver(cls, ligo_receiver):
        return ligo_receiver.originate(cls.util, balance=100000000)

    @classmethod
    def transfer_init_funds(cls):
        cls.util.transfer(cls.mike_key.public_key_hash(), 100000000)
        cls.util.transfer(cls.kyle_key.public_key_hash(), 100000000)

    @classmethod
    def pause_fa2(cls, paused: bool):
        call = cls.fa2.pause(paused)
        op = call.inject()
        cls.util.wait_for_ops(op)

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
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        print("unpausing")
        cls.pause_fa2(False)

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
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.pause_fa2(False)

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
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.pause_fa2(False)

        op_op = cls.alice_receiver.owner_add_operator(
            fa2=cls.fa2.address, operator=cls.admin_key.public_key_hash()
        ).inject()
        cls.util.wait_for_ops(op_op)
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
