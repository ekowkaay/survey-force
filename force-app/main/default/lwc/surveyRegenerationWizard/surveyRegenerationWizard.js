import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import parseTrainingRequestIds from '@salesforce/apex/SurveyRegenerationController.parseTrainingRequestIds';
import getSurveysForRegeneration from '@salesforce/apex/SurveyRegenerationController.getSurveysForRegeneration';
import regenerateSurveyInvitations from '@salesforce/apex/SurveyRegenerationController.regenerateSurveyInvitations';

const STEPS = {
	UPLOAD: 'upload',
	SELECT: 'select',
	CONFIRM: 'confirm',
	COMPLETE: 'complete'
};

export default class SurveyRegenerationWizard extends LightningElement {
	@track currentStep = STEPS.UPLOAD;
	@track manualIds = '';
	@track parsedIds = [];
	@track uploadError = '';
	@track isProcessing = false;
	@track isLoadingSurveys = false;

	// Survey type selections
	@track isCustomerSelected = false;
	@track isTrainerSelected = false;
	@track isParticipantSelected = false;

	// Surveys data
	@track surveysToRegenerate = [];
	@track regenerationResult = null;
	@track regenerationSuccess = false;
	@track regenerationMessage = '';
	@track errorMessages = [];

	get isUploadStep() {
		return this.currentStep === STEPS.UPLOAD;
	}

	get isSelectStep() {
		return this.currentStep === STEPS.SELECT;
	}

	get isConfirmStep() {
		return this.currentStep === STEPS.CONFIRM;
	}

	get isCompleteStep() {
		return this.currentStep === STEPS.COMPLETE;
	}

	get hasParsedIds() {
		return this.parsedIds && this.parsedIds.length > 0;
	}

	get parsedIdsCount() {
		return this.parsedIds ? this.parsedIds.length : 0;
	}

	get noSurveyTypesSelected() {
		return !this.isCustomerSelected && !this.isTrainerSelected && !this.isParticipantSelected;
	}

	get hasSurveysFound() {
		return this.surveysToRegenerate && this.surveysToRegenerate.length > 0;
	}

	get surveysFoundCount() {
		return this.surveysToRegenerate ? this.surveysToRegenerate.length : 0;
	}

	get successCount() {
		return this.regenerationResult ? this.regenerationResult.successCount : 0;
	}

	get failureCount() {
		return this.regenerationResult ? this.regenerationResult.failureCount : 0;
	}

	get hasErrors() {
		return this.errorMessages && this.errorMessages.length > 0;
	}

	get showBackButton() {
		return this.currentStep === STEPS.SELECT || this.currentStep === STEPS.CONFIRM;
	}

	get showNextButton() {
		return this.currentStep === STEPS.UPLOAD || this.currentStep === STEPS.SELECT;
	}

	get showRegenerateButton() {
		return this.currentStep === STEPS.CONFIRM;
	}

	get showFinishButton() {
		return this.currentStep === STEPS.COMPLETE;
	}

	get isNextDisabled() {
		if (this.currentStep === STEPS.UPLOAD) {
			return !this.hasParsedIds || this.isProcessing;
		}
		if (this.currentStep === STEPS.SELECT) {
			return this.noSurveyTypesSelected || !this.hasSurveysFound || this.isProcessing;
		}
		return false;
	}

	handleFileUpload(event) {
		const uploadedFiles = event.detail.files;
		if (uploadedFiles && uploadedFiles.length > 0) {
			const file = uploadedFiles[0];
			this.readFileContent(file);
		}
	}

	readFileContent(file) {
		this.isProcessing = true;
		this.uploadError = '';

		const reader = new FileReader();
		reader.onload = (e) => {
			const fileContent = e.target.result;
			this.parseFileContent(fileContent);
		};
		reader.onerror = () => {
			this.uploadError = 'Error reading file. Please try again.';
			this.isProcessing = false;
		};
		reader.readAsText(file);
	}

	handleManualInput(event) {
		this.manualIds = event.target.value;
		if (this.manualIds) {
			this.parseFileContent(this.manualIds);
		} else {
			this.parsedIds = [];
			this.surveysToRegenerate = [];
			this.uploadError = '';
		}
	}

