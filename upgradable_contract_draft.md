# Upgradable Tezos Contracts (design pattern)

## Introduction

Upgrading deployed smart contract should not break existing **contract clients**
(either other deployed contracts which call this contract and/or different client
tools and DApps which call the smart contract using RPC API).

This proposal ensure the following backward compatibility features:

1. Old **contract address** does not change with the upgrade.
2. Changing contract **implementation** code (w/o changing the entry points) does
not break existing contract clients
3. Adding new **entry points** (extending the contract) does not break existing
contract clients)
4. Changing **contract storage** structure does not break existing contract clients.
5. This design pattern is not resilient to **entry point** removal
6. Proposed implementation is type safe.

## Assumptions

There are following types of changes (upgrades) to the existing contract which
are supported:

1. Changing implementation of existing entry point(s).
2. Adding new entry point(s) to extend contract functionality.
3. Change storage structure and implementation of existing entry points.

## Proposed design pattern

Contract implementation is split into two contracts: **dispatcher** contract
and **store** contract.

**Store** contract maintains upgradable contract state and supports one universal
entry point (there can be other entry points as well) which accepts lambda function
of type: `S -> ([operation], S)` where `S` is the type of storage. In other words,
this dynamic entry point accepts a lambda which encodes some business function which
accepts current contract state and returns new updates state and list of operations.
**Store** contract entry point passes state to a provided lambda and uses its result
as a result of contract invocation. **Store** contract also maintains a white list
of addresses which can call the **store**. Initially this list includes **dispatch**
contract only.

**Dispatcher** contract is implemented as following:
  
  1. Multiple entry points which define interface of the whole upgradable contract.
  2. Address of the **store** contract.
  3. **implementation table** (a record) where each field corresponds to a dispatcher's
  entry point and holds lambda with actual implementation. Each lambda has the following
  type: `A -> (S -> ([operation], S))` where `A` is an input parameter type of the
  corresponding entry point. `S` storage type of the **store** contract.
  4. **Redirect address**. **Dispatcher** can operate in two modes to support
  upgradability:
      1. Direct mode: use **implementation table** to invoke **store** contract.
      2. Redirect mode (**Redirect address** is set): forward all entry point calls
      to other **dispatcher**.
  5. **Dispatcher** implementation code for each entry point follows the same pattern:
      1. Check if **Redirect address** is set. If yes, forward call to other **dispatcher** corresponding entry point. Other **dispatcher** is a newer version of this one and has to support backward compatibility between entry points.
      2. Otherwise locate corresponding lambda in **implementation table**.
      3. Invoke lambda with the entry point parameter `A` and get another lambda
      `S -> ([operation], S)`.
      4. Invoke **store** contract with a new lambda.
  6. **Dispatcher** contract also has administration entry points to change address
  of the **store** contract, **implementation table** or set **redirect address**.

## Update scenarios

  For each scenario we start with the first version of deployed **dispatcher** and
  **store** contracts: `DC1` and `SC1`. **Store** contract storage type is `S1`.

### Scenario 1: Updating contract implementation

  We change only contract implementation code w/o changing storage type and/or
  entry points.

  This is the simple change: we just replace **implementation table** value in
  **dispatcher** contract. In other words we update only data, but not any deployed
  contract code.

  If there are more than one version of **dispatcher** are deployed, all affected
  dispatchers (which support updated entry points) need to be updated.

### Scenario 2: Adding new entry points

  Obviously we cannot change code of already deployed **dispatcher** contract `DC1`
  since it will change its address. Instead, we deploy another **dispatcher** `DC2`
  which implements both new and old entry points. Old **clients** which are not
  aware of new entry points will continue to call upgradable contract using
  **dispatcher** `DC1`. New **clients** will use **dispatcher** `DC2` which provides
  additional entry points (interface extension). White list of **store**
  contract `SC1` needs to include addresses for both dispatchers `DC1` and `DC2`.

