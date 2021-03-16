# Fractional Ownership NFT

Fractional ownership of any generic NFT token is controlled by the ownership DAO
contract. DAO manages special FA2 fungible ownership tokens. For each NFT owned
by DAO, it creates a new ownership fungible token and allocate its supply to other
addresses according to a fractional ownership.

Fractional owners may vote to transfer NFT token from DAO to some other address.
Their votes are proportional to their balances of the linked fungible ownership
token. Once, voting threshold is met, the DAO transfers NFT token and destroys
linked fungible ownership token.

## Entities

**NFT token** - any generic implementation of an FA2 NFT token that can be
transferred between any addresses.

**Ownership DAO** - a contract that can own any generic NFT token and control
their transfer to any other address using fractional ownership logic.

**Ownership token** - a fungible FA2 token created and managed within the
ownership DAO. For each owned NFT, DAO creates a linked ownership token and
allocates its balances to fractional owners.

**Fractional owner** - an address which owns a fraction of NFT managed by the DAO.
Fraction of ownership is represented by the balance of the linked ownership token
allocated to the fractional owner. Fractional owner can vote to transfer
an NFT to some other address.


## Operations

**Setup NFT ownership** - to setup NFT fractional ownership it is required:

1. Transfer NFT to the ownership DAO address
2. Create linked ownership fungible token and allocate its supply within the DAO

**Vote on NFT transfer** - any fractional owner can submit a vote consisting of
a transfer descriptor (NFT ID and destination transfer address) and a nonce.
The vote weight is proportional to a balance of the linked ownership token allocated
to a fractional owner. Once predefined voting threshold is met, DAO transfers NFT
token and destroys linked ownership token.

**Transfer ownership tokens** - Since ownership tokens managed by the DAO are regular
FA2 fungible tokens, fractional owners can transfer them using regular FA2 transfer.

## DAO Entry Points

### %set_ownership

Mints new linked ownership token and allocates fractional ownership

```
%set_ownership {
  nft_contract : address;
  nft_token_id : nat;
  ownership_token_id : nat;
  ownership : {amount : nat; owner : address} list;
  vote_threshold : nat
}
```

### %vote_transfer

To be called by the fractional owner to vote of NFT transfer from DAO to some
other destination address.

```ocaml
%vote_transfer {
  nft_contract: address;
  nft_token_id: nat;
  to_: address;
  nonce: nat;
}
```

### Standard FA2 entry points for ownership tokens

`%transfer`

`balance_of`

`update_operators`
