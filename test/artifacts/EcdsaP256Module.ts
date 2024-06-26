/* Autogenerated file, do not edit! */

/* eslint-disable */
import {
	AztecAddress,
	AztecAddressLike,
	CompleteAddress,
	Contract,
	ContractArtifact,
	ContractBase,
	ContractFunctionInteraction,
	ContractInstanceWithAddress,
	ContractMethod,
	ContractStorageLayout,
	ContractNotes,
	DeployMethod,
	EthAddress,
	EthAddressLike,
	FieldLike,
	Fr,
	FunctionSelectorLike,
	loadContractArtifact,
	NoirCompiledContract,
	Point,
	PublicKey,
	Wallet,
	WrappedFieldLike,
} from "@aztec/aztec.js";
import EcdsaP256ModuleContractArtifactJson from "../../contracts/validators/ecdsa-p256/target/ecdsa_p256_validator-EcdsaP256Module.json" assert { type: "json" };
export const EcdsaP256ModuleContractArtifact = loadContractArtifact(
	EcdsaP256ModuleContractArtifactJson as NoirCompiledContract
);

/**
 * Type-safe interface for contract EcdsaP256Module;
 */
export class EcdsaP256ModuleContract extends ContractBase {
	private constructor(instance: ContractInstanceWithAddress, wallet: Wallet) {
		super(instance, EcdsaP256ModuleContractArtifact, wallet);
	}

	/**
	 * Creates a contract instance.
	 * @param address - The deployed contract's address.
	 * @param wallet - The wallet to use when interacting with the contract.
	 * @returns A promise that resolves to a new Contract instance.
	 */
	public static async at(address: AztecAddress, wallet: Wallet) {
		return Contract.at(
			address,
			EcdsaP256ModuleContract.artifact,
			wallet
		) as Promise<EcdsaP256ModuleContract>;
	}

	/**
	 * Creates a tx to deploy a new instance of this contract.
	 */
	public static deploy(wallet: Wallet) {
		return new DeployMethod<EcdsaP256ModuleContract>(
			Fr.ZERO,
			wallet,
			EcdsaP256ModuleContractArtifact,
			EcdsaP256ModuleContract.at,
			Array.from(arguments).slice(1)
		);
	}

	/**
	 * Creates a tx to deploy a new instance of this contract using the specified public keys hash to derive the address.
	 */
	public static deployWithPublicKeysHash(publicKeysHash: Fr, wallet: Wallet) {
		return new DeployMethod<EcdsaP256ModuleContract>(
			publicKeysHash,
			wallet,
			EcdsaP256ModuleContractArtifact,
			EcdsaP256ModuleContract.at,
			Array.from(arguments).slice(2)
		);
	}

	/**
	 * Creates a tx to deploy a new instance of this contract using the specified constructor method.
	 */
	public static deployWithOpts<
		M extends keyof EcdsaP256ModuleContract["methods"]
	>(
		opts: { publicKeysHash?: Fr; method?: M; wallet: Wallet },
		...args: Parameters<EcdsaP256ModuleContract["methods"][M]>
	) {
		return new DeployMethod<EcdsaP256ModuleContract>(
			opts.publicKeysHash ?? Fr.ZERO,
			opts.wallet,
			EcdsaP256ModuleContractArtifact,
			EcdsaP256ModuleContract.at,
			Array.from(arguments).slice(1),
			opts.method ?? "constructor"
		);
	}

	/**
	 * Returns this contract's artifact.
	 */
	public static get artifact(): ContractArtifact {
		return EcdsaP256ModuleContractArtifact;
	}

	public static get storage(): ContractStorageLayout<"public_keys"> {
		return {
			public_keys: {
				slot: new Fr(1n),
				typ: "Map<AztecAddress, PrivateMutable<EcdsaPublicKeyNote, Context>, Context>",
			},
		} as ContractStorageLayout<"public_keys">;
	}

	public static get notes(): ContractNotes<
		"EcdsaPublicKeyNote" | "PublicKeyNote"
	> {
		return {
			EcdsaPublicKeyNote: {
				id: new Fr(6999100115978011798108105997510112178111116101n),
			},
			PublicKeyNote: {
				id: new Fr(8011798108105997510112178111116101n),
			},
		} as ContractNotes<"EcdsaPublicKeyNote" | "PublicKeyNote">;
	}

	/** Type-safe wrappers for the public methods exposed by the contract. */
	// @ts-ignore
	public override methods!: {
		/** uninstall() */
		uninstall: (() => ContractFunctionInteraction) &
			Pick<ContractMethod, "selector">;

		/** install(keys: array) */
		install: ((keys: FieldLike[]) => ContractFunctionInteraction) &
			Pick<ContractMethod, "selector">;

		/** validate(mode: field, outer_hash: field) */
		validate: ((
			mode: FieldLike,
			outer_hash: FieldLike
		) => ContractFunctionInteraction) &
			Pick<ContractMethod, "selector">;

		/** compute_note_hash_and_nullifier(contract_address: struct, nonce: field, storage_slot: field, note_type_id: field, serialized_note: array) */
		compute_note_hash_and_nullifier: ((
			contract_address: AztecAddressLike,
			nonce: FieldLike,
			storage_slot: FieldLike,
			note_type_id: FieldLike,
			serialized_note: FieldLike[]
		) => ContractFunctionInteraction) &
			Pick<ContractMethod, "selector">;

		/** view_public_keys(account: struct) */
		view_public_keys: ((
			account: AztecAddressLike
		) => ContractFunctionInteraction) &
			Pick<ContractMethod, "selector">;

		/** is_installed(account: struct) */
		is_installed: ((account: AztecAddressLike) => ContractFunctionInteraction) &
			Pick<ContractMethod, "selector">;

		/** set_new_public_key(pub_key_x: array, pub_key_y: array) */
		set_new_public_key: ((
			pub_key_x: (bigint | number)[],
			pub_key_y: (bigint | number)[]
		) => ContractFunctionInteraction) &
			Pick<ContractMethod, "selector">;
	};
}
