/**
 * The `@aztec/accounts/ecdsa` export provides an ECDSA account contract implementation, that uses an ECDSA private key for authentication, and a Grumpkin key for encryption.
 * Consider using this account type when working with integrations with Ethereum wallets.
 *
 * @packageDocumentation
 */
import { AccountManager, type Salt } from "@aztec/aztec.js/account";
import { type PXE } from "@aztec/circuit-types";
import { Fr } from "@aztec/circuits.js";

import {
	KernelAccountContract,
	KernelAccountContractArtifact,
} from "./KernelAccountContract.js";
import { KernelAccountWalletWithSecretKey } from "./KernelAccountWallet.js";
import { KernelAccount } from "./KernelAccount.js";
import { KernelAuthWitnessProviderInterface } from "./validators/KernelAuthWitnessProvider.js";
import {
	KernelNonceProvider,
	KernelNonceProviderInterface,
} from "./entrypoint/KernelNonceProvider.js";
export { KernelAccountContractArtifact } from "../artifacts/KernelAccount.js";
export { KernelAccountContract };

/**
 * Creates an Kernel Account.
 * @param pxe - An PXE server instance.
 * @param secretKey - Secret key used to derive all the keystore keys.
 * @param defaultValidator - default validator used for signing transactions.
 * @param salt - Deployment salt.
 */
export function getKernelAccount(
	pxe: PXE,
	secretKey: Fr,
	authWitnessProvider: KernelAuthWitnessProviderInterface,
	nonceProvider: KernelNonceProviderInterface,
	salt?: Salt
): AccountManager {
	return new AccountManager(
		pxe,
		secretKey,
		new KernelAccountContract(
			KernelAccountContractArtifact,
			authWitnessProvider,
			nonceProvider
		),
		salt
	);
}

// accountManager is for deployment
// instantiate AccountWallet afterwards
export async function deployAndGetKernelAccountWallet(
	pxe: PXE,
	secretKey: Fr,
	authWitnessProvider: KernelAuthWitnessProviderInterface,
	salt?: Salt
): Promise<KernelAccountWalletWithSecretKey> {
	const nonceProvider = new KernelNonceProvider(pxe);
	const accountManager: AccountManager = getKernelAccount(
		pxe,
		secretKey,
		authWitnessProvider,
		nonceProvider,
		salt
	);

	console.log(
		"getCurrentValidator: ",
		authWitnessProvider.getCurrentValidator()
	);
	console.log(
		"getDefaultValidator: ",
		authWitnessProvider.getDefaultValidator().getValidatorAddress()
	);

	const deployedAccount = await accountManager.deploy().wait();

	return new KernelAccountWalletWithSecretKey(
		pxe,
		new KernelAccount(
			authWitnessProvider,
			nonceProvider,
			deployedAccount.wallet.getCompleteAddress(),
			await pxe.getNodeInfo()
		),
		secretKey,
		accountManager.salt
	);
}
