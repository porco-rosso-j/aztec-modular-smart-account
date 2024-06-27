# Modular Smart Account on Aztec

Aztec supports native Account Abstraction at the protocol level. Every account is a smart contract that can incorporate arbitrary signature validation logic and other extensible features. This MSA(modular smart account) example leverages it to implement a modular smart account where multiple different validation schemes can be flexibly added/removed to an account.

This MSA, for example, allows users to create accounts that can customize signature validations. For example, users can set the ECDSA k256 module by default, add the ECDSA P256 module to sign transactions with a fingerprint on mobile and use the multi-sig module for social recovery. Anyone can develop a new validator module, install it into their accounts, and start using it right away.  

The KernelAccount contract itself doesn't implement validation logic, but stores validator addresses selectively called by the account contract for each transaction. Below are the supported modules. 


## Supported Validator module contracts

| Validator           | Details                                    |
| -----------------   | ------------------------------------------ |
| EcdsaK256Module   | secp256k1 with ECDSA algorithm               |
| EcdsaP256Module         | secp256r1 with ECDSA algorithm |
| SchnorrModule           |  Schnorr signature over Grumpkin curve |
| EddsaBjjModule        |  EDDSA algorithm over Baby JubJUb curve |
| MultisigSchnorrModule  | Mulitisg with Schnorr signature algorithm |