	parseFileContent(content) {
		this.isProcessing = true;
		this.uploadError = '';
		this.surveysToRegenerate = []; // Clear previous surveys when new IDs are parsed

		parseTrainingRequestIds({ fileContent: content })
			.then((result) => {
				// Handle both direct List/array responses and wrapper-object responses
				if (Array.isArray(result)) {
					this.parsedIds = result || [];
					if (this.parsedIds.length === 0) {
						this.uploadError = 'No valid Training Request IDs found in the file.';
					}
				} else if (result && result.success) {
					this.parsedIds = result.trainingRequestIds || [];
					if (this.parsedIds.length === 0) {
						this.uploadError = 'No valid Training Request IDs found in the file.';
					}
				} else {
					this.uploadError = result && result.message ? result.message : 'Error parsing file content.';
					this.parsedIds = [];
				}
				this.isProcessing = false;
			})
			.catch((error) => {
				this.uploadError = error.body?.message || 'Error parsing file content.';
				this.parsedIds = [];
				this.isProcessing = false;
			});
	}

	handleSurveyTypeChange(event) {
		const surveyType = event.target.value;
		const isChecked = event.target.checked;

		if (surveyType === 'Customer') {
			this.isCustomerSelected = isChecked;
		} else if (surveyType === 'Trainer') {
			this.isTrainerSelected = isChecked;
		} else if (surveyType === 'Participant') {
			this.isParticipantSelected = isChecked;
		}

		// Reload surveys on any toggle to prevent stale data
		if (this.parsedIds.length > 0) {
			this.loadSurveysForRegeneration();
		} else {
			// Clear surveys if no IDs are available
			this.surveysToRegenerate = [];
		}
	}

	loadSurveysForRegeneration() {
		if (this.noSurveyTypesSelected || this.parsedIds.length === 0) {
			this.surveysToRegenerate = [];
			return;
		}

		this.isLoadingSurveys = true;
		const selectedTypes = [];
		if (this.isCustomerSelected) selectedTypes.push('Customer');
		if (this.isTrainerSelected) selectedTypes.push('Trainer');
		if (this.isParticipantSelected) selectedTypes.push('Participant');

		getSurveysForRegeneration({
			trainingRequestIds: this.parsedIds,
			surveyTypes: selectedTypes
		})
			.then((result) => {
				if (result.success) {
					this.surveysToRegenerate = result.surveys.map((survey) => ({
						surveyId: survey.surveyId,
						surveyName: survey.surveyName,
						surveyType: survey.surveyType,
						trainingRequestName: survey.trainingRequestName
					}));
				} else {
					this.showToast('Error', result.message, 'error');
					this.surveysToRegenerate = [];
				}
				this.isLoadingSurveys = false;
			})
			.catch((error) => {
				this.showToast('Error', error.body?.message || 'Error loading surveys', 'error');
				this.surveysToRegenerate = [];
				this.isLoadingSurveys = false;
			});
	}

	handleNext() {
		if (this.currentStep === STEPS.UPLOAD) {
			if (this.hasParsedIds) {
				this.currentStep = STEPS.SELECT;
			}
		} else if (this.currentStep === STEPS.SELECT) {
			if (!this.noSurveyTypesSelected && this.hasSurveysFound) {
				this.currentStep = STEPS.CONFIRM;
			}
		}
	}

	handleBack() {
		if (this.currentStep === STEPS.SELECT) {
			this.currentStep = STEPS.UPLOAD;
		} else if (this.currentStep === STEPS.CONFIRM) {
			this.currentStep = STEPS.SELECT;
		}
	}

	handleRegenerate() {
		this.isProcessing = true;

		const surveyIds = this.surveysToRegenerate.map((survey) => survey.surveyId);
		const surveyTypes = this.surveysToRegenerate.map((survey) => survey.surveyType);

		regenerateSurveyInvitations({ surveyIds, surveyTypes })
			.then((result) => {
				this.regenerationResult = result;
				this.regenerationSuccess = result.success;
				this.regenerationMessage = result.message;

				if (result.errors && result.errors.length > 0) {
					this.errorMessages = result.errors;
				}

				this.currentStep = STEPS.COMPLETE;
				this.isProcessing = false;

				if (result.success) {
					this.showToast('Success', result.message, 'success');
				} else {
					this.showToast('Error', result.message, 'error');
				}
			})
			.catch((error) => {
				this.regenerationSuccess = false;
				this.regenerationMessage = error.body?.message || 'Error regenerating invitations';
				this.errorMessages = [error.body?.message || 'Unknown error occurred'];
				this.currentStep = STEPS.COMPLETE;
				this.isProcessing = false;
				this.showToast('Error', this.regenerationMessage, 'error');
			});
	}

	handleReset() {
		this.currentStep = STEPS.UPLOAD;
		this.manualIds = '';
		this.parsedIds = [];
		this.uploadError = '';
		this.isCustomerSelected = false;
		this.isTrainerSelected = false;
		this.isParticipantSelected = false;
		this.surveysToRegenerate = [];
		this.regenerationResult = null;
		this.regenerationSuccess = false;
		this.regenerationMessage = '';
		this.errorMessages = [];
		this.isProcessing = false;
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
