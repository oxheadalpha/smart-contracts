import { TezosToolkit } from '@taquito/taquito';
import { Signer } from '@taquito/taquito/dist/types/signer/interface';
import { InMemorySigner } from '@taquito/signer';

type TestKeys = {
  bob: Signer;
  alice: Signer;
};

async function flextesaKeys(): Promise<TestKeys> {
  const bob = await InMemorySigner.fromSecretKey(
    'edsk3RFgDiCt7tWB2oe96w1eRw72iYiiqZPLu9nnEY23MYRp2d8Kkx'
  );
  const alice = await InMemorySigner.fromSecretKey(
    'edsk3QoqBuvdamxouPhin7swCvkQNgq4jP5KZPbwWNnwdZpSpJiEbq'
  );
  return { bob, alice };
}

async function testnetKeys(): Promise<TestKeys> {
  const bob = await InMemorySigner.fromSecretKey(
    'edskRfLsHb49bP4dTpYzAZ7qHCX4ByK2g6Cwq2LWqRYAQSeRpziaZGBW72vrJnp1ahLGKd9rXUf7RHzm8EmyPgseUi3VS9putT'
  );
  const alice = await InMemorySigner.fromSecretKey(
    'edskRqb8GgnD4d2B7nR3ofJajDU7kwooUzXz7yMwRdLDP9j7Z1DvhaeBcs8WkJ4ELXXJgVkq5tGwrFibojDjYVaG7n4Tq1qDxZ'
  );
  return { bob, alice };
}

export type TestTz = {
  bob: TezosToolkit;
  alice: TezosToolkit;
};

function signerToToolkit(signer: Signer, rpc: string): TezosToolkit {
  const tezos = new TezosToolkit(rpc);
  tezos.setProvider({
    signer,
    rpc
  });
  return tezos;
}

export async function bootstrap(): Promise<TestTz> {
  const { bob, alice } = await flextesaKeys();
  const rpc = 'http://localhost:20000';
  const bobTz = signerToToolkit(bob, rpc);

  return {
    bob: bobTz,
    alice: signerToToolkit(alice, rpc)
  };
}

export async function bootstrapTestnet(): Promise<TestTz> {
  const { bob, alice } = await testnetKeys();
  const rpc = 'https://testnet-tezos.giganode.io';
  return {
    bob: signerToToolkit(bob, rpc),
    alice: signerToToolkit(alice, rpc)
  };
}
