import {
	ABIParameterVisibility,
	FunctionAbi,
	FunctionType,
} from "@aztec/foundation/abi";

export const InstallValidatorAbi: FunctionAbi = {
	name: "install_validator",
	isInitializer: false,
	functionType: FunctionType.PRIVATE,
	isInternal: false,
	isStatic: false,
	parameters: [
		{
			name: "validator_address",
			type: {
				kind: "struct",
				path: "authwit::aztec::protocol_types::address::aztec_address::AztecAddress",
				fields: [{ name: "inner", type: { kind: "field" } }],
			},
			visibility: "private" as ABIParameterVisibility,
		},
		{
			name: "keys",
			type: {
				kind: "array",
				length: 500,
				type: {
					kind: "field",
				},
			},
			visibility: "private" as ABIParameterVisibility,
		},
	],
	returnTypes: [],
};

export const UninstallValidatorAbi: FunctionAbi = {
	name: "uninstall_validator",
	isInitializer: false,
	functionType: FunctionType.PRIVATE,
	isInternal: false,
	isStatic: false,
	parameters: [
		{
			name: "validator_address",
			type: {
				kind: "struct",
				path: "authwit::aztec::protocol_types::address::aztec_address::AztecAddress",
				fields: [{ name: "inner", type: { kind: "field" } }],
			},
			visibility: "private" as ABIParameterVisibility,
		},
	],
	returnTypes: [],
};

export const GetNonceAbi: FunctionAbi = {
	name: "get_nonce",
	isInitializer: false,
	functionType: FunctionType.UNCONSTRAINED,
	isInternal: false,
	isStatic: false,
	parameters: [],
	returnTypes: [{ kind: "field" }],
};

export const ApprovePublicAuthwitAbi: FunctionAbi = {
	name: "approve_public_authwit",
	isInitializer: false,
	functionType: FunctionType.PUBLIC,
	isInternal: true,
	isStatic: false,
	parameters: [
		{
			name: "message_hash",
			type: { kind: "field" },
			visibility: "private" as ABIParameterVisibility,
		},
	],
	returnTypes: [],
};

export const CancelAuthwitAbi: FunctionAbi = {
	name: "cancel_authwit",
	isInitializer: false,
	functionType: FunctionType.PRIVATE,
	isInternal: true,
	isStatic: false,
	parameters: [
		{
			name: "message_hash",
			type: { kind: "field" },
			visibility: "private" as ABIParameterVisibility,
		},
	],
	returnTypes: [],
};

export const LookupValidityAbi: FunctionAbi = {
	name: "lookup_validity",
	isInitializer: false,
	functionType: FunctionType.UNCONSTRAINED,
	isInternal: false,
	isStatic: false,
	parameters: [
		{
			name: "myself",
			type: {
				kind: "struct",
				path: "authwit::aztec::protocol_types::address::aztec_address::AztecAddress",
				fields: [{ name: "inner", type: { kind: "field" } }],
			},
			visibility: "private" as ABIParameterVisibility,
		},
		{
			name: "block_number",
			type: { kind: "integer", sign: "unsigned", width: 32 },
			visibility: "private" as ABIParameterVisibility,
		},
		{
			name: "check_private",
			type: { kind: "boolean" },
			visibility: "private" as ABIParameterVisibility,
		},
		{
			name: "message_hash",
			type: { kind: "field" },
			visibility: "private" as ABIParameterVisibility,
		},
	],
	returnTypes: [{ kind: "array", length: 2, type: { kind: "boolean" } }],
};

export const RotateNpkMAbi: FunctionAbi = {
	name: "rotate_npk_m",
	isInitializer: false,
	functionType: FunctionType.PUBLIC,
	isInternal: false,
	isStatic: false,
	parameters: [
		{
			name: "address",
			type: {
				fields: [{ name: "inner", type: { kind: "field" } }],
				kind: "struct",
				path: "authwit::aztec::protocol_types::address::aztec_address::AztecAddress",
			},
			visibility: "private" as ABIParameterVisibility,
		},
		{
			name: "new_npk_m",
			type: {
				fields: [
					{ name: "x", type: { kind: "field" } },
					{ name: "y", type: { kind: "field" } },
				],
				kind: "struct",
				path: "authwit::aztec::protocol_types::grumpkin_point::GrumpkinPoint",
			},
			visibility: "private" as ABIParameterVisibility,
		},
		{
			name: "nonce",
			type: { kind: "field" },
			visibility: "private" as ABIParameterVisibility,
		},
	],
	returnTypes: [],
};
