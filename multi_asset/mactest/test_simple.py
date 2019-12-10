from pathlib import Path
from unittest import TestCase

from mactest.ligo import LigoEnv, LigoContract


root_dir = Path(__file__).parent.parent
ligo_env = LigoEnv(root_dir / "impl", root_dir / "out")


class TestSimple(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inspector = ligo_env.contract_from_file("inspector.mligo", "main")

    def test_response2(self):
        param = self.inspector.compile_parameter(
            """
            Response [
                ({ 
                    owner = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
                    token_id = 42n;
                },  532n)
            ]
        """
        )

        init_storage = self.inspector.compile_storage("Empty unit")
        expected_storage = self.inspector.compile_storage(
            """
            State {
                owner = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
                token_id = 42n;
                balance = 532n;
            }
        """
        )

        res = self.inspector().response(param["response"]).result(storage=init_storage)

        self.assertDictEqual(
            expected_storage, res.storage, "updated storage is different",
        )

    def test_storage(self):
        storage = self.inspector.compile_storage("Empty unit")
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
        parameter = self.inspector.compile_parameter(ligo)
        print(parameter)
