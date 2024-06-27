# Modular Smart Account on Aztec

Aztec supports native Account Abstraction at the protocol level. Every account is a smart contract that can incorporate arbitrary signature validation logic and other extensible features. This MSA(modular smart account) example leverages it to implement a modular smart account where multiple different validation schemes can be flexibly added/removed to an account.

The account contract called KernelAccount ( inspired by [ZeroDev](https://docs.zerodev.app/) ) doesn't implement any validation logic but can store multiple validator addresses that are called by the account contract during the validation phase. It should set one default validator at deployment, and nothing stops it from adding other custom validators later to customize its authorization scheme.

For example, a user can set the ECDSA k256 module by default, add the ECDSA P256 module for signing transactions with a fingerprint on mobile, and also use the multi-sig module for social recovery. Also, it's possible to develop a new validator module, install it into their accounts, and start using it right away.

## Validator module contracts

| Validator             | Details                                   |
| --------------------- | ----------------------------------------- |
| EcdsaK256Module       | secp256k1 with ECDSA algorithm            |
| EcdsaP256Module       | secp256r1 with ECDSA algorithm            |
| SchnorrModule         | Schnorr signature over Grumpkin curve     |
| EddsaBjjModule        | EDDSA algorithm over Baby Jubjub curve    |
| MultisigSchnorrModule | Mulitisg with Schnorr signature algorithm |

## Develop

fork:

```shell
git clone git@github.com:porco-rosso-j/aztec-modular-smart-account.git
cd aztec-modular-smart-account
```

run sandbox:

```shell
cd .docker
aztec-sandbox
```

install dependencies:

```shell
yarn
```

test:

```shell
yarn test
```

## References

- [ERC7579](https://erc7579.com/)
- [ZeroDev](https://zerodev.app/)
- [Rhinestone](https://www.rhinestone.wtf/)

## TODO

- implement other module types executors, hooks, fallbacks
- make test/kernel a npm package
- integrate session-account-action into kernelAccount and tests
- consider implementing 2D nonce
