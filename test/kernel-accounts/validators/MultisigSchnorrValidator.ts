import { AuthWitness } from "@aztec/circuit-types";
import { Schnorr } from "@aztec/circuits.js/barretenberg";
import { Fr } from "@aztec/foundation/fields";
import { AztecAddress, GrumpkinPrivateKey } from "@aztec/circuits.js";
import {
	MODE_CUSTOM,
	MODE_DEFAULT,
	ValidatorInterface,
	padDeploymentArgs,
	padWitness,
} from "./ValidatorInterface.js";

export class MultisigSchnorrValidator implements ValidatorInterface {
	// private signatures: Buffer;

	constructor(
		private address: AztecAddress,
		private owners: AztecAddress[],
		private signingPrivateKeys: GrumpkinPrivateKey[],
		private threshold: Number
	) {
		if (owners.length != signingPrivateKeys.length) {
			throw "different length between owners and signingPrivateKeys";
		}
	}

	getValidatorAddress(): AztecAddress {
		return this.address;
	}

	getValidatorSigningKey(): GrumpkinPrivateKey[] {
		return this.signingPrivateKeys;
	}

	getDeploymentArgs() {
		const signingPublicKeys = this.signingPrivateKeys
			.map((key) => new Schnorr().computePublicKey(key)) // Compute public keys
			.map((point) => point.toFields()) // Convert each Point to [x, y]
			.flat();

		console.log("signingPublicKeys: ", signingPublicKeys);

		return [this.address, padDeploymentArgs(signingPublicKeys)];
	}

	// addSignature()

	createAuthWit(messageHash: Fr, isDefault: boolean): Promise<AuthWitness> {
		const schnorr = new Schnorr();
		const messageBuffer = messageHash.toBuffer();
		const signatures = this.signingPrivateKeys.map((key) =>
			schnorr.constructSignature(messageBuffer, key).toBuffer()
		);

		// const signature = [
		// 	new Fr(signatures.length),
		// 	new Fr(0),
		// 	...signatures[0],
		// 	new Fr(1),
		// 	...signatures[1],
		// ];
		let signature = [new Fr(signatures.length).toBuffer()];

		signatures.forEach((sig, index) => {
			signature.push(new Fr(index).toBuffer());
			signature.push(sig);
		});

		// Flatten the signature array to a single Buffer
		const finalBuffer = Buffer.concat(signature);

		// const combinedBuffers = [];
		// for (let i = 0; i < signatures.length; i++) {
		// 	combinedBuffers.push(i);
		// 	combinedBuffers.push(signatures[i]);
		// }

		// const finalBuffer = Buffer.concat(combinedBuffers);
		// let signature = [
		// 	new Fr(signatures.length),
		// 	new Fr(0),
		// 	...signatures[0],
		// 	new Fr(1),
		// 	...signatures[1],
		// ];

		const prefix = isDefault
			? [MODE_DEFAULT]
			: [MODE_CUSTOM, this.address.toField()];

		const witness = padWitness([...prefix, ...finalBuffer]);

		return Promise.resolve(new AuthWitness(messageHash, witness));
	}
}
