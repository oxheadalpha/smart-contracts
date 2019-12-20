from pathlib import Path
import os
from subprocess import Popen, PIPE
from io import TextIOWrapper
from time import sleep

from pytezos import pytezos, ContractInterface, Key
from pytezos.operation.result import OperationResult
from pytezos.rpc.errors import RpcError
from pytezos.operation import fees

fees.hard_gas_limit_per_operation = 800000


class LigoEnv:
    def __init__(self, src_dir, out_dir):
        self.src_dir = Path(src_dir)
        self.out_dir = Path(out_dir)

    def contract_from_file(self, file_name, main_func, tz_file_name=None):
        if tz_file_name:
            tz_file_name = Path(tz_file_name)
            if tz_file_name.suffix != ".tz":
                tz_file_name = tz_file_name.with_suffix(".tz")
        else:
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

    def originate(self, util, storage=None, balance=0):
        """
        Originates contract on blockchain.
        :param util: PtzUtils wrapping pytezos client connected to Tezos RPC
        :param storage: initial storage python object
        :return: originated contract id
        """

        op = self.originate_async(util, storage, balance)
        contract_id = util.wait_for_contracts(op)[0]

        return contract_id

    def originate_async(self, util, storage=None, balance=0):
        """
        Originates contract on blockchain.
        :param util: PtzUtils wrapping pytezos client connected to Tezos RPC
        :param storage: initial storage python object
        :return: operation descriptor returned by inject()
        """
        c = self.get_contract()
        script = c.contract.script(storage=storage)
        counter = util.contract_counter()
        op = (
            util.client.origination(script=script, balance=balance)
            .autofill()
            .sign()
            .inject()
        )
        util.wait_for_contract_counter(counter + 1)

        return op


class PtzUtils:
    def __init__(self, client, block_time=60, block_depth=5, num_blocks_wait=2):
        """
        :param client: PyTezosClient
        :param block_time: block baking time in seconds
        """
        self.client = client
        self.block_time = block_time
        self.block_depth = block_depth
        self.num_blocks_wait = num_blocks_wait

    def using(self, shell=None, key=None):
        new_client = self.client.using(
            shell=shell or self.client.shell, key=key or self.client.key
        )
        return PtzUtils(
            new_client,
            block_time=self.block_time,
            block_depth=self.block_depth,
            num_blocks_wait=self.num_blocks_wait,
        )

    def wait_for_ops(self, *ops):
        """
        Waits for specified operations to be completed successfully.
        If any of the operations fails, raises exception.
        :param *ops: list of operation descriptors returned by inject()
        """

        for _ in range(self.num_blocks_wait):
            chr = (self._check_op(op) for op in ops)
            res = [op_res for op_res in chr if op_res]
            if len(ops) == len(res):
                return res
            print(f"{len(res)} out of {len(ops)} operations are completed")
            try:
                self.client.shell.wait_next_block(block_time=self.block_time)
            except AssertionError:
                print("block waiting timed out")

        raise TimeoutError("waiting for operations")

    def wait_for_contracts(self, *ops):
        """
        Waits for specified contracts to be originated successfully.
        :param *ops: list of operation descriptors returned by inject()
        :return: corresponding list of contract ids
        """
        res = self.wait_for_ops(*ops)

        def get_contract_id(op):
            return op["contents"][0]["metadata"]["operation_result"][
                "originated_contracts"
            ][0]

        return [get_contract_id(op) for op in res]

    def transfer_async(self, to_address, amount):
        count = self.contract_counter()
        op = self.client.transaction(to_address, amount).autofill().sign().inject()
        self.wait_for_contract_counter(count + 1)
        return op

    def _check_op(self, op):
        """
        Returns None if operation is not completed
        Raises error if operation failed
        Return operation result if operation is completed
        """

        op_data = op[0] if isinstance(op, tuple) else op
        op_hash = op_data["hash"]

        blocks = self.client.shell.blocks[-self.block_depth :]
        try:
            res = blocks.find_operation(op_hash)
            if not OperationResult.is_applied(res):
                raise RpcError.from_errors(OperationResult.errors(res)) from op_hash
            for r in OperationResult.iter_results(res):
                print(f"operation consumed gas: {r['consumed_gas']}")
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
        poll_time_sec = 0
        while poll_time_sec < self.block_time * self.num_blocks_wait:
            counter = self.contract_counter()
            if counter == cnt:
                print(f"waited for counter update for {poll_time_sec}sec")
                return
            sleep(1)
            poll_time_sec += 1
        raise TimeoutError(
            f"waiting for contract counter {cnt}. Actual counter {counter}"
        )


flextesa_sandbox = pytezos.using(
    shell="http://localhost:20000",
    key=Key.from_encoded_key("edsk3RFgDiCt7tWB2oe96w1eRw72iYiiqZPLu9nnEY23MYRp2d8Kkx"),
)

