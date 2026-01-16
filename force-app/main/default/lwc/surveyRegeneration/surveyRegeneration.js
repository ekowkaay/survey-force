import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import regenerateSurveyLinks from '@salesforce/apex/SurveyRegenerationController.regenerateSurveyLinks';

export default class SurveyRegeneration extends LightningElement {
	@track trainingRequestIds = '';
	@track regenerateParticipant = true;
	@track regenerateCustomer = true;
	@track regenerateTrainer = true;

	// UI State
	@track isLoading = false;
	@track showConfirmation = false;
	@track showResults = false;

	// Results
	@track success = false;
	@track message = '';
	@track totalProcessed = 0;
	@track totalSuccess = 0;
	@track totalFailed = 0;
	@track participantLinksGenerated = 0;
	@track customerLinksGenerated = 0;
	@track trainerLinksGenerated = 0;
	@track errorDetails = '';

	get isInputValid() {
		return this.trainingRequestIds && this.trainingRequestIds.trim().length > 0;
	}

	get hasResults() {
		return this.showResults;
	}

	get showSuccessMessage() {
		return this.showResults && this.success;
	}

	get showErrorMessage() {
		return this.showResults && !this.success;
	}

	get hasAtLeastOneSurveyTypeSelected() {
		return this.regenerateParticipant || this.regenerateCustomer || this.regenerateTrainer;
	}

	get canProceed() {
		return this.isInputValid && this.hasAtLeastOneSurveyTypeSelected && !this.isLoading;
	}

	get isNextDisabled() {
		return !this.canProceed;
	}

	handleTrainingRequestIdsChange(event) {
		this.trainingRequestIds = event.target.value;
	}

	handleParticipantChange(event) {
		this.regenerateParticipant = event.target.checked;
	}

	handleCustomerChange(event) {
		this.regenerateCustomer = event.target.checked;
	}

	handleTrainerChange(event) {
		this.regenerateTrainer = event.target.checked;
	}

	handleNext() {
		if (!this.canProceed) {
			this.showToast('Error', 'Please enter Training Request IDs and select at least one survey type', 'error');
			return;
		}
		this.showConfirmation = true;
	}

	handleBack() {
		this.showConfirmation = false;
	}

	handleConfirm() {
		this.executeRegeneration();
	}

	handleReset() {
		this.trainingRequestIds = '';
		this.regenerateParticipant = true;
		this.regenerateCustomer = true;
		this.regenerateTrainer = true;
		this.showConfirmation = false;
		this.showResults = false;
		this.success = false;
		this.message = '';
		this.errorDetails = '';
	}

	executeRegeneration() {
		this.isLoading = true;

		// Parse Training Request IDs
		const idsArray = this.trainingRequestIds
			.split(',')
			.map((id) => id.trim())
			.filter((id) => id.length > 0);

		const request = {
			trainingRequestIds: idsArray,
			regenerateParticipant: this.regenerateParticipant,
			regenerateCustomer: this.regenerateCustomer,
			regenerateTrainer: this.regenerateTrainer
		};

		regenerateSurveyLinks({ requests: [request] })
			.then((results) => {
				if (results && results.length > 0) {
					const result = results[0];
					this.success = result.success;
					this.message = result.message;
					this.totalProcessed = result.totalProcessed;
					this.totalSuccess = result.totalSuccess;
					this.totalFailed = result.totalFailed;
					this.participantLinksGenerated = result.participantLinksGenerated;
					this.customerLinksGenerated = result.customerLinksGenerated;
					this.trainerLinksGenerated = result.trainerLinksGenerated;
					this.errorDetails = result.errorDetails || '';

					this.showConfirmation = false;
					this.showResults = true;

					if (this.success) {
						this.showToast('Success', 'Survey links regenerated successfully', 'success');
					} else {
						this.showToast('Warning', 'Regeneration completed with errors', 'warning');
					}
				}
				this.isLoading = false;
			})
			.catch((error) => {
				this.isLoading = false;
				this.showConfirmation = false;
				this.showResults = true;
				this.success = false;
				this.message = 'Error executing regeneration';
				this.errorDetails = error.body?.message || error.message || 'Unknown error';
				this.showToast('Error', 'Error regenerating survey links: ' + this.errorDetails, 'error');
			});
	}

	showToast(title, message, variant) {
		const event = new ShowToastEvent({
			title,
			message,
			variant
		});
		this.dispatchEvent(event);
	}
}
