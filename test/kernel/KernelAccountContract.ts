import { AccountInterface } from "@aztec/aztec.js/account";
import { type CompleteAddress } from "@aztec/circuit-types";
import { type ContractArtifact } from "@aztec/foundation/abi";
import { KernelAccount } from "./KernelAccount.js";
import { AccountContract, NodeInfo } from "@aztec/aztec.js";
import { KernelNonceProviderInterface } from "./entrypoint/KernelNonceProvider.js";
import { KernelAuthWitnessProviderInterface } from "./authwit/KernelAuthWitnessProvider.js";
export { KernelAccountContractArtifact } from "../artifacts/KernelAccount.js";

export class KernelAccountContract implements AccountContract {
	constructor(
		private artifact: ContractArtifact,
		private authWitnessProvider: KernelAuthWitnessProviderInterface,
		private nonceProvider: KernelNonceProviderInterface
	) {}

	getDeploymentArgs() {
		return this.authWitnessProvider.getDefaultValidator().getDeploymentArgs();
	}

	getContractArtifact(): ContractArtifact {
		return this.artifact;
	}

	getAuthWitnessProvider(
		address: CompleteAddress
	): KernelAuthWitnessProviderInterface {
		return this.authWitnessProvider;
	}

	getInterface(address: CompleteAddress, nodeInfo: NodeInfo): AccountInterface {
		return new KernelAccount(
			this.getAuthWitnessProvider(address),
			this.nonceProvider,
			address,
			nodeInfo
		);
	}
}
