from tezos_fa2_hooks_tests.test_mac import TestMacSetUp, ligo_env

GREEN = 0
YELLOW = 1
RED = 2


class TestTokenSorter(TestMacSetUp):
    def orig_contracts(self):
        print("loading ligo contracts...")
        ligo_fa2 = ligo_env.contract_from_file(
            "fa2_multi_asset.mligo", "multi_asset_main"
        )
        ligo_receiver = ligo_env.contract_from_file(
            "token_owner.mligo", "token_owner_main"
        )
        ligo_sorter = ligo_env.contract_from_file(
            "token_sorter.mligo", "token_sorter_main"
        )
        ligo_inspector = ligo_env.contract_from_file("inspector.mligo", "main")

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
        ligo_storage = f"""Big_map.literal [
          ((("{self.fa2.address}" : address), {GREEN}n), ("{self.green_receiver.address}" : address));
          ((("{self.fa2.address}" : address), {YELLOW}n), ("{self.yellow_receiver.address}" : address));
          ((("{self.fa2.address}" : address), {RED}n), ("{self.red_receiver.address}" : address));
        ]"""

        ptz_storage = ligo_sorter.compile_storage(ligo_storage)
        return ligo_sorter.originate(self.util, ptz_storage)

    def setUp(self):
        super().setUp()
        self.create_tokens()
        self.pause_fa2(False)

        op_op = self.alice_receiver.owner_add_operator(
            fa2=self.fa2.address, operator=self.admin_key.public_key_hash()
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

        # assert alice reminders
        self.assertBalance(alice_a, GREEN, 7, "alice green")
        self.assertBalance(alice_a, YELLOW, 6, "alice yellow")
        self.assertBalance(alice_a, RED, 4, "alice red")

        # assert sorter does not hold any balances
        self.assertBalance(sorter_a, GREEN, 0, "sorter green")
        self.assertBalance(sorter_a, YELLOW, 0, "sorter yellow")
        self.assertBalance(sorter_a, RED, 0, "sorter red")

        # assert each token receiver
        green_a = self.green_receiver.address
        self.assertBalance(green_a, GREEN, 3, "receiver green")
        self.assertBalance(green_a, YELLOW, 0, "receiver green has yellow tokens")
        self.assertBalance(green_a, RED, 0, "receiver green has red tokens")

        yellow_a = self.yellow_receiver.address
        self.assertBalance(yellow_a, GREEN, 0, "receiver yellow has green tokens")
        self.assertBalance(yellow_a, YELLOW, 4, "receiver yellow")
        self.assertBalance(yellow_a, RED, 0, "receiver yellow has red tokens")

        red_a = self.red_receiver.address
        self.assertBalance(red_a, GREEN, 0, "receiver red has green tokens")
        self.assertBalance(red_a, YELLOW, 0, "receiver red has yellow tokens")
        self.assertBalance(red_a, RED, 6, "receiver red")

