from pathlib import Path
import os
from pytezos import ContractInterface


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
        self.ligo_file = ligo_file
        self.tz_file = tz_file
        self.main_func = main_func

    def compile(self):
        command = (
            f"ligo compile-contract {self.ligo_file} {self.main_func} > {self.tz_file}"
        )
        os.system(command)
        return ContractInterface.create_from(str(self.tz_file))
