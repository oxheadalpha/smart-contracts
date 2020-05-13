from pathlib import Path
from decimal import *
from unittest import TestCase

from pytezos import Key, pytezos
from pytezos.rpc.errors import MichelsonRuntimeError

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
        ligo_fa2 = ligo_env.contract_from_file("fa2_nft_asset.mligo", "nft_asset_main")
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
                ledger = (Big_map.empty : (token_id, address) big_map);
                operators = (Big_map.empty : ((address * address), unit) big_map);
                metadata = {
                  token_defs = (Set.empty : token_def set);
                  last_used_id = 0n;
                  metadata = (Big_map.empty : (token_def, token_metadata) big_map);
                };
                permissions_descriptor = {
                  operator = Owner_or_operator_transfer;
                  sender = Owner_no_hook;
                  receiver = Owner_no_hook;
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

    def assertBalance(self, owner_address, token_id, expected_balance, msg=None):
        op = self.inspector.query(
            fa2=self.fa2.address, request={"owner": owner_address, "token_id": token_id}
        ).inject()
        self.util.wait_for_ops(op)
        b = self.inspector.storage()["state"]
        print(b)
        self.assertEqual(
            {
                "balance": expected_balance,
                "request": {"token_id": token_id, "owner": owner_address},
            },
            b,
            msg,
        )


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
        mint_op = self.fa2.mint_tokens(
            {
                "metadata": {
                    "decimals": 0,
                    "name": "socks token",
                    "symbol": "SOCK",
                    "token_id": 0,
                    "extras": {"0": "left", "1": "right"},
                },
                "token_def": {"from_": 0, "to_": 2,},
                "owners": [owner1_address, owner2_address],
            }
        ).inject()
        self.util.wait_for_ops(mint_op)
        self.assertBalance(owner1_address, 0, 1, "invalid mint balance 1")
        self.assertBalance(owner1_address, 1, 0, "invalid mint balance 1")
        self.assertBalance(owner2_address, 1, 1, "invalid mint balance 2")

        print("burning")
        burn_op = self.fa2.burn_tokens(from_=0, to_=2).inject()
        self.util.wait_for_ops(burn_op)

        with self.assertRaises(MichelsonRuntimeError) as cm:
            op = self.inspector.query(
                fa2=self.fa2.address, request={"owner": owner1_address, "token_id": 0}
            ).inject()
            self.util.wait_for_ops(op)

        failedwith = cm.exception.args[0]["with"]["string"]
        self.assertEqual("TOKEN_UNDEFINED", failedwith)


class TestOperator(TestFa2SetUp):
    def setUp(self):
        super().setUp()
        self.pause_fa2(False)

    def test_add_operator_to_receiver(self):

        print("adding operator")
        op_add = self.alice_receiver.owner_add_operator(
            fa2=self.fa2.address, operator=self.admin_key.public_key_hash()
        ).inject()
        self.util.wait_for_ops(op_add)

        print("checking operator")
        op_check = self.inspector.assert_is_operator(
            fa2=self.fa2.address,
            request={
                "owner": self.alice_receiver.address,
                "operator": self.admin_key.public_key_hash(),
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

        op_op2 = self.bob_receiver.owner_add_operator(
            fa2=self.fa2.address, operator=self.admin_key.public_key_hash()
        ).inject()
        self.util.wait_for_ops(op_op2)
        print("transfer test setup completed")

    def test_transfer(self):

        alice_a = self.alice_receiver.address
        bob_a = self.bob_receiver.address
        mike_a = self.mike_key.public_key_hash()
        left_sock = 0
        right_sock = 1

        mint_op = self.fa2.mint_tokens(
            {
                "metadata": {
                    "decimals": 0,
                    "name": "socks token",
                    "symbol": "SOCK",
                    "token_id": 0,
                    "extras": {"0": "left", "1": "right"},
                },
                "token_def": {"from_": 0, "to_": 2,},
                "owners": [alice_a, bob_a],
            }
        ).inject()
        self.util.wait_for_ops(mint_op)

        self.assertBalance(alice_a, left_sock, 1, "invalid mint balance alice")
        self.assertBalance(bob_a, right_sock, 1, "invalid mint balance bob")
        self.assertBalance(mike_a, left_sock, 0, "invalid mint balance mike")
        self.assertBalance(mike_a, right_sock, 0, "invalid mint balance mike")

        print("transfering")
        op_tx = self.fa2.transfer(
            [
                {"from_": alice_a, "to_": mike_a, "token_id": left_sock, "amount": 1},
                {"from_": bob_a, "to_": mike_a, "token_id": right_sock, "amount": 1},
            ]
        ).inject()
        self.util.wait_for_ops(op_tx)

        self.assertBalance(alice_a, left_sock, 0, "invalid mint balance alice")
        self.assertBalance(bob_a, right_sock, 0, "invalid mint balance bob")
        self.assertBalance(mike_a, left_sock, 1, "invalid mint balance mike")
        self.assertBalance(mike_a, right_sock, 1, "invalid mint balance mike")
