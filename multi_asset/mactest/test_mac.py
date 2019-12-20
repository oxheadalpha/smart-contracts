from pathlib import Path
from decimal import *
from unittest import TestCase

from pytezos import Key

from mactest.ligo import LigoEnv, LigoContract, PtzUtils, flextesa_sandbox


root_dir = Path(__file__).parent.parent
ligo_env = LigoEnv(root_dir / "impl", root_dir / "out")


class TestMacSetUp(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sandbox = flextesa_sandbox
        cls.util = PtzUtils(flextesa_sandbox, block_time=8)
        cls.admin = cls.sandbox.key

        cls.orig_contracts()

        cls.mike = Key.generate(export=False)
        cls.kyle = Key.generate(export=False)

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
        mac_op = cls.orig_mac(cls.ligo_mac)
        alice_op = cls.orig_receiver(cls.ligo_receiver)
        bob_op = cls.orig_receiver(cls.ligo_receiver)
        inspector_op = cls.orig_inspector(cls.ligo_inspector)

        print("waiting for contracts origination to complete...")
        contract_ids = cls.util.wait_for_contracts(
            mac_op, alice_op, bob_op, inspector_op
        )
        contracts = [cls.sandbox.contract(id) for id in contract_ids]
        (cls.mac, cls.alice, cls.bob, cls.inspector) = contracts

    @classmethod
    def orig_mac(cls, ligo_mac):

        ligo_storage = (
            """
        {
            admin = {
              admin = ("%s" : address);
              paused = true;
              tokens = (Big_map.empty : (nat, string) big_map);
            };
            assets = {
              operators = (Big_map.empty : (address, address set) big_map);
              balance_storage = {
                owners = {
                  owner_count = 0n;
                  owners = (Big_map.empty : (address, nat) big_map);
                };
                balances = (Big_map.empty : (nat, nat) big_map);
              }
            };
        }
        """
            % cls.admin.public_key_hash()
        )

        ptz_storage = ligo_mac.compile_storage(ligo_storage)
        return ligo_mac.originate_async(cls.util, ptz_storage)

    @classmethod
    def orig_inspector(cls, ligo_inspector):
        ligo_storage = "Empty unit"
        ptz_storage = ligo_inspector.compile_storage(ligo_storage)
        return ligo_inspector.originate_async(cls.util, ptz_storage)

    @classmethod
    def orig_receiver(cls, ligo_receiver):
        return ligo_receiver.originate_async(cls.util, balance=100000000)

    @classmethod
    def transfer_init_funds(cls):
        op3 = cls.util.transfer_async(cls.mike.public_key_hash(), 100000000)
        op4 = cls.util.transfer_async(cls.kyle.public_key_hash(), 100000000)
        cls.util.wait_for_ops(op3, op4)

    @classmethod
    def create_token(self, id, name):
        op = (
            self.mac.create_token(token_id=id, descriptor=name)
            .operation_group.sign()
            .inject()
        )
        self.util.wait_for_ops(op)

    @classmethod
    def pause_mac(cls, paused: bool):
        call = cls.mac.pause(paused)
        op = call.inject()
        cls.util.wait_for_ops(op)

    def inspect_balance(self, address, token_id):
        # op = self.inspector.query(
        #     mac=self.mac.address, token_id=token_id, owner=address
        # ).inject()
        # from pytezos.operation.result import OperationResult

        from pytezos.operation.group import OperationResult
        og = self.inspector.query(
            mac=self.mac.address, token_id=token_id, owner=address
        ).operation_group
        og.contents[0]["gas_limit"] = "800000"
        af = og.autofill()
        op = af.sign().inject()
        self.util.wait_for_ops(op)
        return self.inspector.storage()["state"]


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
        print("minting")
        mint_op = self.mac.mint_tokens(
            owner=self.alice.address, batch=[{"amount": 10, "token_id": 1}], data="00",
        ).inject()
        self.util.wait_for_ops(mint_op)
        print("inspecting")
        b = self.inspect_balance(self.alice.address, 1)
        print(b)
        self.assertEqual({
            "balance": 10,
            "token_id": 1,
            "owner": self.alice.address
        }, b, "wrong mint balance")


class TestBalances(TestMacSetUp):
    def test_dummy(self):
        self.assertIsNotNone(self.alice)

    def test_kyle_balance(self):
        bal1 = self.sandbox.account(self.kyle.public_key_hash())["balance"]
        print(f"kyle={bal1}")

    def test_alice_balance(self):
        bal2 = self.sandbox.account(self.alice.address)["balance"]
        print(f"alice={bal2}")
