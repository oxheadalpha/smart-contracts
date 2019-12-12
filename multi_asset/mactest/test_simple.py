from pathlib import Path
from unittest import TestCase

from pytezos import pytezos
from mactest.ligo import LigoEnv, LigoContract, flextesa_sandbox


root_dir = Path(__file__).parent.parent
ligo_env = LigoEnv(root_dir / "impl", root_dir / "out")


class TestSimple(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sandbox = flextesa_sandbox
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
        inspector_id = self.inspector.originate(self.sandbox, init_storage)
        ci = self.sandbox.contract(inspector_id)

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
        self.sandbox.shell.wait_next_block(block_time=10)
        self.sandbox.shell.blocks[-5:].find_operation(op["hash"])

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
