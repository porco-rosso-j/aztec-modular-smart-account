import { type AuthWitnessProvider } from "@aztec/aztec.js/account";
import { AuthWitness, type CompleteAddress } from "@aztec/circuit-types";
import { type Fr } from "@aztec/foundation/fields";
import { ValidatorInterface } from "./ValidatorInterface.js";
import { AztecAddress } from "@aztec/circuits.js";

export interface KernelAuthWitnessProviderInterface
	extends AuthWitnessProvider {
	createAuthWit(messageHash: Fr): Promise<AuthWitness>;
	getValidator(validatorAddress: AztecAddress): ValidatorInterface;
	getCurrentValidator(): ValidatorInterface;
	getDefaultValidator(): ValidatorInterface;
	switchValidator(validator: ValidatorInterface): void;
	addValidator(validator: ValidatorInterface): void;
	removeValidator(validator: ValidatorInterface): void;
}

export class KernelAuthWitnessProvider
	implements KernelAuthWitnessProviderInterface
{
	private validators: Map<AztecAddress, ValidatorInterface> = new Map();
	private currentValidatorKey: AztecAddress;

	constructor(private defaultValidator: ValidatorInterface) {
		this.validators.set(
			defaultValidator.getValidatorAddress(),
			defaultValidator
		);
		this.currentValidatorKey = defaultValidator.getValidatorAddress();
	}

	createAuthWit(messageHash: Fr): Promise<AuthWitness> {
		const validator = this.validators.get(this.currentValidatorKey);
		if (!validator) {
			throw new Error(`Validator not found`);
		}

		const isDefault = this.defaultValidator
			.getValidatorAddress()
			.equals(validator.getValidatorAddress());

		return validator.createAuthWit(messageHash, isDefault);
	}

	getValidator(validatorAddress: AztecAddress): ValidatorInterface {
		return this.validators.get(validatorAddress)!;
	}

	getCurrentValidator(): ValidatorInterface {
		return this.validators.get(this.currentValidatorKey)!;
	}

	getDefaultValidator(): ValidatorInterface {
		return this.defaultValidator;
	}

	switchValidator(validator: ValidatorInterface) {
		if (this.validators.has(validator.getValidatorAddress())) {
			this.currentValidatorKey = validator.getValidatorAddress();
		} else {
			throw new Error("Validator not found");
		}
	}

	addValidator(validator: ValidatorInterface) {
		this.validators.set(validator.getValidatorAddress(), validator);
	}
	removeValidator(validator: ValidatorInterface) {
		this.validators.delete(validator.getValidatorAddress());
	}
}
