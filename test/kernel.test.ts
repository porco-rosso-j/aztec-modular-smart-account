import { jest, beforeAll, it, describe } from "@jest/globals";
import {
	Fr,
	PXE,
	createPXEClient,
	initAztecJs,
	AccountWalletWithSecretKey,
} from "@aztec/aztec.js";
import { Fq } from "@aztec/circuits.js";
import { getDeployedTestAccountsWallets } from "@aztec/accounts/testing";
import { CounterContract } from "@aztec/noir-contracts.js";
import { SANDBOX_URL, TIMEOUT } from "./utils/constants.js";
import { ECDSASecp256K1ModuleContract } from "./artifacts/ECDSASecp256K1Module.js";
import { SchnorrModuleContract } from "./artifacts/SchnorrModule.js";
import { EcdsaValidator } from "./kernel-accounts/validators/EcdsaValidator.js";
import { SchnorrValidator } from "./kernel-accounts/validators/ShnorrValidator.js";
import { deployAndGetKernelAccountWallet } from "./kernel-accounts/index.js";
import { KernelAccountWalletWithSecretKey } from "./kernel-accounts/KernelAccountWallet.js";
import { KernelAuthWitnessProvider } from "./kernel-accounts/validators/KernelAuthWitnessProvider.js";

let pxe: PXE;
let ecdsaValidatorContract: ECDSASecp256K1ModuleContract;
let schnorrValidatorContract: SchnorrModuleContract;

let ecdsaValidator: EcdsaValidator;
let schnorrValidator: SchnorrValidator;

let deployer: AccountWalletWithSecretKey;
let kernelAccount: KernelAccountWalletWithSecretKey;

let counter: CounterContract;

// presequities (typescript)
// - kernel account class that can have multiple auth wit provider

// deploy validators
// deploy an account and install default validator
// transact through validator

// install another validator
// transact with the second validator

beforeAll(async () => {
	pxe = createPXEClient(SANDBOX_URL);

	await initAztecJs();
	deployer = (await getDeployedTestAccountsWallets(pxe))[0];

	// deploy Validators
	ecdsaValidatorContract = (
		await ECDSASecp256K1ModuleContract.deploy(deployer).send().wait()
	).contract;

	console.log("ecdsaValidator: ", ecdsaValidatorContract.address);

	schnorrValidatorContract = (
		await SchnorrModuleContract.deploy(deployer).send().wait()
	).contract;

	console.log("schnorrValidator: ", schnorrValidatorContract.address);

	const schnorrSigningKey = Fq.random();

	schnorrValidator = new SchnorrValidator(
		schnorrValidatorContract.address,
		schnorrSigningKey
	);

	const kernelAuthWitProvider = new KernelAuthWitnessProvider(schnorrValidator);
	// instantiate and deploy KernelAccount contract
	kernelAccount = await deployAndGetKernelAccountWallet(
		pxe,
		Fr.random(),
		kernelAuthWitProvider,
		0
	);

	console.log("kernelAccount: ", kernelAccount.getAddress());

	const isInstalled = await schnorrValidatorContract.methods
		.is_installed(kernelAccount.getAddress())
		.simulate();

	console.log("isInstalled: ", isInstalled);

	// const public_keys = await schnorrValidatorContract.methods
	// 	.view_public_keys(kernelAccount.getAddress())
	// 	.simulate();

	// console.log("public_keys: ", public_keys);

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
	it("transact with default validator", async () => {
		const tx = await counter
			.withWallet(kernelAccount)
			.methods.increment(kernelAccount.getAddress(), kernelAccount.getAddress())
			.send()
			.wait();

		console.log("tx: ", tx.txHash.toString());
		const count = await counter.methods
			.get_counter(kernelAccount.getAddress())
			.simulate();
		console.log("count: ", count);
	});

	it("install and transact with a custom validator ", async () => {
		const ecdsaSigningKey = new Fr(
			Fr.random().toBigInt() % Fr.MODULUS
		).toBuffer();

		// instantiate Validators
		ecdsaValidator = new EcdsaValidator(
			ecdsaValidatorContract.address,
			ecdsaSigningKey
		);

		const installTx = await kernelAccount
			.installValidator(ecdsaValidator)
			.send()
			.wait();

		console.log("installTx: ", installTx);

		const isInstalled = await ecdsaValidatorContract.methods
			.is_installed(kernelAccount.getAddress())
			.simulate();

		console.log("isInstalled: ", isInstalled);

		// switch validator
		kernelAccount.switchValidator(ecdsaValidator);

		const tx = await counter
			.withWallet(kernelAccount)
			.methods.increment(kernelAccount.getAddress(), kernelAccount.getAddress())
			.send()
			.wait();

		console.log("tx: ", tx.txHash.toString());

		const count = await counter.methods
			.get_counter(kernelAccount.getAddress())
			.simulate();
		console.log("count: ", count);
	});
});
