import { AuthWitnessProvider } from "@aztec/aztec.js/account";
import {
	type EntrypointInterface,
	type ExecutionRequestInit,
} from "@aztec/aztec.js/entrypoint";
import {
	type AuthWitness,
	type TxExecutionRequest,
} from "@aztec/circuit-types";
import {
	type AztecAddress,
	type CompleteAddress,
	Fr,
} from "@aztec/circuits.js";
import { type NodeInfo } from "@aztec/types/interfaces";
import { KernelAccountEntrypoint } from "./entrypoint/KernelAccountEntrypoint.js";
import { KernelNonceProviderInterface } from "./entrypoint/KernelNonceProvider.js";
import { KernelAuthWitnessProviderInterface } from "./authwit/KernelAuthWitnessProvider.js";

export interface KernelAccountInterface
	extends AuthWitnessProvider,
		EntrypointInterface,
		KernelNonceProviderInterface {
	getCompleteAddress(): CompleteAddress;

	/** Returns the address for this account. */
	getAddress(): AztecAddress;

	/** Returns the chain id for this account */
	getChainId(): Fr;

	/** Returns the rollup version for this account */
	getVersion(): Fr;

	getNonce(): Promise<Fr>;

	getAuthWitnessProvider(): KernelAuthWitnessProviderInterface;
}

/**
 * Default implementation for an account interface. Requires that the account uses the default
 * entrypoint signature, which accept an AppPayload and a FeePayload as defined in noir-libs/aztec-noir/src/entrypoint module
 */
export class KernelAccount implements KernelAccountInterface {
	private entrypoint: EntrypointInterface;
	private chainId: Fr;
	private version: Fr;

	constructor(
		private authWitnessProvider: KernelAuthWitnessProviderInterface,
		private nonceProvider: KernelNonceProviderInterface,
		private address: CompleteAddress,
		nodeInfo: Pick<NodeInfo, "chainId" | "protocolVersion">
	) {
		this.entrypoint = new KernelAccountEntrypoint(
			address.address,
			authWitnessProvider,
			this.nonceProvider,
			nodeInfo.chainId,
			nodeInfo.protocolVersion
		);

		this.chainId = new Fr(nodeInfo.chainId);
		this.version = new Fr(nodeInfo.protocolVersion);
	}

	createTxExecutionRequest(
		execution: ExecutionRequestInit
	): Promise<TxExecutionRequest> {
		return this.entrypoint.createTxExecutionRequest(execution);
	}

	createAuthWit(messageHash: Fr): Promise<AuthWitness> {
		return this.authWitnessProvider.createAuthWit(messageHash);
	}

	getCompleteAddress(): CompleteAddress {
		return this.address;
	}

	getAddress(): AztecAddress {
		return this.address.address;
	}

	async getNonce(): Promise<Fr> {
		return await this.nonceProvider.getNonce(this.address.address);
	}

	getChainId(): Fr {
		return this.chainId;
	}

	getVersion(): Fr {
		return this.version;
	}

	getAuthWitnessProvider(): KernelAuthWitnessProviderInterface {
		return this.authWitnessProvider;
	}
}
