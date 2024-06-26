import { AuthWitness } from "@aztec/circuit-types";
import { Schnorr } from "@aztec/circuits.js/barretenberg";
import { type Fr } from "@aztec/foundation/fields";
import { AztecAddress, GrumpkinPrivateKey } from "@aztec/circuits.js";
import { ValidatorInterface } from "../ValidatorInterface.js";
import { MODE_CUSTOM, MODE_DEFAULT } from "../constants.js";
import { padDeploymentArgs, padWitness } from "../padder.js";

export class SchnorrValidator implements ValidatorInterface {
	constructor(
		private address: AztecAddress,
		private signingPrivateKey: GrumpkinPrivateKey
	) {}

	getValidatorAddress(): AztecAddress {
		return this.address;
	}

	getValidatorSigningKey(): GrumpkinPrivateKey {
		return this.signingPrivateKey;
	}

	getDeploymentArgs() {
		const signingPublicKey = new Schnorr().computePublicKey(
			this.signingPrivateKey
		);

		return [
			this.address,
			padDeploymentArgs([signingPublicKey.x, signingPublicKey.y]),
		];
	}

	createAuthWit(messageHash: Fr, isDefault: boolean): Promise<AuthWitness> {
		const schnorr = new Schnorr();
		const signature = schnorr
			.constructSignature(messageHash.toBuffer(), this.signingPrivateKey)
			.toBuffer();

		const prefix = isDefault
			? [MODE_DEFAULT]
			: [MODE_CUSTOM, this.address.toField()];

		const witness = padWitness([...prefix, ...signature]);

		return Promise.resolve(new AuthWitness(messageHash, witness));
	}
}
