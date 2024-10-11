import { jest, beforeAll, it, describe } from "@jest/globals";
import {
	Fr,
	PXE,
	createPXEClient,
	AccountWalletWithSecretKey,
	TxStatus,
} from "@aztec/aztec.js";
import { Ecdsa } from "@aztec/circuits.js/barretenberg";
import { getDeployedTestAccountsWallets } from "@aztec/accounts/testing";
import { CounterContract } from "@aztec/noir-contracts.js";
import { SANDBOX_URL, TIMEOUT } from "./constants.js";
import { EcdsaKAuthenticator } from "../src/kernel/authenticators/EcdsaKAuthenticator.js";
import { KernelAccountWalletWithKey } from "../src/kernel/KernelAccountWalletWithKey.js";
import { EcdsaK256ModuleContract } from "../src/artifacts/EcdsaK256Module.js";
import { deployAndGetKernelAccountWallet } from "../src/kernel/index.js";
import { KernelAccountContract } from "../src/artifacts/KernelAccount.js";

// DEBUG=aztec:* yarn test test/kernel.test.ts

let pxe: PXE;
let ecdsaAuthenticatorContract: EcdsaK256ModuleContract;
let ecdsaAuthWitnessProvider: EcdsaKAuthenticator;
let deployer: AccountWalletWithSecretKey;
let kernelAccount: KernelAccountWalletWithKey;
let kernelAccountContract: KernelAccountContract;

let counter: CounterContract;
let ecdsaSigningKey: Buffer;

beforeAll(async () => {
	pxe = createPXEClient(SANDBOX_URL);
	deployer = (await getDeployedTestAccountsWallets(pxe))[0];
	console.log("deployer: ", deployer.getAddress());

	// const deployTestAccs = true;
	// if (deployTestAccs) {
	// 	await deployInitialTestAccounts(pxe);
	// }

	// deploy Validators
	ecdsaAuthenticatorContract = (
		await EcdsaK256ModuleContract.deploy(deployer).send().wait()
	).contract;

	console.log("ecdsaAuthenticator: ", ecdsaAuthenticatorContract.address);

	ecdsaSigningKey = new Fr(Fr.random().toBigInt() % Fr.MODULUS).toBuffer();

	ecdsaAuthWitnessProvider = new EcdsaKAuthenticator(
		ecdsaAuthenticatorContract.address,
		ecdsaSigningKey
	);

	// instantiate and deploy KernelAccount contract
	kernelAccount = await deployAndGetKernelAccountWallet(
		pxe,
		Fr.random(),
		ecdsaAuthWitnessProvider
	);

	console.log("kernelAccount: ", kernelAccount.getAddress());

	kernelAccountContract = await KernelAccountContract.at(
		kernelAccount.getAddress(),
		kernelAccount
	);
	console.log("kernelAccountContract: ", kernelAccountContract.address);

	counter = (
		await CounterContract.deploy(
			deployer,
			0,
			kernelAccount.getAddress(),
			kernelAccount.getAddress()
		)
			.send()
			.wait()
	).contract;

	console.log("counter: ", counter.address);
}, TIMEOUT);

