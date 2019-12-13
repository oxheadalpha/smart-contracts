from pathlib import Path
import os
from subprocess import Popen, PIPE
from io import TextIOWrapper
from time import sleep

from pytezos import pytezos, ContractInterface
from pytezos.operation.result import OperationResult
from pytezos.rpc.errors import RpcError


class LigoEnv:
    def __init__(self, src_dir, out_dir):
        self.src_dir = Path(src_dir)
        self.out_dir = Path(out_dir)

    def contract_from_file(self, file_name, main_func):
        tz_file_name = Path(file_name).with_suffix(".tz")
        return LigoContract(
            self.src_dir / file_name, self.out_dir / tz_file_name, main_func
        )


class LigoContract:
    def __init__(self, ligo_file, tz_file, main_func):
        """
        :param ligo_file: path to the contract LIGO source file.
        :param tz_file: path to the contract Michelson file to be compiled.
        :param main_func: name of the contract entry point function
        """
        self.ligo_file = ligo_file
        self.tz_file = tz_file
        self.main_func = main_func
        self.contract_interface = None

    def __call__(self):
        return self.get_contract()

    def compile_contract(self):
        """
        Force compilation of LIGO contract from source file and loads it into
        pytezos.
        :return: pytezos.ContractInterface
        """
        command = f"ligo compile-contract {self.ligo_file} {self.main_func}"
        michelson = self._ligo_to_michelson(command)
        self.tz_file.write_text(michelson)
        self.contract_interface = ContractInterface.create_from(michelson)
        return self.contract_interface

    def get_contract(self):
        """
        Returns pytezos contract. If it is not loaded et, compiles it from LIGO
        source file.
        :return: pytezos.ContractInterface
        """
        if self.contract_interface:
            return self.contract_interface
        else:
            return self.compile_contract()

    def compile_storage(self, ligo_storage):
        """
        Compiles LIGO encoded storage to Python object to be used with pytezos.
        :return:  object
        """
        command = (
            f"ligo compile-storage {self.ligo_file} {self.main_func} '{ligo_storage}'"
        )
        michelson = self._ligo_to_michelson_sanitized(command)
        c = self.get_contract()
        return c.contract.storage.decode(michelson)

    def compile_parameter(self, ligo_parameter):
        """
        Compiles LIGO encoded storage to Python object to be used with pytezos.
        :param ligo_parameter: LIGO string encoding entry point and parameter
        :return: object:
        """
        command = f"ligo compile-parameter {self.ligo_file} {self.main_func} '{ligo_parameter}'"
        michelson = self._ligo_to_michelson_sanitized(command)
        c = self.get_contract()
        return c.contract.parameter.decode(michelson)

    def _ligo_to_michelson(self, command):
        with Popen(command, stdout=PIPE, stderr=PIPE, shell=True) as p:
            with TextIOWrapper(p.stdout) as out, TextIOWrapper(p.stderr) as err:
                michelson = out.read()
                if not michelson:
                    msg = err.read()
                    raise Exception(msg)
                else:
                    return michelson

    def _ligo_to_michelson_sanitized(self, command):
        michelson = self._ligo_to_michelson(command)
        return self._sanitize(michelson)

    def _sanitize(self, michelson):
        stripped = michelson.strip()
        if stripped.startswith("(") and stripped.endswith(")"):
            return stripped[1:-1]
        else:
            return stripped

    def originate(self, util, storage=None):
        """
        Originates contract on blockchain.
        :param util: PtzUtils wrapping pytezos client connected to Tezos RPC
        :param storage: initial storage python object
        :return: originated contract id
        """

        op = self.originate_async(util, storage)
        contract_id = util.wait_for_contracts(op)[0]

        return contract_id

    def originate_async(self, util, storage=None):
        """
        Originates contract on blockchain.
        :param util: PtzUtils wrapping pytezos client connected to Tezos RPC
        :param storage: initial storage python object
        :return: operation descriptor returned by inject()
        """
        c = self.get_contract()
        script = c.contract.script(storage=storage)
        counter = util.contract_counter()
        op = util.client.origination(script=script).autofill().sign().inject()
        util.wait_for_contract_counter(counter + 1)
        print("after orig: " + str(util.contract_counter()))
        return op


class PtzUtils:
    def __init__(self, client, wait_time=60, block_depth=5, num_blocks_wait=2):
        """
        :param client: PyTezosClient
        :param block_time: block baking time in seconds
        """
        self.client = client
        self.wait_time = wait_time
        self.block_depth = block_depth
        self.num_blocks_wait = num_blocks_wait

    def wait_for_ops(self, *ops):
        """
        Waits for specified operations to be completed successfully.
        If any of the operations fails, raises exception.
        :param *ops: list of operation descriptors returned by inject()
        """

        for _ in range(self.num_blocks_wait):
            self.client.shell.wait_next_block(block_time=self.wait_time)
            res = [self._check_op(op) for op in ops if op]
            if len(ops) == len(res):
                return res

        raise TimeoutError("waiting for operations")

    def wait_for_contracts(self, *ops):
        """
        Waits for specified contracts to be originated successfully.
        :param *ops: list of operation descriptors returned by inject()
        :return: corresponding list of contract ids
        """
        res = self.wait_for_ops(ops)

        def get_contract_id(op):
            return op["contents"][0]["metadata"]["operation_result"][
                "originated_contracts"
            ][0]

        return [get_contract_id(op) for op in res]

    def _check_op(self, op):
        """
        Returns None if operation is not completed
        Raises error if operation failed
        Return operation result if operation is completed
        """

        op_data = op[0] if isinstance(op, tuple) else op
        op_hash = op_data["hash"]
        op_source = op_data["contents"][0]["source"]
        source = self.client.key.public_key_hash()
        assert (
            source == op_source
        ), f"operation from different source. Expected '{source}' actual '{op_source}'"

        blocks = self.client.shell.blocks[-self.block_depth :]
        try:
            res = blocks.find_operation(op_hash)
            if not OperationResult.is_applied(res):
                raise RpcError.from_errors(OperationResult.errors(res)) from op_hash
            return res
        except StopIteration:
            # not found
            return None

    def contract_counter(self):
        source = self.client.key.public_key_hash()
        counter = self.client.shell.contracts[source].count()
        return next(counter)

    # quick and dirty polling of the node to increase contract counter
    def wait_for_contract_counter(self, cnt):
        poll_time_sec = 0.0
        while poll_time_sec < self.wait_time * 2:
            counter = self.contract_counter()
            if counter == cnt:
                print(f"waited for counter update for {poll_time_sec}sec")
                return
            sleep(1)
            poll_time_sec += 1
        raise TimeoutError("waiting for contract counter")


flextesa_sandbox = pytezos.using(
    shell="http://localhost:20000",
    key="edsk3RFgDiCt7tWB2oe96w1eRw72iYiiqZPLu9nnEY23MYRp2d8Kkx",
)

