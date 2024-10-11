import {
	type AccountInterface,
	type AuthWitnessProvider,
} from "@aztec/aztec.js/account";
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
import { DefaultAccountEntrypoint } from "@aztec/entrypoints/account";
import { type NodeInfo } from "@aztec/types/interfaces";

/**
 * Default implementation for an account interface. Requires that the account uses the default
 * entrypoint signature, which accept an AppPayload and a FeePayload as defined in noir-libs/aztec-noir/src/entrypoint module
 */

// TODO 1: replace entrypoint with one that implements 2D nonce
// TODO 2: add get nonce method
export class KernelAccountInterface implements AccountInterface {
	private entrypoint: EntrypointInterface;
	private chainId: Fr;
	private version: Fr;

	constructor(
		private authWitnessProvider: AuthWitnessProvider,
		private address: CompleteAddress,
		nodeInfo: Pick<NodeInfo, "l1ChainId" | "protocolVersion">
	) {
		this.entrypoint = new DefaultAccountEntrypoint(
			address.address,
			authWitnessProvider,
			nodeInfo.l1ChainId,
			nodeInfo.protocolVersion
		);
		this.chainId = new Fr(nodeInfo.l1ChainId);
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

	getChainId(): Fr {
		return this.chainId;
	}

	getVersion(): Fr {
		return this.version;
	}
}
