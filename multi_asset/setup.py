#!/usr/bin/env python

from distutils.core import setup

setup(
    name="tezos-mac-tests",
    version="1.0",
    description="Multi Asset Contract Tests",
    packages=["test"],
    install_requires=["pytezos"]
)

