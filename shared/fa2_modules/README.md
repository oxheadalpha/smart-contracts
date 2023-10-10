Reusable modules to use as part of FA2 implementation.

## `simple_admin`

One of the possible implementations of admin API for FA2 contract.
The admin API can change an admin address using two step confirmation pattern and
pause/unpause the contract. Only current admin can initiate those operations.

Other entry points may guard their access using helper functions
`fail_if_not_admin` and `fail_if_paused`.

### `simple_admin_wrapper`

The `simple_admin_wrapper` contract includes the `simple_admin` module,
exposing the functions `fail_if_not_admin` and  `fail_if_paused` as entrypoints:

```ocaml
type wrapper_storage = Admin.storage

[@entry] let admin (p : Admin.entrypoints) (s : wrapper_storage) = ...

[@entry] let fail_if_not_admin (_ : unit) (s : wrapper_storage) = ...

[@entry] let fail_if_paused  (_ : unit) (s : wrapper_storage) = ...
```

The contract is located in [`test/`](test/simple_admin_wrapper.mligo)
and it can be compiled to Michelson using the following command from `shared`
directory:

```bash
ligo compile contract fa2-modules/test/simple_admin_wrapper.mligo \
  --module SimpleAdminWrapper \
  --output-file fa2-modules/test/out/simple_admin_wrapper.tz
```

Or, using `docker`:

```bash
docker run --rm -v "$PWD":"$PWD" -w "$PWD" ligolang/ligo:1.0.0 compile contract \
  fa2-modules/test/simple_admin_wrapper.mligo \
  --module SimpleAdminWrapper \
  --output-file fa2-modules/test/out/simple_admin_wrapper.tz
```
