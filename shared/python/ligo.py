from pathlib import Path
import os
from subprocess import Popen, PIPE
from io import TextIOWrapper
from time import sleep

from pytezos import pytezos, ContractInterface, Key
from pytezos.operation.result import OperationResult
from pytezos.rpc.errors import RpcError
from pytezos.operation import fees

ligo_version = "0.7.1"
ligo_cmd = (
    f'docker run --rm -v "$PWD":"$PWD" -w "$PWD" ligolang/ligo:{ligo_version} "$@"'
)


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
        command = f"{ligo_cmd} compile-contract {self.ligo_file} {self.main_func}"
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
        command = f"{ligo_cmd} compile-storage {self.ligo_file} {self.main_func} '{ligo_storage}'"
        michelson = self._ligo_to_michelson_sanitized(command)
        c = self.get_contract()
        return c.contract.storage.decode(michelson)

    def compile_parameter(self, ligo_parameter):
        """
        Compiles LIGO encoded storage to Python object to be used with pytezos.
        :param ligo_parameter: LIGO string encoding entry point and parameter
        :return: object:
        """
        command = f"{ligo_cmd} compile-parameter {self.ligo_file} {self.main_func} '{ligo_parameter}'"
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
        :return: originated contract ContractInterface
        """

        c = self.get_contract()
        script = c.contract.script(storage=storage)
        op = (
            util.client.origination(script=script, balance=balance)
            .autofill()
            .sign()
            .inject()
        )
        op_r = util.wait_for_ops(op)[0]
        contract_id = op_r["contents"][0]["metadata"]["operation_result"][
            "originated_contracts"
        ][0]
        return util.client.contract(contract_id)


def get_consumed_gas(op_res):
    gs = (r["consumed_gas"] for r in OperationResult.iter_results(op_res))
    return [int(g) for g in gs]


def pformat_consumed_gas(op_res):
    gs = get_consumed_gas(op_res)
    if len(gs) == 1:
        return f"operation consumed gas: {gs[0]:,}"
    else:
        total = sum(gs)
        internal_ops_gas = [f"{g:,}" for g in gs]
        return f"operation consumed gas: {total:,} {internal_ops_gas}"


class PtzUtils:
    def __init__(self, client, block_depth=5, num_blocks_wait=3):
        """
        :param client: PyTezosClient
        :param block_depth number of recent blocks to test when checking for operation status
        :param num_blocks_wait number of backed blocks to retry wait until failing with timeout
        """
        self.client = client
        self.block_depth = block_depth
        self.num_blocks_wait = num_blocks_wait

    def using(self, shell=None, key=None):
        new_client = self.client.using(
            shell=shell or self.client.shell, key=key or self.client.key
        )
        return PtzUtils(
            new_client,
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
            try:
                self.client.shell.wait_next_block()
            except AssertionError:
                print("block waiting timed out")

        raise TimeoutError("waiting for operations")

    def transfer(self, to_address, amount):
        op = self.client.transaction(to_address, amount).autofill().sign().inject()
        self.wait_for_ops(op)

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
            print(pformat_consumed_gas(res))
            return res
        except StopIteration:
            # not found
            return None


flextesa_sandbox = pytezos.using(
    shell="http://localhost:20000",
    key=Key.from_encoded_key("edsk3RFgDiCt7tWB2oe96w1eRw72iYiiqZPLu9nnEY23MYRp2d8Kkx"),
)


def token_metadata_literal(token_id, symbol, name, decimals):
    bsymbol = symbol.encode().hex()
    bname = name.encode().hex()
    bdecimals = str(decimals).encode().hex()
    return """{
        token_id = %sn;
        token_info = Map.literal [
          ("symbol", 0x%s);
          ("name", 0x%s);
          ("decimals", 0x%s);
        ];
    }
    """ % (
        token_id,
        bsymbol,
        bname,
        bdecimals,
    )


def token_metadata_object(token_id, symbol, name, decimals):
    return {
        "token_id": token_id,
        "token_info": {
            # because of an issue with pytezos, the keys must be sorted alphabetically
            "decimals": str(decimals).encode().hex(),
            "name": name.encode().hex(),
            "symbol": symbol.encode().hex(),
        },
    }
