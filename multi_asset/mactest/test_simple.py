from pathlib import Path
from unittest import skip, TestCase

from mactest.ligo import LigoEnv, LigoContract, PtzUtils, flextesa_sandbox


root_dir = Path(__file__).parent.parent
ligo_env = LigoEnv(root_dir / "impl", root_dir / "out")


@skip
class TestSimple(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sandbox = flextesa_sandbox
        cls.util = PtzUtils(flextesa_sandbox, block_time=8)
        cls.inspector = ligo_env.contract_from_file("inspector.mligo", "main")

    def test_response(self):
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

    def test_response_sandbox(self):
        init_storage = self.inspector.compile_storage("Empty unit")
        ci = self.inspector.originate(self.util, init_storage)

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
        op = ci.response(param["response"]).operation_group.sign().inject()
        self.util.wait_for_ops(op)

        s = ci.storage()
        expected_storage = self.inspector.compile_storage(
            """
            State {
                owner = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
                token_id = 42n;
                balance = 532n;
            }
        """
        )
        self.assertDictEqual(
            expected_storage, s, "updated storage is different",
        )
