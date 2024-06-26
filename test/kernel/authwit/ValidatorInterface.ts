import {
	AuthWitness,
	AztecAddress,
	ContractFunctionInteraction,
	Fr,
	FunctionCall,
	GrumpkinPrivateKey,
} from "@aztec/aztec.js";

type DeploymentArgsType = (AztecAddress | Fr[])[];

export interface ValidatorInterface {
	getValidatorAddress(): AztecAddress;
	getValidatorSigningKey(): GrumpkinPrivateKey | GrumpkinPrivateKey[] | Buffer;
	getDeploymentArgs(): DeploymentArgsType;
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
