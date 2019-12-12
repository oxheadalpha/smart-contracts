from pathlib import Path
import os
from subprocess import Popen, PIPE
from io import TextIOWrapper
from pytezos import pytezos, ContractInterface


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

    def originate(self, client, storage=None):
        """
        Originates contract on blockchain.
        :param client: pytezos client connected to Tezos RPC
        :param storage: initial storage python object
        :return: originated contract address
        """
        c = self.get_contract()
        script = c.contract.script(storage=storage)
        op = client.origination(script=script).autofill().sign().inject()

        client.shell.wait_next_block()
        opg = client.shell.blocks[-1:].find_operation(op["hash"])
        contract_id = opg["contents"][0]["metadata"]["operation_result"][
            "originated_contracts"
        ][0]

        return contract_id


flextesa_sandbox = pytezos.using(
    shell="http://localhost:20000",
    key="edsk3RFgDiCt7tWB2oe96w1eRw72iYiiqZPLu9nnEY23MYRp2d8Kkx",
)

