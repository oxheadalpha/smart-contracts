from pathlib import Path
from unittest import TestCase

# from pytezos import pytezos as ptz, ContractInterface

from test.ligo import LigoEnv, LigoContract


root_dir = Path.cwd() / "multi_asset"
ligo_env = LigoEnv(root_dir / "impl", root_dir / "out")


class TestSimple(TestCase):
    @classmethod
    def setUpClass(cls):
        c = ligo_env.contract_from_file("inspector.mligo", "main")
        cls.inspector = c.compile()

    def test_response(self):
        res = self.inspector.response(
            [["tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU", 42, 532]]
        ).result(storage={"empty": None})
        self.assertDictEqual(
            {
                "state": {
                    "balance": 532,
                    "owner": "tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU",
                    "token_id": 42,
                }
            },
            res.storage,
            "updated storage is different",
        )

