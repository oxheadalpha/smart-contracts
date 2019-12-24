# Multi Asset Contract Standard

Specification for Tezos multi-asset contract adapted from the corresponding
specification for [Ethereum](https://eips.ethereum.org/EIPS/eip-1155).

## Project Structure

* `multi_asset.md` - standard specification
* `multi_token_interface.mligo` - multi-asset contract interfaces defined in
[LIGO](https://ligolang.org/), smart-contract language for Tezos
* `impl` folder - reference implementation of the multi-asset contract, test helper
contracts and code.
* `out` folder - multi-assert contract and helper contract compiled into Michelson
* `tezos_mac_tests` folder - Python multi_asset contract tests implemented with
[Pytezos](https://github.com/baking-bad/pytezos) and
[unittest](https://docs.python.org/3/library/unittest.html).

## Test Dependencies

### LIGO

Install LIGO docker image by running the following command:

`curl https://gitlab.com/ligolang/ligo/raw/dev/scripts/installer.sh | bash -s "next"`

See [LIGO installation](https://ligolang.org/docs/intro/installation/) instructions
for more details or alternative installation options.

### Python3

To run the test, Python 3.6+ and pip 19.0.1+ are required.

### Cryptographic Libraries For Pytezos

Pytezos can be installed as `tezos_mac_tests` module dependency, but it requires
to install several cryptographic packages first.

See [Pytezos requirements](https://github.com/baking-bad/pytezos#requirements).

#### Linux

Use apt or your favourite package manager:

`$ sudo apt install libsodium-dev libsecp256k1-dev libgmp-dev`

#### MacOS

Use homebrew:

```
$ brew tap cuber/homebrew-libsecp256k1
$ brew install libsodium libsecp256k1 gmp
```

### Flextesa Sanbox

Tests are configured to run on [Flextesa sandbox](https://assets.tqtezos.com/sandbox-quickstart).
There are two helper scripts in `tezos_mac_tests` module:

* `start-sandbox.sh` - starts Flextesa sandbox from docker image
* `kill-sandbox.sh` - kills running Flextesa sandbox docker container

## Installation and Running The Tests

### Install dependencies

#### LIGO 

`curl https://gitlab.com/ligolang/ligo/raw/dev/scripts/installer.sh | bash -s "next"`

#### Cryptographic libraries

```
$ brew tap cuber/homebrew-libsecp256k1
$ brew install libsodium libsecp256k1 gmp
```

### Create Python virtual environment

```
python3 -m venv tezos_mac_tests_env
source tezos_mac_tests_env/bin/activate
```

### Install `tezos_mac_tests` Python module

```
git clone https://github.com/tqtezos/smart-contracts.git
cd smart-contracts/multi_asset
pip install -e .
```

Alternatively, you can install it directly from Github:

`pip3 install -e "git+https://github.com/tqtezos/smart-contracts.git#subdirectory=multi_asset&egg=tezos_mac_tests"`

It will install Pytezos dependencies as well.

### Start Tezos Sandbox

`tezos_mac_tests/start-sandbox.sh`

Alternative command:

`docker run --rm --name flextesa-sandbox --detach -p 20000:20000 registry.gitlab.com/tezos/flextesa:image-babylonbox-run babylonbox start`

When running for the first time, it will download sandbox docker image.
It may take a few seconds until sandbox is bootstrapped.

### Run The Tests

`python -m unittest discover tezos_mac_tests`
