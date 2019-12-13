from pathlib import Path
from unittest import TestCase

from pytezos import Key

from mactest.ligo import LigoEnv, LigoContract, PtzUtils, flextesa_sandbox

from time import sleep


root_dir = Path(__file__).parent.parent
ligo_env = LigoEnv(root_dir / "impl", root_dir / "out")


class TestMac(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sandbox = flextesa_sandbox
        cls.util = PtzUtils(flextesa_sandbox, wait_time=10)
        cls.admin = cls.sandbox.key.public_key_hash()

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
            % cls.admin
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
        return receiver.originate_async(cls.util)

    @classmethod
    def orig_implicit(cls):
        key = Key.generate()
        address = key.public_key_hash()
        op = cls.sandbox.reveal(address).fill().sign().inject()
        return (op, key)

    def test_dummy(self):
        self.assertIsNotNone(self.alice)

