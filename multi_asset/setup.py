#!/usr/bin/env python

from distutils.core import setup

setup(
    name="tezos_mac_tests",
    version="1.3",
    description="Multi Asset Contract Tests",
    packages=["tezos_mac_tests"],
    install_requires=["pysodium", "secp256k1", "fastecdsa", "pytezos", "crypto"],
    include_package_data=True,
)