describe("E2E Batcher setup", () => {
	jest.setTimeout(TIMEOUT);
	it("should successfully installed ecdsa authenticator", async () => {
		const isInstalled_Acc = await kernelAccountContract.methods
			.is_authenticator_installed(ecdsaAuthenticatorContract.address)
			.simulate();
		expect(isInstalled_Acc).toBe(true);

		const isInstalled_Mod = await ecdsaAuthenticatorContract.methods
			.is_installed(kernelAccount.getAddress())
			.simulate();
		expect(isInstalled_Mod).toBe(true);

		const signingPublicKey = new Ecdsa().computePublicKey(
			ecdsaAuthWitnessProvider.getSigningPrivateKey()
		);

		console.log("signingPublicKey: ", signingPublicKey);

		const public_keys = await ecdsaAuthenticatorContract.methods
			.view_public_keys(kernelAccount.getAddress())
			.simulate();

		console.log("public_keys: ", public_keys);
	});

	it("transact with default validator", async () => {
		const countBefore = await counter.methods
			.get_counter(kernelAccount.getAddress())
			.simulate();

		console.log("countBefore: ", countBefore);

		const tx = await counter
			.withWallet(kernelAccount)
			.methods.increment(kernelAccount.getAddress(), kernelAccount.getAddress())
			.send()
			.wait();

		expect(tx.status).toBe(TxStatus.SUCCESS);

		const countAfter = await counter.methods
			.get_counter(kernelAccount.getAddress())
			.simulate();

		console.log("countAfter: ", countAfter);

		expect(countAfter).toBe(countBefore + 1n);
	});

	it.skip("uninstall authenitcator", async () => {
		console.log(
			"ecdsaAuthenticatorContract.address: ",
			ecdsaAuthenticatorContract.address
		);
		const tx = await kernelAccountContract
			.withWallet(kernelAccount)
			.methods.uninstall_authenticator(ecdsaAuthenticatorContract.address)
			.send()
			.wait({ debug: true });

		expect(tx.status).toBe(TxStatus.SUCCESS);
	});

	it.skip("set new pub key", async () => {
		const signingPublicKey = new Ecdsa().computePublicKey(ecdsaSigningKey);

		const pub_x: number[] = Array.from(signingPublicKey.slice(0, 32));
		const pub_y: number[] = Array.from(signingPublicKey.slice(32, 64));
		console.log("pub_x: ", pub_x);
		console.log("pub_y: ", pub_y);

		const tx = await ecdsaAuthenticatorContract
			.withWallet(kernelAccount)
			.methods.set_new_public_key(pub_x, pub_y)
			.send()
			.wait();

		expect(tx.status).toBe(TxStatus.SUCCESS);
	});

	// it("install and transact with a custom validator: ecdsa k256 ", async () => {
	// 	const ecdsaSigningKey = new Fr(
	// 		Fr.random().toBigInt() % Fr.MODULUS
	// 	).toBuffer();

	// 	// instantiate Validators
	// 	ecdsaValidator = new EcdsaValidator(
	// 		ecdsaValidatorContract.address,
	// 		ecdsaSigningKey
	// 	);

	// 	const installTx = await kernelAccount
	// 		.installValidator(ecdsaValidator)
	// 		.send()
	// 		.wait();

	// 	expect(installTx.status).toBe(TxStatus.SUCCESS);

	// 	const isInstalled_Acc = await kernelAccountContract.methods
	// 		.is_validator_installed(ecdsaValidatorContract.address)
	// 		.simulate();
	// 	expect(isInstalled_Acc).toBe(true);

	// 	const isInstalled_Mod = await ecdsaValidatorContract.methods
	// 		.is_installed(kernelAccount.getAddress())
	// 		.simulate();
	// 	expect(isInstalled_Mod).toBe(true);

	// 	const signingPublicKey = new Ecdsa().computePublicKey(ecdsaSigningKey);
	// 	const public_keys: bigint[] = await ecdsaValidatorContract.methods
	// 		.view_public_keys(kernelAccount.getAddress())
	// 		.simulate();

	// 	console.log("public_keys: ", public_keys);
	// 	console.log("signingPublicKey:", signingPublicKey);

	// 	expect(
	// 		compBigIntArrayAndBuffer(
	// 			public_keys.slice(0, 32),
	// 			signingPublicKey.subarray(0, 32)
	// 		)
	// 	).toBe(true);
	// 	expect(
	// 		compBigIntArrayAndBuffer(
	// 			public_keys.slice(32, 64),
	// 			signingPublicKey.subarray(32, 64)
	// 		)
	// 	).toBe(true);

	// 	// switch validator
	// 	kernelAccount.switchValidator(ecdsaValidator);

	// 	const countBefore = await counter.methods
	// 		.get_counter(kernelAccount.getAddress())
	// 		.simulate();

	// 	const tx = await counter
	// 		.withWallet(kernelAccount)
	// 		.methods.increment(kernelAccount.getAddress(), kernelAccount.getAddress())
	// 		.send()
	// 		.wait();

	// 	expect(tx.status).toBe(TxStatus.SUCCESS);

	// 	const countAfter = await counter.methods
	// 		.get_counter(kernelAccount.getAddress())
	// 		.simulate();
	// 	expect(countAfter).toBe(countBefore + 1n);
	// });
});
