#!/usr/bin/env python

from distutils.core import setup

setup(
    name="tezos_mac_tests",
    version="1.0",
    description="Multi Asset Contract Tests",
    packages=["tezos_mac_tests"],
    install_requires=["pytezos", "crypto"],
    include_package_data=True,
)

