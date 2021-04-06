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
type wrapper_storage = {
  admin : simple_admin_storage;
}

type wrapper_param =
  | Admin of simple_admin
  | Fail_if_not_admin of unit
  | Fail_if_paused of unit
```

The contract is located in [`test/`](test/simple_admin_wrapper.mligo)
and it can be compiled to Michelson using the following command:

```bash
ligo compile-contract --syntax cameligo \
  --output-file=test/out/simple_admin_wrapper.tz \
  test/simple_admin_wrapper.mligo wrapper_main
```

Or, using `docker`:

```bash
docker run --rm -v "$PWD":"$PWD" -w "$PWD" ligolang/ligo:0.13.0 compile-contract \
  --syntax cameligo --output-file=test/out/simple_admin_wrapper.tz \
  test/simple_admin_wrapper.mligo wrapper_main
```

