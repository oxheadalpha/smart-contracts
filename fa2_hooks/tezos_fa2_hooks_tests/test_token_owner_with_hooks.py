from tezos_fa2_hooks_tests.test_mac import (
    TestMacSetUp,
    ligo_env,
    ligo_client_env,
    balance_response,
)


class TestHooks(TestMacSetUp):
    def orig_contracts(self):
        print("loading ligo contracts...")
        ligo_fa2 = ligo_env.contract_from_file(
            "fa2_multi_asset.mligo", "multi_asset_main"
        )
        ligo_receiver = ligo_env.contract_from_file(
            "token_owner_with_hooks.mligo", "token_owner_with_hooks_main"
        )

        print("originating contracts...")
        self.fa2 = self.orig_mac(ligo_fa2)
        print(f"FA2 address {self.fa2.address}")

        self.alice_receiver = self.orig_receiver(ligo_receiver)
        print(f"Alice address {self.alice_receiver.address}")
        self.bob_receiver = self.orig_receiver(ligo_receiver)
        print(f"Bob address {self.bob_receiver.address}")

    def setUp(self):
        super().setUp()
        self.pause_fa2(False)

        self.alice_receiver.owner_add_operator(
            fa2=self.fa2.address, operator=self.admin_key.public_key_hash(), token_id=1
        ).send(min_confirmations=1)
        print("transfer test setup completed")

    def test_transfer(self):
        self.create_token(1, "TK1")
        self.transfer(1, self.alice_receiver.address, self.bob_receiver.address)
        print(f"bob storage after: {self.bob_receiver.storage()}")
        print(f"alice storage after: {self.alice_receiver.storage()}")

    def transfer(self, token_id, from_address, to_address):
        self.fa2.mint_tokens(
            [{"owner": from_address, "amount": 10, "token_id": token_id}]
        ).send(min_confirmations=1)

        self.fa2.transfer(
            [
                {
                    "from_": from_address,
                    "txs": [{"to_": to_address, "token_id": token_id, "amount": 3}],
                }
            ]
        ).send(min_confirmations=1)
        print("transferred")

        self.assertBalances(
            [
                balance_response(to_address, token_id, 3),
                balance_response(from_address, token_id, 7),
            ],
            "invalid balances",
        )
