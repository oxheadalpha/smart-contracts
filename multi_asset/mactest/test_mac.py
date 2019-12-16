from pathlib import Path
from decimal import *
from unittest import TestCase

from pytezos import Key

from mactest.ligo import LigoEnv, LigoContract, PtzUtils, flextesa_sandbox


root_dir = Path(__file__).parent.parent
ligo_env = LigoEnv(root_dir / "impl", root_dir / "out")


class TestMac(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sandbox = flextesa_sandbox
        cls.util = PtzUtils(flextesa_sandbox, wait_time=10)
        cls.admin = cls.sandbox.key

        cls.orig_contracts()

        cls.mike = Key.generate(export=False)
        cls.kyle = Key.generate(export=False)

        cls.transfer_init_funds()

    @classmethod
    def orig_contracts(cls):
        print("loading ligo contracts...")
        mac = ligo_env.contract_from_file("multi_asset.mligo", "multi_asset_main")
        receiver = ligo_env.contract_from_file(
            "multi_token_receiver.mligo", "receiver_stub"
        )
        inspector = ligo_env.contract_from_file("inspector.mligo", "main")

        print("originating contracts...")
        alice_op = cls.orig_receiver(receiver)
        bob_op = cls.orig_receiver(receiver)
        inspector_op = cls.orig_inspector(inspector)
        # mac_op = cls.orig_mac(mac)

        print("waiting for contracts origination to complete...")
        contract_ids = cls.util.wait_for_contracts(
            alice_op, bob_op, inspector_op  # , mac_op
        )
        contracts = [cls.sandbox.contract(id) for id in contract_ids]
        (cls.alice, cls.bob, cls.inspector) = contracts  # cls.mac,

    @classmethod
    def orig_mac(cls, mac):

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

        ptz_storage = mac.compile_storage(ligo_storage)
        return mac.originate_async(cls.util, ptz_storage)

    @classmethod
    def orig_inspector(cls, inspector):
        ligo_storage = "Empty unit"
        ptz_storage = inspector.compile_storage(ligo_storage)
        return inspector.originate_async(cls.util, ptz_storage)

    @classmethod
    def orig_receiver(cls, receiver):
        return receiver.originate_async(cls.util, balance=100000000)

    @classmethod
    def transfer_init_funds(cls):
        op3 = cls.util.transfer_async(cls.mike.public_key_hash(), 100000000)
        op4 = cls.util.transfer_async(cls.kyle.public_key_hash(), 100000000)
        cls.util.wait_for_ops(op3, op4)

    def test_dummy(self):
        self.assertIsNotNone(self.alice)

    def test_kyle_balance(self):
        bal1 = self.sandbox.account(self.kyle.public_key_hash())["balance"]
        print(f"kyle={bal1}")

    def test_alice_balance(self):
        bal2 = self.sandbox.account(self.alice.address)["balance"]
        print(f"alice={bal2}")

