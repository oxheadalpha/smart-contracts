#!/usr/bin/env python

from distutils.core import setup

setup(
    name="tezos_fa2_nft_tests",
    version="1.3",
    description="FA2 NFT Asset Contract Tests",
    packages=["tezos_fa2_nft_tests"],
    install_requires=["pysodium", "secp256k1", "fastecdsa", "pytezos", "crypto"],
    include_package_data=True,
)
