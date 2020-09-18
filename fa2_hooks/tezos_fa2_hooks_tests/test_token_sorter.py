from tezos_fa2_hooks_tests.test_mac import (
    TestMacSetUp,
    ligo_env,
    ligo_client_env,
    balance_response,
)

GREEN = 0
YELLOW = 1
RED = 2


class TestTokenSorter(TestMacSetUp):
    def orig_contracts(self):
        print("loading ligo contracts...")
        ligo_fa2 = ligo_env.contract_from_file(
            "fa2_multi_asset.mligo", "multi_asset_main"
        )
        ligo_receiver = ligo_client_env.contract_from_file(
            "token_owner.mligo", "token_owner_main"
        )
        ligo_sorter = ligo_env.contract_from_file(
            "token_sorter.mligo", "token_sorter_main"
        )
        ligo_inspector = ligo_client_env.contract_from_file("inspector.mligo", "main")

        print("originating contracts...")
        self.fa2 = self.orig_mac(ligo_fa2)
        print(f"FA2 address {self.fa2.address}")

        self.alice_receiver = self.orig_receiver(ligo_receiver)
        print(f"Alice address {self.alice_receiver.address}")

        self.green_receiver = self.orig_receiver(ligo_receiver)
        print(f"green address {self.green_receiver.address}")
        self.yellow_receiver = self.orig_receiver(ligo_receiver)
        print(f"yellow address {self.yellow_receiver.address}")
        self.red_receiver = self.orig_receiver(ligo_receiver)
        print(f"red address {self.red_receiver.address}")

        self.sorter = self.orig_sorter(ligo_sorter)
        print(f"sorter address {self.sorter.address}")

        self.inspector = self.orig_inspector(ligo_inspector)

    def orig_sorter(self, ligo_sorter):
        storage_entry = (
            lambda fa2_a, token_id, receiver_a: f"""
            (
              (("{fa2_a}" : address), {token_id}n), 
              {{
                destination = ("{receiver_a}" : address);
                pending_balance = 0n;
              }}
            )"""
        )

        ligo_storage = f"""Big_map.literal [
          {storage_entry(self.fa2.address, GREEN, self.green_receiver.address)};
          {storage_entry(self.fa2.address, YELLOW, self.yellow_receiver.address)};
          {storage_entry(self.fa2.address, RED, self.red_receiver.address)};
        ]"""

        ptz_storage = ligo_sorter.compile_storage(ligo_storage)
        return ligo_sorter.originate(self.util, ptz_storage)

    def setUp(self):
        super().setUp()
        self.create_tokens()
        self.pause_fa2(False)

        op_op = self.alice_receiver.owner_add_operator(
            fa2=self.fa2.address,
            operator=self.admin_key.public_key_hash(),
            token_id=RED,
        ).inject()
        self.util.wait_for_ops(op_op)
        op_op = self.alice_receiver.owner_add_operator(
            fa2=self.fa2.address,
            operator=self.admin_key.public_key_hash(),
            token_id=GREEN,
        ).inject()
        self.util.wait_for_ops(op_op)
        op_op = self.alice_receiver.owner_add_operator(
            fa2=self.fa2.address,
            operator=self.admin_key.public_key_hash(),
            token_id=YELLOW,
        ).inject()
        self.util.wait_for_ops(op_op)
        print("sorter test setup completed")

    def create_tokens(self):
        print("creating tokens")
        self.create_token(GREEN, "GREEN")
        self.create_token(YELLOW, "YELLOW")
        self.create_token(RED, "RED")

    def test_sort(self):
        alice_a = self.alice_receiver.address
        mint_op = self.fa2.mint_tokens(
            [
                {"owner": alice_a, "amount": 10, "token_id": GREEN},
                {"owner": alice_a, "amount": 10, "token_id": YELLOW,},
                {"owner": alice_a, "amount": 10, "token_id": RED},
            ]
        ).inject()
        self.util.wait_for_ops(mint_op)
        print("minted")

        sorter_a = self.sorter.address
        op_tx = self.fa2.transfer(
            [
                {
                    "from_": alice_a,
                    "txs": [
                        {"to_": sorter_a, "token_id": GREEN, "amount": 3},
                        {"to_": sorter_a, "token_id": YELLOW, "amount": 4},
                        {"to_": sorter_a, "token_id": RED, "amount": 6},
                    ],
                }
            ]
        ).inject()
        self.util.wait_for_ops(op_tx)
        print("transferred")

        op_forward = self.sorter.forward(
            fa2=self.fa2.address, tokens=[GREEN, YELLOW, RED]
        ).inject()
        self.util.wait_for_ops(op_forward)
        print("forwarded")

        # assert alice reminders
        self.assertBalances(
            [
                balance_response(alice_a, GREEN, 7),
                balance_response(alice_a, YELLOW, 6),
                balance_response(alice_a, RED, 4),
            ],
            "alice balances",
        )

        # assert sorter does not hold any balances
        self.assertBalances(
            [
                balance_response(sorter_a, GREEN, 0),
                balance_response(sorter_a, YELLOW, 0),
                balance_response(sorter_a, RED, 0),
            ],
            "sorter balances",
        )

        # assert each token receiver
        green_a = self.green_receiver.address
        self.assertBalances(
            [
                balance_response(green_a, GREEN, 3),
                balance_response(green_a, YELLOW, 0),
                balance_response(green_a, RED, 0),
            ],
            "green receiver balances",
        )

        yellow_a = self.yellow_receiver.address
        self.assertBalances(
            [
                balance_response(yellow_a, GREEN, 0),
                balance_response(yellow_a, YELLOW, 4),
                balance_response(yellow_a, RED, 0),
            ],
            "yellow receiver balances",
        )

        red_a = self.red_receiver.address
        self.assertBalances(
            [
                balance_response(red_a, GREEN, 0),
                balance_response(red_a, YELLOW, 0),
                balance_response(red_a, RED, 6),
            ],
            "red receiver balances",
        )

