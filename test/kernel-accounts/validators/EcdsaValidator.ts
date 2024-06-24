import { AuthWitness } from "@aztec/circuit-types";
import { Ecdsa } from "@aztec/circuits.js/barretenberg";
import { Fr } from "@aztec/foundation/fields";

import { AztecAddress } from "@aztec/circuits.js";
import {
	MODE_CUSTOM,
	MODE_DEFAULT,
	ValidatorInterface,
	padDeploymentArgs,
	padWitness,
} from "./ValidatorInterface.js";

export class EcdsaValidator implements ValidatorInterface {
	constructor(
		private address: AztecAddress,
		private signingPrivateKey: Buffer
	) {}

	getValidatorAddress(): AztecAddress {
		return this.address;
	}

	getValidatorSigningKey(): Buffer {
		return this.signingPrivateKey;
	}

	getDeploymentArgs() {
		const signingPublicKey = new Ecdsa().computePublicKey(
			this.signingPrivateKey
		);

		return [this.address, padDeploymentArgs(signingPublicKey)];
	}

	createAuthWit(messageHash: Fr, isDefault: boolean): Promise<AuthWitness> {
		console.log("ecdsa messageHash: ", messageHash);
		console.log("isDefault: ", isDefault);
		const ecdsa = new Ecdsa();
		const signature = ecdsa.constructSignature(
			messageHash.toBuffer(),
			this.signingPrivateKey
		);

		const prefix = isDefault
			? [MODE_DEFAULT]
			: [MODE_CUSTOM, this.address.toField()];

		const witness = padWitness([...prefix, ...signature.r, ...signature.s]);
		console.log("witness len: ", witness.length);

		return Promise.resolve(new AuthWitness(messageHash, witness));
	}
}
