from pathlib import Path
from decimal import *
from unittest import TestCase

from pytezos import Key

from tezos_mac_tests.ligo import LigoEnv, LigoContract, PtzUtils, flextesa_sandbox


root_dir = Path(__file__).parent.parent
ligo_env = LigoEnv(root_dir / "impl", root_dir / "out")


class TestMacSetUp(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sandbox = flextesa_sandbox
        cls.util = PtzUtils(flextesa_sandbox, block_time=8)
        cls.admin_key = cls.sandbox.key

        cls.orig_contracts()

        cls.mike_key = Key.generate(export=False)
        cls.kyle_key = Key.generate(export=False)

        cls.transfer_init_funds()

    @classmethod
    def orig_contracts(cls):
        print("loading ligo contracts...")
        cls.ligo_mac = ligo_env.contract_from_file(
            "multi_asset.mligo", "multi_asset_main"
        )
        cls.ligo_receiver = ligo_env.contract_from_file(
            "multi_token_receiver.mligo", "receiver_stub"
        )
        cls.ligo_inspector = ligo_env.contract_from_file("inspector.mligo", "main")

        print("originating contracts...")
        cls.mac = cls.orig_mac(cls.ligo_mac)
        cls.alice_receiver = cls.orig_receiver(cls.ligo_receiver)
        cls.bob_receiver = cls.orig_receiver(cls.ligo_receiver)
        cls.inspector = cls.orig_inspector(cls.ligo_inspector)

    @classmethod
    def orig_mac(cls, ligo_mac):

        ligo_storage = (
            """
        {
            admin = {
              admin = ("%s" : address);
              paused = true;
            };
            assets = {
              operators = (Big_map.empty : (address, address set) big_map);
              balance_storage = {
                owners = {
                  owner_count = 0n;
                  owners = (Big_map.empty : (address, owner_entry) big_map);
                };
                balances = (Big_map.empty : (nat, nat) big_map);
              }
            };
            tokens = (Big_map.empty : (nat, string) big_map);
        }
        """
            % cls.admin_key.public_key_hash()
        )

        ptz_storage = ligo_mac.compile_storage(ligo_storage)
        return ligo_mac.originate(cls.util, ptz_storage)

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
    def create_token(self, id, name):
        op = self.mac.create_token(token_id=id, descriptor=name).inject()
        self.util.wait_for_ops(op)

    @classmethod
    def pause_mac(cls, paused: bool):
        call = cls.mac.pause(paused)
        op = call.inject()
        cls.util.wait_for_ops(op)

    def assertBalance(self, owner_address, token_id, expected_balance, msg=None):
        op = self.inspector.query(
            mac=self.mac.address, token_id=token_id, owner=owner_address
        ).inject()
        self.util.wait_for_ops(op)
        b = self.inspector.storage()["state"]
        print(b)
        self.assertEqual(
            {"balance": expected_balance, "token_id": token_id, "owner": owner_address},
            b,
            msg,
        )


class TestMintBurn(TestMacSetUp):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        print("creating token TK1")
        cls.create_token(1, "TK1")
        # needed to check balances which is guarded
        print("unpausing")
        cls.pause_mac(False)

    def test_mint_burn_to_receiver(self):
        self.mint_burn(self.alice_receiver.address)

    def test_mint_burn_implicit(self):
        op = self.mac.add_implicit_owners([self.mike_key.public_key_hash()]).inject()
        self.util.wait_for_ops(op)
        self.mint_burn(self.mike_key.public_key_hash())

    def mint_burn(self, owner_address):
        print("minting")
        mint_op = self.mac.mint_tokens(
            owner=owner_address, batch=[{"amount": 10, "token_id": 1}], data="00"
        ).inject()
        self.util.wait_for_ops(mint_op)
        self.assertBalance(owner_address, 1, 10, "invalid mint balance")

        print("burning")
        burn_op = self.mac.burn_tokens(
            owner=owner_address, batch=[{"amount": 3, "token_id": 1}]
        ).inject()
        self.util.wait_for_ops(burn_op)

        self.assertBalance(owner_address, 1, 7, "invalid balance after burn")


class TestOperator(TestMacSetUp):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.pause_mac(False)

    def test_add_operator_to_receiver(self):

        op_add = self.alice_receiver.add_operator(
            mac=self.mac.address, operator=self.admin_key.public_key_hash()
        ).inject()
        self.util.wait_for_ops(op_add)

        op_check = self.inspector.assert_is_operator(
            mac=self.mac.address,
            request={
                "owner": self.alice_receiver.address,
                "operator": self.admin_key.public_key_hash(),
            },
        ).inject()

        self.util.wait_for_ops(op_check)

        # def test_add_operator_to_implicit(self):
        #     op_add = (
        #         self.sandbox.transaction(
        #             destination=self.mac.address,
        #             source=self.mike_key.public_key_hash(),
        #             parameters={
        #                 "entrypoint": "add_operator",
        #                 "value": {"string": self.admin_key.public_key_hash()},
        #             },
        #         )
        #         .autofill()
        #         .sign()
        #         .inject()
        #     )
        #     self.util.wait_for_ops(op_add)
        #     print("operator added")

        # op_check = self.inspector.assert_is_operator(
        #     mac=self.mac.address,
        #     request={
        #         "owner": self.mike_key.public_key_hash(),
        #         "operator": self.admin_key.public_key_hash(),
        #     },
        # ).inject()

        # self.util.wait_for_ops(op_check)


class TestTransfer(TestMacSetUp):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.pause_mac(False)

        op_op = cls.alice_receiver.add_operator(
            mac=cls.mac.address, operator=cls.admin_key.public_key_hash()
        ).inject()
        cls.util.wait_for_ops(op_op)

    def test_transfer_to_receiver(self):
        self.create_token(1, "TK1")

        self.transfer(1, self.alice_receiver.address, self.bob_receiver.address)

    def test_transfer_to_implicit(self):
        self.create_token(2, "TK2")

        op = self.mac.add_implicit_owners([self.mike_key.public_key_hash()]).inject()
        self.util.wait_for_ops(op)

        self.transfer(2, self.alice_receiver.address, self.mike_key.public_key_hash())

    def transfer(self, token_id, from_address, to_address):

        mint_op = self.mac.mint_tokens(
            owner=from_address, batch=[{"amount": 10, "token_id": token_id}], data="00",
        ).inject()
        self.util.wait_for_ops(mint_op)

        op_tx = self.mac.transfer(
            from_=from_address,
            to_=to_address,
            batch=[{"token_id": token_id, "amount": 3}],
            data="00",
        ).inject()
        self.util.wait_for_ops(op_tx)

        self.assertBalance(to_address, token_id, 3, "invalid recipient balance")
        self.assertBalance(from_address, token_id, 7, "invalid source balance")
