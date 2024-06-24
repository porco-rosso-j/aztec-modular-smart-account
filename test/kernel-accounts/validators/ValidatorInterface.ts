import {
	AuthWitness,
	AuthWitnessProvider,
	AztecAddress,
	ContractFunctionInteraction,
	Fr,
	FunctionCall,
	GrumpkinPrivateKey,
} from "@aztec/aztec.js";

// export interface ValidatorInterface extends AuthWitnessProvider {
// 	getValidatorAddress(): AztecAddress;
// 	getDeploymentArgs(): Fr[] | Buffer[];
// }

type DeploymentArgsType = (AztecAddress | Fr[])[];

export interface ValidatorInterface {
	getValidatorAddress(): AztecAddress;
	getValidatorSigningKey(): GrumpkinPrivateKey | GrumpkinPrivateKey[] | Buffer;
	// getDeploymentArgs(): Fr[] | Buffer[];
	getDeploymentArgs(): DeploymentArgsType;

	/**
	 * Computes an authentication witness from either a message hash or an intent (caller and an action).
	 * If a message hash is provided, it will create a witness for that directly.
	 * Otherwise, it will compute the message hash using the caller and the action of the intent.
	 * @param messageHashOrIntent - The message hash or the intent (caller and action) to approve
	 * @param chainId - The chain id for the message, will default to the current chain id
	 * @param version - The version for the message, will default to the current protocol version
	 * @returns The authentication witness
	 */
	createAuthWit(
		messageHashOrIntent:
			| Fr
			| Buffer
			| {
					/** The caller to approve  */
					caller: AztecAddress;
					/** The action to approve */
					action: ContractFunctionInteraction | FunctionCall;
					/** The chain id to approve */
					chainId?: Fr;
					/** The version to approve  */
					version?: Fr;
			  },
		isDefault: boolean
	): Promise<AuthWitness>;
}

export const MODE_DEFAULT = new Fr(0);
export const MODE_CUSTOM = new Fr(1);
export const MAX_WITNESS_LEN = 500;
export const MAX_INSTALL_KEYS_LEN = 500;
export const VALIDATE_SELECTOR = 0xdd0526f3;
export const INSTALL_SELECTOR = 0x7b42afcc;
export const UNINSTALL_SELECTOR = 0x0d638f30;

type Witness = (Fr | number)[];

export function padWitness(witness: Witness): Witness {
	if (witness.length < MAX_WITNESS_LEN) {
		witness = [
			...witness,
			...new Array<Fr>(MAX_WITNESS_LEN - witness.length).fill(Fr.ZERO),
		];
	}
	return witness;
}

export function padDeploymentArgs(args: Buffer | Fr[]): Fr[] {
	if (args.length < MAX_INSTALL_KEYS_LEN) {
		let fieldArray: Fr[] = [];
		if (Buffer.isBuffer(args)) {
			fieldArray = Array.from(args).map((arg) => new Fr(arg));
			console.log("len: ", fieldArray.length);
			console.log("fieldArray: ", fieldArray);
		} else {
			fieldArray = args;
		}

		fieldArray = [
			...fieldArray,
			...new Array<Fr>(MAX_WITNESS_LEN - fieldArray.length).fill(Fr.ZERO),
		];

		// console.log("fieldArray: ", fieldArray);
		console.log("len after padded: ", fieldArray.length);
		return fieldArray;
	} else {
		throw "len too long > MAX_INSTALL_KEYS_LEN";
	}
}
