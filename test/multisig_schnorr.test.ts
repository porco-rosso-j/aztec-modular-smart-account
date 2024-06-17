import { jest, beforeAll, it, describe } from "@jest/globals";
import {
	Fr,
	PXE,
	createPXEClient,
	initAztecJs,
	AccountWalletWithSecretKey,
	deriveKeys,
	Schnorr,
	TxExecutionRequest,
	AuthWitness,
	FunctionCall,
	PackedValues,
	encodeArguments,
} from "@aztec/aztec.js";
import {
	AztecAddress,
	FunctionSelector,
	GasSettings,
	Point,
	TxContext,
	computePartialAddress,
	deriveSigningKey,
} from "@aztec/circuits.js";
import { getDeployedTestAccountsWallets } from "@aztec/accounts/testing";
import { CounterContract } from "@aztec/noir-contracts.js";
import { MultisigAccountSchnorrContract } from "./artifacts/MultisigAccountSchnorr.js";
import {
	MAX_MULTISIG_OWNERS,
	SANDBOX_URL,
	TIMEOUT,
} from "./utils/constants.js";
import { EntrypointPayload } from "@aztec/aztec.js/entrypoint";
import { getEntrypointAbi } from "./utils/getEntrypointAbit.js";

let pxe: PXE;
let multisigContract: MultisigAccountSchnorrContract;

let signerA: AccountWalletWithSecretKey;
let signerB: AccountWalletWithSecretKey;
let signerC: AccountWalletWithSecretKey;

let counter: CounterContract;

//  yarn test multisig_schnorr.test.ts

beforeAll(async () => {
	pxe = createPXEClient(SANDBOX_URL);

	await initAztecJs();
	const accounts = await getDeployedTestAccountsWallets(pxe);

	signerA = accounts[0];
	signerB = accounts[1];
	signerC = accounts[2];
	console.log("signerA addr: ", signerA.getAddress());
	console.log("signerB addr: ", signerB.getAddress());
	console.log("signerC addr: ", signerC.getAddress());

	const owners = accounts.map((account) => account.getAddress());
	while (owners.length < MAX_MULTISIG_OWNERS) {
		owners.push(AztecAddress.ZERO); // Fill the remaining slots with AztecAddress::ZERO
	}

	console.log("owners: ", owners);
	const signing_pubkeys = accounts.map((account) =>
		new Schnorr().computePublicKey(deriveSigningKey(account.getSecretKey()))
	);

	while (signing_pubkeys.length < MAX_MULTISIG_OWNERS) {
		signing_pubkeys.push(Point.ZERO); // Fill the remaining slots with AztecAddress::ZERO
	}

	// create keys for Multisig contract
	const secretKey = Fr.random();
	const keys = deriveKeys(secretKey);
	console.log("keys: ", keys);

	const ov_secret_key = {
		high: keys.masterOutgoingViewingSecretKey.high,
		low: keys.masterOutgoingViewingSecretKey.low,
	};

	const iv_secret_key = {
		high: keys.masterIncomingViewingSecretKey.high,
		low: keys.masterIncomingViewingSecretKey.low,
	};

	console.log("0");

	const multisigDeployment =
		MultisigAccountSchnorrContract.deployWithPublicKeysHash(
			keys.publicKeys.hash(),
			signerA,
			owners,
			signing_pubkeys,
			2,
			iv_secret_key,
			ov_secret_key
		);

	// deploy setter account
	const multisigInstance = multisigDeployment.getInstance();
	console.log(
		"multisigInstance.contractClassId: ",
		multisigInstance.contractClassId
	);
	await pxe.registerAccount(secretKey, computePartialAddress(multisigInstance));
	multisigContract = await multisigDeployment.send().deployed();
	console.log("multisigContract.address: ", multisigContract.address);

	counter = (
		await CounterContract.deploy(
			signerA,
			0,
			multisigContract.address,
			multisigContract.address
		)
			.send()
			.wait()
	).contract;
	console.log(
		"counter.instance.contractClassId: ",
		counter.instance.contractClassId
	);

	console.log("counter: ", counter.address);
}, TIMEOUT);

describe("E2E Batcher setup", () => {
	jest.setTimeout(TIMEOUT);
	it("deployment", async () => {
		const owners = await multisigContract.methods.get_owners().simulate();
		console.log("owners: ", owners);

		const threshold = await multisigContract.methods.get_threshold().simulate();
		console.log("threshold: ", threshold);

		const nonce = await multisigContract.methods.get_nonce().simulate();
		console.log("nonce: ", nonce);

		const owner1_pubkey = await multisigContract.methods
			.get_pubkeys_by_owner(owners[0])
			.simulate();
		console.log("owner1_pubkey: ", owner1_pubkey);
	});

	it("increment counter", async () => {
		const funcCall: FunctionCall = counter.methods
			.increment(multisigContract.address, multisigContract.address)
			.request();

		const appPayload = EntrypointPayload.fromAppExecution([funcCall]);
		const feePayload = await EntrypointPayload.fromFeeOptions(
			multisigContract.address
		);

		const abi = getEntrypointAbi();
		const gasSettings = GasSettings.default();
		const entrypointPackedArgs = PackedValues.fromValues(
			encodeArguments(abi, [appPayload, feePayload])
		);

		const functionSelector = FunctionSelector.fromNameAndParameters(
			abi.name,
			abi.parameters
		);

		const chainId = new Fr((await pxe.getNodeInfo()).chainId);
		const version = new Fr((await pxe.getNodeInfo()).protocolVersion);

		const AppauthWitA = await signerA.createAuthWit(appPayload.hash());
		const AppauthWitB = await signerB.createAuthWit(appPayload.hash());

		const FeeauthWitA = await signerA.createAuthWit(feePayload.hash());
		const FeeauthWitB = await signerB.createAuthWit(feePayload.hash());

		const signerLen = new Fr(2);

		let appSig: Fr[] = [
			signerLen,
			new Fr(0),
			...AppauthWitA.witness,
			new Fr(1),
			...AppauthWitB.witness,
		];

		if (appSig.length < 326) {
			appSig = [...appSig, ...new Array<Fr>(326 - appSig.length).fill(Fr.ZERO)];
		}

		console.log("(appSig.length: ", appSig.length);

		let feeSig: Fr[] = [
			signerLen,
			new Fr(0),
			...FeeauthWitA.witness,
			new Fr(1),
			...FeeauthWitB.witness,
		];

		if (feeSig.length < 326) {
			feeSig = [...feeSig, ...new Array<Fr>(326 - feeSig.length).fill(Fr.ZERO)];
		}

		console.log("(feeSig.length: ", feeSig.length);

		const _txRequest = TxExecutionRequest.from({
			firstCallArgsHash: entrypointPackedArgs.hash,
			origin: multisigContract.address,
			functionSelector,
			txContext: new TxContext(chainId, version, gasSettings),
			argsOfCalls: [
				...appPayload.packedArguments,
				...feePayload.packedArguments,
				entrypointPackedArgs,
			],
			authWitnesses: [
				new AuthWitness(appPayload.hash(), appSig),
				new AuthWitness(feePayload.hash(), feeSig),
			],
		});

		const simulatedTx = (await pxe.simulateTx(_txRequest, true)).tx;
		await pxe.sendTx(simulatedTx);
	});
});
