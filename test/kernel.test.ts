import { jest, beforeAll, it, describe } from "@jest/globals";
import {
	Fr,
	PXE,
	createPXEClient,
	initAztecJs,
	AccountWalletWithSecretKey,
	Schnorr,
	TxStatus,
} from "@aztec/aztec.js";
import { Fq } from "@aztec/circuits.js";
import { Ecdsa } from "@aztec/circuits.js/barretenberg";
import { getDeployedTestAccountsWallets } from "@aztec/accounts/testing";
import { CounterContract } from "@aztec/noir-contracts.js";
import { SANDBOX_URL, TIMEOUT } from "./constants.js";
import {
	deployAndGetKernelAccountWallet,
	KernelAccountWalletWithSecretKey,
} from "./kernel/index.js";
import {
	KernelAccountContract,
	SchnorrModuleContract,
	EcdsaK256ModuleContract,
} from "./artifacts/index.js";
import {
	KernelAuthWitnessProvider,
	EcdsaValidator,
	SchnorrValidator,
} from "./kernel/authwit/index.js";
import { compBigIntArrayAndBuffer } from "./helper.js";

let pxe: PXE;
let ecdsaValidatorContract: EcdsaK256ModuleContract;
let schnorrValidatorContract: SchnorrModuleContract;

let ecdsaValidator: EcdsaValidator;
let schnorrValidator: SchnorrValidator;

let deployer: AccountWalletWithSecretKey;
let kernelAccount: KernelAccountWalletWithSecretKey;
let kernelAccountContract: KernelAccountContract;

let counter: CounterContract;

beforeAll(async () => {
	pxe = createPXEClient(SANDBOX_URL);

	await initAztecJs();
	deployer = (await getDeployedTestAccountsWallets(pxe))[0];

	// deploy Validators
	ecdsaValidatorContract = (
		await EcdsaK256ModuleContract.deploy(deployer).send().wait()
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

	kernelAccountContract = await KernelAccountContract.at(
		kernelAccount.getAddress(),
		kernelAccount
	);

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
	it("should successfully installed schnorr validator", async () => {
		const isInstalled_Acc = await kernelAccountContract.methods
			.is_validator_installed(schnorrValidatorContract.address)
			.simulate();
		expect(isInstalled_Acc).toBe(true);

		const isInstalled_Mod = await schnorrValidatorContract.methods
			.is_installed(kernelAccount.getAddress())
			.simulate();
		expect(isInstalled_Mod).toBe(true);

		const signingPublicKey = new Schnorr().computePublicKey(
			schnorrValidator.getValidatorSigningKey()
		);

		const public_keys = await schnorrValidatorContract.methods
			.view_public_keys(kernelAccount.getAddress())
			.simulate();

		expect(signingPublicKey.x.toBigInt()).toBe(public_keys[0]);
		expect(signingPublicKey.y.toBigInt()).toBe(public_keys[1]);
	});

	it("transact with default validator", async () => {
		const countBefore = await counter.methods
			.get_counter(kernelAccount.getAddress())
			.simulate();

		const tx = await counter
			.withWallet(kernelAccount)
			.methods.increment(kernelAccount.getAddress(), kernelAccount.getAddress())
			.send()
			.wait();

		expect(tx.status).toBe(TxStatus.SUCCESS);

		const countAfter = await counter.methods
			.get_counter(kernelAccount.getAddress())
			.simulate();
		expect(countAfter).toBe(countBefore + 1n);
	});

	it("install and transact with a custom validator: ecdsa k256 ", async () => {
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

		expect(installTx.status).toBe(TxStatus.SUCCESS);

		const isInstalled_Acc = await kernelAccountContract.methods
			.is_validator_installed(ecdsaValidatorContract.address)
			.simulate();
		expect(isInstalled_Acc).toBe(true);

		const isInstalled_Mod = await ecdsaValidatorContract.methods
			.is_installed(kernelAccount.getAddress())
			.simulate();
		expect(isInstalled_Mod).toBe(true);

		const signingPublicKey = new Ecdsa().computePublicKey(ecdsaSigningKey);
		const public_keys: bigint[] = await ecdsaValidatorContract.methods
			.view_public_keys(kernelAccount.getAddress())
			.simulate();

		console.log("public_keys: ", public_keys);
		console.log("signingPublicKey:", signingPublicKey);

		expect(
			compBigIntArrayAndBuffer(
				public_keys.slice(0, 32),
				signingPublicKey.subarray(0, 32)
			)
		).toBe(true);
		expect(
			compBigIntArrayAndBuffer(
				public_keys.slice(32, 64),
				signingPublicKey.subarray(32, 64)
			)
		).toBe(true);

		// switch validator
		kernelAccount.switchValidator(ecdsaValidator);

		const countBefore = await counter.methods
			.get_counter(kernelAccount.getAddress())
			.simulate();

		const tx = await counter
			.withWallet(kernelAccount)
			.methods.increment(kernelAccount.getAddress(), kernelAccount.getAddress())
			.send()
			.wait();

		expect(tx.status).toBe(TxStatus.SUCCESS);

		const countAfter = await counter.methods
			.get_counter(kernelAccount.getAddress())
			.simulate();
		expect(countAfter).toBe(countBefore + 1n);
	});
});
