import { DefaultAccountContract } from "@aztec/accounts/defaults";
import { type CompleteAddress } from "@aztec/circuit-types";
import { type ContractArtifact } from "@aztec/foundation/abi";
import { KernelAccountContractArtifact } from "../artifacts/KernelAccount.js";
import { Fr, AuthWitness } from "@aztec/aztec.js";
import { AuthWitnessProvider } from "@aztec/aztec.js";

export interface KernelAuthWitnessProviderInterface
	extends AuthWitnessProvider {
	createAuthWit(messageHash: Fr): Promise<AuthWitness>;
	getDeploymentArgs(): any;
}

export class KernelAccountContract extends DefaultAccountContract {
	constructor(private authWitnessProvider: KernelAuthWitnessProviderInterface) {
		super(KernelAccountContractArtifact as ContractArtifact);
	}

	getDeploymentArgs() {
		return this.authWitnessProvider.getDeploymentArgs();
	}

	getAuthWitnessProvider(
		address: CompleteAddress
	): KernelAuthWitnessProviderInterface {
		return this.authWitnessProvider;
	}
}
