import { AuthWitness } from "@aztec/circuit-types";
import { Ecdsa } from "@aztec/circuits.js/barretenberg";
import { Fr } from "@aztec/foundation/fields";
import { AztecAddress } from "@aztec/circuits.js";
import { padDeploymentArgs, padWitness } from "../utils/padder.js";
import { KernelAuthWitnessProviderInterface } from "../KernelAccountContract.js";

export class EcdsaKAuthenticator implements KernelAuthWitnessProviderInterface {
	constructor(
		private address: AztecAddress,
		private signingPrivateKey: Buffer
	) {}

	getAddress(): AztecAddress {
		return this.address;
	}

	getSigningPrivateKey(): Buffer {
		return this.signingPrivateKey;
	}

	getDeploymentArgs() {
		const signingPublicKey = new Ecdsa().computePublicKey(
			this.signingPrivateKey
		);

		return [this.address, padDeploymentArgs(signingPublicKey)];
	}

	createAuthWit(messageHash: Fr): Promise<AuthWitness> {
		const signature = new Ecdsa().constructSignature(
			messageHash.toBuffer(),
			this.signingPrivateKey
		);

		const witness = padWitness([this.address, ...signature.r, ...signature.s]);
		return Promise.resolve(new AuthWitness(messageHash, witness));
	}
}
