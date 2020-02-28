from pathlib import Path
from unittest import TestCase
from tezos_mac_tests.ligo import LigoEnv


root_dir = Path(__file__).parent.parent
ligo_env = LigoEnv(root_dir / "impl", root_dir / "out")


# helper test to verify that all parts if MAC implementation compile w/o errors
class TestMacCompile(TestCase):
    @classmethod
    def setUpClass(cls):
        pass

    def test_compile_tokens_impl(self):
        ligo_env.contract_from_file(
            "multi_token_impl.mligo", "multi_token_main"
        ).compile_contract()

    def test_compile_simple_admin(self):
        ligo_env.contract_from_file(
            "simple_admin.mligo", "simple_admin"
        ).compile_contract()

    def test_compile_token_manager(self):
        ligo_env.contract_from_file(
            "token_manager.mligo", "token_manager"
        ).compile_contract()

    def test_compile_multi_asset(self):
        ligo_env.contract_from_file(
            "multi_asset.mligo", "multi_asset_main"
        ).compile_contract()

