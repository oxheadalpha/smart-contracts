# Multi Asset Contract

Implementation of the FA2 token contract (TZIP-12) for multiple fungible assets
that supports sender/receiver hooks. Receiver/sender hooks behavior is controlled
by the `permissions.sender` and `permissions.receiver` field
values initialized when the FA2 contract is originated. Since the permissions are
already represented on-chain as a contract storage field, they are not duplicated
in the contract metadata as required by TZIP-12/TZIP-16.

There are two example contracts that implement a receiver hook:

- `token_owner_with_hooks.mligo` tracks its own token balances within its own storage
- `token_sorter.mligo` forwards received tokens to other accounts according to its
  dispatch table.

## Project Structure

- [`multi_asset.md`](multi_asset.md) - description
- [`ligo`](ligo/) - contracts code defined in [LIGO](https://ligolang.org/),
  smart-contract language for Tezos.
  - [`ligo/fa2`](ligo/fa2/) - FA2 contract interfaces and libraries
  - [`ligo/fa2_modules`](ligo/fa2_modules/) - reusable contract implementation modules
  - [`ligo/fa2_clients`](ligo/fa2_clients/) - test client contracts interacting
    with FA2 contract
  - [`ligo/src`](ligo/src/) folder - reference implementation of the multi-asset
    FA2 contract, test helper contracts and code.
  - [`ligo/out`](ligo/out/) folder - multi-asset FA2 contract and helper contract
    compiled into Michelson.
- [`tezos_fa2_hooks_tests`](tezos_fa2_hooks_tests/) folder - Python multi_asset
  contract tests implemented with
  [Pytezos](https://github.com/baking-bad/pytezos) and
  [unittest](https://docs.python.org/3/library/unittest.html).

## Test Dependencies

### LIGO

If you are running the tests, the correct LIGO docker image version will be
downloaded automatically when used first time.

See [LIGO installation](https://ligolang.org/docs/intro/installation/) instructions
for more details or alternative installation options.

### Python3

To run the test, Python 3.6+ and pip 19.0.1+ are required.

### Cryptographic Libraries For Pytezos

Pytezos can be installed as `tezos_mac_tests` module dependency, but it requires
to install several cryptographic packages first.

See [Pytezos requirements](https://github.com/baking-bad/pytezos#requirements).

#### Linux

Use apt or your favorite package manager:

`$ sudo apt install libsodium-dev libsecp256k1-dev libgmp-dev`

#### MacOS

Use homebrew:

```
$ brew tap cuber/homebrew-libsecp256k1
$ brew install libsodium libsecp256k1 gmp
```

### Flextesa Sandbox

Tests are configured to run on [Flextesa sandbox](https://assets.tqtezos.com/sandbox-quickstart).
There are two helper scripts in `tezos_mac_tests` module:

- [`start-sandbox.sh`](tezos_mac_tests/start-sandbox.sh) - starts Flextesa sandbox
  from the docker image
- [`kill-sandbox.sh`](tezos_mac_tests/kill-sandbox.sh) - kills running Flextesa
  sandbox docker container

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
cd smart-contracts/fa2_hooks
pip install -e .
```

Alternatively, you can install it directly from Github:

`pip3 install -e "git+https://github.com/tqtezos/smart-contracts.git#subdirectory=mfa2_hooks&egg=tezos_fa2_hooks_tests"`

It will install Pytezos dependencies as well.

### Start Tezos Sandbox

`flextesa/start-sandbox.sh`

When running for the first time, it will download sandbox docker image.
It may take a few seconds until sandbox is bootstrapped.

### Run The Tests

`python -m unittest discover tezos_fa2_hooks_tests`