### Scenario 3: Changing storage type and storage migration

  To change storage type we need to create new **store** contract `SC2` with
  storage type `S2`. Internal implementation of `SC2` may have a reference to
  an old store `SC1` and use *lazy upgrade* pattern to migrate the data gradually.
  `SC2` will have universal entry point which accepts lambda of type
  `S2 -> ([operation], S2)`.

  We also need to create a new **dispatcher** `DC2` which **implementation table**
  holds lambdas of type `A -> (S2 -> ([operation], S2))` and points to **store** `SC2`.
  `DC2` entry points need to be backward compatible with entry points of the previous
  **dispatcher implementation** `DC1`.

  All previous versions of contract **dispatchers** (including `DC1`) should be
  redirected to **dispatcher** `DC2` instead of using their own **implementation table**.
  **Store** `SC1` can be called only by `SC2` which implements lazy upgrade pattern.

### Conclusion

  Scenarios 1-3 represent minimal basis required to implement upgrade operations.
  Real life upgrades may require combination of those scenarios.

## Implementation of *lazy store upgrade* pattern on Tezos

  The general idea is that any business operation executed on a new storage tries to get
  needed resource from this new storage and if resource is not available, it falls back
  and retrieves it from the old storage. Since calls to a Tezos contract cannot return a value,
  we need to use continuation style (pass a callback lambda).

  We start with the original *store* contract `SC1` which has storage type `S1`. Let's `R` be a type
  of the resource which needs to support *lazy upgrade* and `K` be a type of key to access such
  a resource (Usually, lazy upgradable resource will be stored in `lazy_map(K, R)` inside storage
  `S1`). To support future upgradability, store `SC1` has an additional entry point:
  `getR: (K, (K, R) -> operation)`. The second parameter is a callback lambda which takes retrieved
  resource `R` and provided key `K` and returns an operation which calls back the original contract.

  Implementation of upgraded version of the contract will have upgraded *store* `SC2` with storage
  type `S2`. Upgraded store also supports resource `R` accessible by key `K`, but the actual data is
  migrated from `SC1` lazily, only when business operation tries to access a resource for the first time. Signature of the business operation lambda for the new *store* is `S2 -> ([operation], S2)`.
  But internal implementation is broken into two parts: `computeR: S1 -> (S1, K, R option)` and
  `continue: (S1, K, R) -> ([operation], S1)`. The glue pseudo-code looks as following:

  ```ocaml
    let (s2_1, k, r) = computeR(s2_0)
    match r with
      Some(x) -> continue(s2_1, k, x)
      None    ->
        let callback = (k1, r1) -> call(SC2, dynamic_entry, s2 -> continue(s2, k1, r1))
        (s1_1, [call(SC1, getR, (k, callback)])

  ```

  `computeR` tries to retrieve required resource from the storage of the contract `SC2`.
  If the value is available, it simply passes it to the `continue` lambda. If a resource is not
  available in `SC2`, the business operation calls `getR` entry point of the store contract `SC1`
  and passes a callback with will invoke `SC2` dynamic entry point with a lambda which embeds `continue` function.

  Such continuation style can be cumbersome when coded manually using low level programming
  languages like Michelson. But it would be relatively easy to implement and use such a pattern
  in high level languages that support monadic continuation syntax like `async/await` or
  Haskell-style  `do` notation.

## Possible optimization

  Proposed solution provides minimal basis to implement upgradable contracts.
  One of the drawbacks is that for each contract invocation **dispatcher** sends
  code of the lambda representing entry point implementation. Overtime, this can
  incur significant gas cost.

  One of the possible optimization is to implement business logic entry points
  in the **store** contract in addition to a dynamic entry point. The **dispatcher**
  can directly invoke them until they get "patched" with upgraded lambda implementation
  which then passes to the dynamic entry point.
  Assuming that upgrades do not happen often and if happen, only a few entry points
  get upgraded, the majority of calls to an upgradable contract will not pass large
  lambdas as parameters to store contract calls. Although, such optimization
  significantly complicate contract implementation.
