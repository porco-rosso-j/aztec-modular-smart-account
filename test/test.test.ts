import { AztecAddress } from "@aztec/circuits.js";
import crypto from "crypto";
import fs from "fs";
import { KernelAccountContract } from "./artifacts/KernelAccount.js";
import { SignerlessWallet, createPXEClient, Fr } from "@aztec/aztec.js";
import { SANDBOX_URL } from "./utils/constants.js";

beforeAll(async () => {});

describe("E2E Batcher setup", () => {
	// it("deployment", async () => {
	// 	// Initialize array of length 500
	// 	let array = new Uint8Array(500);

	// 	// Set specific values
	// 	array[0] = 1; // 1 at index 0

	// 	// Random hex at index 1
	// 	array[1] = crypto.randomBytes(1)[0];

	// 	// Random u8 values from index 2 to 66
	// 	for (let i = 2; i < 66; i++) {
	// 		array[i] = crypto.randomBytes(1)[0];
	// 	}

	// 	// The remaining elements are already 0 by default
	// 	let arrayRegular = Array.from(array);

	// 	console.log(array);
	// 	fs.writeFileSync("output.json", JSON.stringify(arrayRegular));
	// });

	it("nonce", async () => {
		const pxe = createPXEClient(SANDBOX_URL);
		const kernelAccount = await KernelAccountContract.at(
			AztecAddress.fromString(
				"0x1647e8833cb2e25d1800bdfb3955c0180f36d4ef7977ab703fd72789290d3181"
			),
			new SignerlessWallet(pxe)
		);

		const nonce: Fr = await kernelAccount.methods.get_nonce().simulate();

		console.log("nonce: ", new Fr(nonce).add(new Fr(BigInt(1))));
	});
});
