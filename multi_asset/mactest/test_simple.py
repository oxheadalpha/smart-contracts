from pathlib import Path
from unittest import TestCase

from mactest.ligo import LigoEnv, LigoContract


root_dir = Path(__file__).parent.parent
ligo_env = LigoEnv(root_dir / "impl", root_dir / "out")


class TestSimple(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ligo_inspector = ligo_env.contract_from_file("inspector.mligo", "main")
        cls.inspector = cls.ligo_inspector.compile_contract()

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

    def test_storage(self):
        storage = self.ligo_inspector.compile_storage("Empty unit")
        print(storage)

    def test_parameter(self):
        ligo = """
            Response [
                ({ 
                    owner = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
                    token_id = 42n;
                },  532n)
            ]
        """
        parameter = self.ligo_inspector.compile_parameter(ligo)
        print(parameter)
