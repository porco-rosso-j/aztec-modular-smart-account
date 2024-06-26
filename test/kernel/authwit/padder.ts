import { Fr } from "@aztec/circuits.js";
import { MAX_INSTALL_KEYS_LEN, MAX_WITNESS_LEN } from "./constants.js";

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
		} else {
			fieldArray = args;
		}
		fieldArray = padFrArray(fieldArray, MAX_WITNESS_LEN);
		console.log("len after padded: ", fieldArray.length);
		return fieldArray;
	} else {
		throw "len too long > MAX_INSTALL_KEYS_LEN";
	}
}

export function padFrArray(array: Fr[], len: number) {
	return [...array, ...new Array<Fr>(len - array.length).fill(Fr.ZERO)];
}

export function padArray(array: any[], len: number, value: any) {
	return [...array, ...new Array<any>(len - array.length).fill(value)];
}
