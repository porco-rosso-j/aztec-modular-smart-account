import { type PXE } from "@aztec/circuit-types";
import { type Fr } from "@aztec/circuits.js";
import { KernelAccountInterface } from "./KernelAccountInterface.js";
import { AccountWallet } from "@aztec/aztec.js";
import { Salt } from "@aztec/aztec.js/account";

/**
 * Extends {@link AccountWallet} with the encryption private key. Not required for
 * implementing the wallet interface but useful for testing purposes or exporting
 * an account to another pxe.
 */
export class KernelAccountWalletWithKey extends AccountWallet {
	constructor(
		pxe: PXE,
		account: KernelAccountInterface,
		private secretKey: Fr,
		/** Deployment salt for this account contract. */
		public readonly salt: Salt
	) {
		super(pxe, account);
	}

	/** Returns the encryption private key associated with this account. */
	public getSecretKey() {
		return this.secretKey;
	}

	// TODO: implement
	// public async getNonce(): Promise<Fr>
	// install authenticator
	// uninstall authenticator
	// switch authenticator
}
