import { PXE, SignerlessWallet, createPXEClient } from "@aztec/aztec.js";
import { AztecAddress, CompleteAddress, Fr } from "@aztec/circuits.js";
import { KernelAccountContract } from "../../artifacts/KernelAccount.js";

export interface KernelNonceProviderInterface {
	getNonce(address: AztecAddress): Promise<Fr>;
}

export class KernelNonceProvider implements KernelNonceProviderInterface {
	constructor(private pxe: PXE) {}

	async getNonce(address: AztecAddress): Promise<Fr> {
		const kernelAccount = await KernelAccountContract.at(
			address,
			new SignerlessWallet(this.pxe)
		);

		return await kernelAccount.methods.get_nonce().simulate();
	}
}
