import { AuthWitness } from "@aztec/circuit-types";
import { Schnorr } from "@aztec/circuits.js/barretenberg";
import { Fq, Fr } from "@aztec/foundation/fields";
import { AztecAddress, GrumpkinPrivateKey } from "@aztec/circuits.js";
import { ValidatorInterface } from "../ValidatorInterface.js";
import { MAX_OWNER_LEN, MODE_CUSTOM, MODE_DEFAULT } from "../constants.js";
import {
	padArray,
	padDeploymentArgs,
	padFrArray,
	padWitness,
} from "../padder.js";

export class MultisigSchnorrValidator implements ValidatorInterface {
	private owners: AztecAddress[];
	private signingPrivateKeys: GrumpkinPrivateKey[];
	private owners_len: number;

	constructor(
		private address: AztecAddress,
		owners: AztecAddress[],
		signingPrivateKeys: GrumpkinPrivateKey[],
		private threshold: number
	) {
		if (owners.length != signingPrivateKeys.length) {
			throw "different length between owners and signingPrivateKeys";
		}

		this.owners_len = owners.length;
		this.owners = padArray(owners, MAX_OWNER_LEN, AztecAddress.ZERO);
		this.signingPrivateKeys = padArray(
			signingPrivateKeys,
			MAX_OWNER_LEN,
			GrumpkinPrivateKey.ZERO
		);
	}

	getValidatorAddress(): AztecAddress {
		return this.address;
	}

	getValidatorSigningKey(): GrumpkinPrivateKey[] {
		return this.signingPrivateKeys;
	}

	getDeploymentArgs() {
		let signingPublicKeys: Fr[] = [];
		this.signingPrivateKeys.map((key) => {
			if (key != Fq.ZERO) {
				const point = new Schnorr().computePublicKey(key);
				signingPublicKeys.push(point.x);
				signingPublicKeys.push(point.y);
			}
		});

		signingPublicKeys = padFrArray(signingPublicKeys, 10);
		console.log("signingPublicKeys len: ", signingPublicKeys.length);

		const args: Fr[] = [
			new Fr(this.owners_len), // signer count
			new Fr(2), // thresdhold
			...this.owners.map((owner) => owner.toField()),
			...signingPublicKeys,
		];

		console.log("args: ", args.length);

		return [this.address, padDeploymentArgs(args)];
	}

	// addSignature()

	// todo: follow
	// index 0: mode
	// index 1: signer len
	// index 2~6: owners
	// index 7~: 64 * N signatures

	// and take mode into consideration.
	createAuthWit(messageHash: Fr, isDefault: boolean): Promise<AuthWitness> {
		const schnorr = new Schnorr();
		const messageBuffer = messageHash.toBuffer();
		let signatures: Fr[] = [];

		this.signingPrivateKeys.map((key, index) => {
			if (key != Fq.ZERO && index < this.threshold) {
				signatures.push(new Fr(index));
				const sig = Array.from(
					schnorr.constructSignature(messageBuffer, key).toBuffer()
				).map((num) => new Fr(num));
				console.log("sig len: ", sig.length);
				signatures.push(...sig);
			}
		});

		console.log("signatures len: ", signatures.length);

		const prefix = isDefault
			? [MODE_DEFAULT]
			: [MODE_CUSTOM, this.address.toField()];

		const witness = padWitness([
			...prefix,
			new Fr(this.threshold),
			...signatures,
		]);
		console.log("witness: ", witness.length);

		return Promise.resolve(new AuthWitness(messageHash, witness));
	}
}
