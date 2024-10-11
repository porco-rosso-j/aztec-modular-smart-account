/**
 * The `@aztec/accounts/ecdsa` export provides an ECDSA account contract implementation, that uses an ECDSA private key for authentication, and a Grumpkin key for encryption.
 * Consider using this account type when working with integrations with Ethereum wallets.
 *
 * @packageDocumentation
 */
import { AccountManager, type Salt } from "@aztec/aztec.js/account";
import { type AccountWallet, getWallet } from "@aztec/aztec.js/wallet";
import { type PXE } from "@aztec/circuit-types";
import { type AztecAddress, type Fr } from "@aztec/circuits.js";

import {
	KernelAccountContract,
	KernelAuthWitnessProviderInterface,
} from "./KernelAccountContract.js";
import { KernelAccountContractArtifact } from "../artifacts/KernelAccount.js";
import { KernelAccountWalletWithKey } from "./KernelAccountWalletWithKey.js";
import { KernelAccountInterface } from "./KernelAccountInterface.js";
export { KernelAccountContractArtifact };

/**
 * Creates an Account that relies on an ECDSA signing key for authentication.
 * @param pxe - An PXE server instance.
 * @param secretKey - Secret key used to derive all the keystore keys.
 * @param signingPrivateKey - Secp256k1 key used for signing transactions.
 * @param salt - Deployment salt.
 */
export function getKernelAccount(
	pxe: PXE,
	secretKey: Fr,
	authenticator: KernelAuthWitnessProviderInterface,
	salt?: Salt
): AccountManager {
	return new AccountManager(
		pxe,
		secretKey,
		new KernelAccountContract(authenticator),
		salt
	);
}

/**
 * Gets a wallet for an already registered account using ECDSA signatures.
 * @param pxe - An PXE server instance.
 * @param address - Address for the account.
 * @param signingPrivateKey - ECDSA key used for signing transactions.
 * @returns A wallet for this account that can be used to interact with a contract instance.
 */
export function getKernelWallet(
	pxe: PXE,
	address: AztecAddress,
	authenticator: KernelAuthWitnessProviderInterface
): Promise<AccountWallet> {
	return getWallet(pxe, address, new KernelAccountContract(authenticator));
}

export async function deployAndGetKernelAccountWallet(
	pxe: PXE,
	secretKey: Fr,
	authWitnessProvider: KernelAuthWitnessProviderInterface,
	salt?: Salt
): Promise<KernelAccountWalletWithKey> {
	const accountManager: AccountManager = getKernelAccount(
		pxe,
		secretKey,
		authWitnessProvider,
		salt
	);

	const deployedAccount = await accountManager.deploy().wait();

	return new KernelAccountWalletWithKey(
		pxe,
		new KernelAccountInterface(
			authWitnessProvider,
			deployedAccount.wallet.getCompleteAddress(),
			await pxe.getNodeInfo()
		),
		secretKey,
		accountManager.salt
	);
}
