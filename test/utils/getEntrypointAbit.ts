import { FunctionAbi } from "@aztec/foundation/abi";

export function getEntrypointAbi() {
	return {
		name: "entrypoint",
		isInitializer: false,
		functionType: "private",
		isInternal: false,
		isStatic: false,
		parameters: [
			{
				name: "app_payload",
				type: {
					kind: "struct",
					path: "authwit::entrypoint::app::AppPayload",
					fields: [
						{
							name: "function_calls",
							type: {
								kind: "array",
								length: 4,
								type: {
									kind: "struct",
									path: "authwit::entrypoint::function_call::FunctionCall",
									fields: [
										{ name: "args_hash", type: { kind: "field" } },
										{
											name: "function_selector",
											type: {
												kind: "struct",
												path: "authwit::aztec::protocol_types::abis::function_selector::FunctionSelector",
												fields: [
													{
														name: "inner",
														type: {
															kind: "integer",
															sign: "unsigned",
															width: 32,
														},
													},
												],
											},
										},
										{
											name: "target_address",
											type: {
												kind: "struct",
												path: "authwit::aztec::protocol_types::address::AztecAddress",
												fields: [{ name: "inner", type: { kind: "field" } }],
											},
										},
										{ name: "is_public", type: { kind: "boolean" } },
										{ name: "is_static", type: { kind: "boolean" } },
									],
								},
							},
						},
						{ name: "nonce", type: { kind: "field" } },
					],
				},
				visibility: "public",
			},
			{
				name: "fee_payload",
				type: {
					kind: "struct",
					path: "authwit::entrypoint::fee::FeePayload",
					fields: [
						{
							name: "function_calls",
							type: {
								kind: "array",
								length: 2,
								type: {
									kind: "struct",
									path: "authwit::entrypoint::function_call::FunctionCall",
									fields: [
										{ name: "args_hash", type: { kind: "field" } },
										{
											name: "function_selector",
											type: {
												kind: "struct",
												path: "authwit::aztec::protocol_types::abis::function_selector::FunctionSelector",
												fields: [
													{
														name: "inner",
														type: {
															kind: "integer",
															sign: "unsigned",
															width: 32,
														},
													},
												],
											},
										},
										{
											name: "target_address",
											type: {
												kind: "struct",
												path: "authwit::aztec::protocol_types::address::AztecAddress",
												fields: [{ name: "inner", type: { kind: "field" } }],
											},
										},
										{ name: "is_public", type: { kind: "boolean" } },
										{ name: "is_static", type: { kind: "boolean" } },
									],
								},
							},
						},
						{ name: "nonce", type: { kind: "field" } },
						{ name: "is_fee_payer", type: { kind: "boolean" } },
					],
				},
				visibility: "public",
			},
		],
		returnTypes: [],
	} as FunctionAbi;
}
