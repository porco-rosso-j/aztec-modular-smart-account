import { BatchCall, Wallet } from "@aztec/aztec.js";
import {
	deployInstance,
	registerContractClass,
} from "@aztec/aztec.js/deployment";
import { SchnorrAccountContractArtifact } from "@aztec/noir-contracts.js";

export async function publicDeployAccounts(
	sender: Wallet,
	accountsToDeploy: Wallet[]
) {
	const accountAddressesToDeploy = accountsToDeploy.map((a) => a.getAddress());
	const instances = await Promise.all(
		accountAddressesToDeploy.map((account) =>
			sender.getContractInstance(account)
		)
	);
	const batch = new BatchCall(sender, [
		(
			await registerContractClass(sender, SchnorrAccountContractArtifact)
		).request(),
		...instances.map((instance) => deployInstance(sender, instance!).request()),
	]);
	await batch.send().wait();
}
