import { jest, beforeAll, it, describe } from "@jest/globals";
import {
	Fr,
	PXE,
	createPXEClient,
	initAztecJs,
	AccountWalletWithSecretKey,
	Schnorr,
	TxStatus,
	AztecAddress,
} from "@aztec/aztec.js";
import {
	INITIAL_TEST_SIGNING_KEYS,
	getDeployedTestAccountsWallets,
} from "@aztec/accounts/testing";
import { CounterContract } from "@aztec/noir-contracts.js";
import { SANDBOX_URL, TIMEOUT } from "./constants.js";
import {
	KernelAuthWitnessProvider,
	MultisigSchnorrValidator,
} from "./kernel/authwit/index.js";
import {
	deployAndGetKernelAccountWallet,
	KernelAccountWalletWithSecretKey,
} from "./kernel/index.js";
import {
	KernelAccountContract,
	MultisigSchnorrModuleContract,
} from "./artifacts/index.js";

let pxe: PXE;
let multisigValidatorContract: MultisigSchnorrModuleContract;
let multisigValidator: MultisigSchnorrValidator;

let signers: AccountWalletWithSecretKey[];

let kernelAccount: KernelAccountWalletWithSecretKey;
let kernelAccountContract: KernelAccountContract;

let counter: CounterContract;

beforeAll(async () => {
	pxe = createPXEClient(SANDBOX_URL);
	await initAztecJs();

	signers = await getDeployedTestAccountsWallets(pxe);

	// deploy Validators
	multisigValidatorContract = (
		await MultisigSchnorrModuleContract.deploy(signers[0]).send().wait()
	).contract;

	console.log("multisigValidatorContract: ", multisigValidatorContract.address);

	multisigValidator = new MultisigSchnorrValidator(
		multisigValidatorContract.address,
		signers.map((signer) => signer.getAddress()),
		INITIAL_TEST_SIGNING_KEYS,
		2
	);

	const kernelAuthWitProvider = new KernelAuthWitnessProvider(
		multisigValidator
	);
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

	const multisigNote = await multisigValidatorContract.methods
		.get_multisig_note(kernelAccount.getAddress())
		.simulate();

	console.log("multisigNote: ", multisigNote);

	counter = (
		await CounterContract.deploy(
			signers[0],
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
			.is_validator_installed(multisigValidatorContract.address)
			.simulate();
		expect(isInstalled_Acc).toBe(true);

		const isInstalled_Mod = await multisigValidatorContract.methods
			.is_installed(kernelAccount.getAddress())
			.simulate();
		expect(isInstalled_Mod).toBe(true);
		const threshold = await multisigValidatorContract.methods
			.get_threshold(kernelAccount.getAddress())
			.simulate();

		expect(threshold).toBe(2n);

		const owners = (await multisigValidatorContract.methods
			.get_owners(kernelAccount.getAddress())
			.simulate()) as BigInt[];

		console.log("owners: ", owners);

		const signingKeys = multisigValidator.getValidatorSigningKey();
		for (let i = 0; i < signers.length; i++) {
			expect(owners[i]).toBe(signers[i].getAddress().toBigInt());
			const signingPublicKey = new Schnorr().computePublicKey(signingKeys[i]);
			const pubkey_key = await multisigValidatorContract.methods
				.view_public_keys(kernelAccount.getAddress(), signers[i].getAddress())
				.simulate();

			expect(signingPublicKey.x.toBigInt()).toBe(pubkey_key[0]);
			expect(signingPublicKey.y.toBigInt()).toBe(pubkey_key[1]);
		}
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
});
