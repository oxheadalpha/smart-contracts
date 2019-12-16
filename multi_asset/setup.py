#!/usr/bin/env python

from distutils.core import setup

setup(
    name="tezos-mac-tests",
    version="1.0",
    description="Multi Asset Contract Tests",
    packages=["mactest"],
    install_requires=["pytezos"],
    include_package_data=True,
)

