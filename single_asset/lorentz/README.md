
## Building

To build the Lorentz FA1.2, a.k.a. `ManagedLedger` contract, run:

```bash
make fa12
```

The result will be output to `out/fa12_lorentz.tz`

## Running

You can run the `morley-ledgers` executable using:

```bash
make run ARG="[morley-ledgers arguments]"
```

For example,

```bash
$ make run ARG="--help"
which stack || curl -sSL https://get.haskellstack.org/ | sh
/Users/michaelklein/.local/bin/stack
ls morley-ledgers || git clone https://gitlab.com/morley-framework/morley-ledgers.git
CONTRIBUTING.md          LICENSE   Makefile          README.md      cabal.project.freeze          cabal.project.license  code  nix      snapshot-stack2cabal.yaml  stack.yaml.lock
CONTRIBUTING.md.license  LICENSES  ManagedLedger.tz  cabal.project  cabal.project.freeze.license  ci.nix                 docs  scripts  stack.yaml                 stack.yaml.lock.license
cd morley-ledgers && git checkout e9ef09eefd476b07635d7052cf6f1916cd04063d
HEAD is now at e9ef09e Update morley-ledgers' README
cd morley-ledgers && stack build
cd morley-ledgers && stack exec morley-ledgers -- --help
Ledger contracts for Michelson

Usage: morley-ledgers [--version] COMMAND
  Ledger contracts registry

Available options:
  -h,--help                Show this help text
  --version                Show version.

Available commands:
  list                     Show all available contracts
  print                    Dump a contract in form of Michelson code
  document                 Dump contract documentation in Markdown
  analyze                  Analyze the contract and prints statistics about it.
  storage-AbstractLedger   Print initial storage for the contract
                           'AbstractLedger'
  storage-ManagedLedger    Print initial storage for the contract
                           'ManagedLedger'

You can use help for specific COMMAND
EXAMPLE:
  morley-ledgers print --help
```

## Testing

To test the Lorentz FA1.2, a.k.a. `ManagedLedger` contract, run:

```bash
make test
```

