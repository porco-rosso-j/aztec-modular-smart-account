export const compBigIntArrayAndBuffer = (bgArray: bigint[], buffer: Buffer) => {
	const strArray1 = bgArray.map((bigint) => bigint.toString());
	const strArray2 = Array.from(buffer).map((value) => value.toString());

	console.log("strArray1: ", strArray1);
	console.log("strArray2: ", strArray2);

	let result = true;
	for (let i = 0; i < strArray1.length; i++) {
		if (strArray1[i] != strArray2[i]) {
			result = false;
		}
	}

	return result;
};
