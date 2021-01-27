#!/usr/bin/env python

from distutils.core import setup

setup(
    name="tezos_fa2_hooks_tests",
    version="1.3",
    description="Multi Asset With Hooks Contract Tests",
    packages=["tezos_fa2_hooks_tests"],
    install_requires=["pysodium", "secp256k1", "fastecdsa", "pytezos", "crypto"],
    include_package_data=True,
)
