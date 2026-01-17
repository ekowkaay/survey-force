import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import regenerateSurveyLinks from '@salesforce/apex/SurveyRegenerationController.regenerateSurveyLinks';

export default class SurveyRegeneration extends LightningElement {
	@track selectedRecords = [];
	@track pendingRecord = null;
	@track recordPickerValue = null;
	@track useBulkInput = false;
	@track bulkInputValue = '';
	@track regenerateParticipant = true;
	@track regenerateCustomer = true;
	@track regenerateTrainer = true;
	@track useCustomSettings = false;
	@track relatedRecordObjectApiName = 'Training_Request__c';
	@track participantSurveyFieldApiName = 'Participant_Survey__c';
	@track participantSurveyLinkFieldApiName = 'Participant_Survey__c';
	@track participantObjectApiName = 'Participants__c';
	@track participantLookupFieldApiName = 'Training_Request__c';
	@track participantNameFieldApiName = 'Participant_Name__c';
	@track participantEmailFieldApiName = 'Email__c';
	@track customerSurveyFieldApiName = 'Customer_Survey__c';
	@track trainerSurveyFieldApiName = 'Trainer_Survey__c';
	@track trainingTypeFieldApiName = 'Training_Type__c';
	@track lastPrefillIds = null;

	// UI State
	@track isLoading = false;
	@track loadingMessage = 'Preparing to regenerate surveys...';
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

	recordColumns = [
		{ label: 'Record', fieldName: 'name' },
		{ label: 'Record Id', fieldName: 'id' },
		{
			type: 'button-icon',
			fixedWidth: 50,
			typeAttributes: {
				iconName: 'utility:close',
				name: 'remove',
				title: 'Remove',
				variant: 'bare',
				alternativeText: 'Remove'
			}
		}
	];

	get isInputValid() {
		return this.selectedRecords.length > 0;
	}

	get isBulkInputEmpty() {
		return !this.bulkInputValue || this.bulkInputValue.trim().length === 0;
	}

	get hasObjectApiName() {
		return !this.useCustomSettings || (this.relatedRecordObjectApiName && this.relatedRecordObjectApiName.trim().length > 0);
	}

	get hasRequiredFieldConfig() {
		if (!this.useCustomSettings) {
			return true;
		}

		const hasParticipantField = !this.regenerateParticipant || (this.participantSurveyFieldApiName && this.participantSurveyFieldApiName.trim().length > 0);
		const hasParticipantLinkField = !this.regenerateParticipant || (this.participantSurveyLinkFieldApiName && this.participantSurveyLinkFieldApiName.trim().length > 0);
		const hasParticipantObject = !this.regenerateParticipant || (this.participantObjectApiName && this.participantObjectApiName.trim().length > 0);
		const hasParticipantLookup = !this.regenerateParticipant || (this.participantLookupFieldApiName && this.participantLookupFieldApiName.trim().length > 0);
		const hasParticipantName = !this.regenerateParticipant || (this.participantNameFieldApiName && this.participantNameFieldApiName.trim().length > 0);
		const hasParticipantEmail = !this.regenerateParticipant || (this.participantEmailFieldApiName && this.participantEmailFieldApiName.trim().length > 0);
		const hasCustomerField = !this.regenerateCustomer || (this.customerSurveyFieldApiName && this.customerSurveyFieldApiName.trim().length > 0);
		const hasTrainerField = !this.regenerateTrainer || (this.trainerSurveyFieldApiName && this.trainerSurveyFieldApiName.trim().length > 0);

		return (
			hasParticipantField &&
			hasParticipantLinkField &&
			hasParticipantObject &&
			hasParticipantLookup &&
			hasParticipantName &&
			hasParticipantEmail &&
			hasCustomerField &&
			hasTrainerField
		);
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
		return this.isInputValid && this.hasAtLeastOneSurveyTypeSelected && this.hasObjectApiName && this.hasRequiredFieldConfig && !this.isLoading;
	}

	get isNextDisabled() {
		return !this.canProceed;
	}

	get recordPickerObjectApiName() {
		if (!this.useCustomSettings) {
			return 'Training_Request__c';
		}
		return this.relatedRecordObjectApiName && this.relatedRecordObjectApiName.trim().length > 0 ? this.relatedRecordObjectApiName.trim() : 'Training_Request__c';
	}

	get isAddRecordDisabled() {
		return !this.pendingRecord;
	}

	get hasSelectedRecords() {
		return this.selectedRecords.length > 0;
	}

	get selectedRecordCount() {
		return this.selectedRecords.length;
	}

	get selectedSurveyTypesText() {
		const types = [];
		if (this.regenerateParticipant) types.push('Participant');
		if (this.regenerateCustomer) types.push('Customer');
		if (this.regenerateTrainer) types.push('Trainer');
		return types.length > 0 ? types.join(', ') : 'None';
	}

	get selectedRecordsPreview() {
		// Show max 10 records in preview
		return this.selectedRecords.slice(0, 10);
	}

	get showSelectedRecordsList() {
		return this.selectedRecords.length > 0 && this.selectedRecords.length <= 20;
	}

	@wire(CurrentPageReference)
	handlePageReference(pageReference) {
		if (!pageReference || !pageReference.state) {
			return;
		}

		const idsParam = pageReference.state.c__ids || pageReference.state.ids;
		if (!idsParam || idsParam === this.lastPrefillIds) {
			return;
		}

		this.lastPrefillIds = idsParam;
		const ids = this.parsePrefillIds(idsParam);
		this.addSelectedRecordsFromIds(ids);
	}

	parsePrefillIds(idsParam) {
		if (!idsParam) {
			return [];
		}

		return idsParam
			.split(/[,\s;]+/)
			.map((value) => value.trim())
			.filter((value) => value);
	}

	addSelectedRecordsFromIds(ids) {
		if (!ids || ids.length === 0) {
			return;
		}

		const existingIds = new Set(this.selectedRecords.map((record) => record.id));
		const newRecords = [];

		ids.forEach((recordId) => {
			if (!existingIds.has(recordId)) {
				newRecords.push({ id: recordId, name: recordId });
				existingIds.add(recordId);
			}
		});

		if (newRecords.length > 0) {
			this.selectedRecords = [...this.selectedRecords, ...newRecords];
		}
	}

	handleRecordPickerChange(event) {
		const { recordId, recordName } = event.detail;
		if (recordId) {
			this.pendingRecord = {
				id: recordId,
				name: recordName || recordId
			};
			this.recordPickerValue = recordId;
		} else {
			this.pendingRecord = null;
			this.recordPickerValue = null;
		}
	}

	handleAddRecord() {
		if (!this.pendingRecord) {
			return;
		}

		const exists = this.selectedRecords.some((record) => record.id === this.pendingRecord.id);
		if (exists) {
			this.showToast('Info', 'That record is already in the list.', 'info');
			return;
		}

		this.selectedRecords = [...this.selectedRecords, this.pendingRecord];
		this.pendingRecord = null;
		this.recordPickerValue = null;
	}

	handleRowAction(event) {
		if (event.detail.action.name !== 'remove') {
			return;
		}

		const recordId = event.detail.row.id;
		this.selectedRecords = this.selectedRecords.filter((record) => record.id !== recordId);
	}

	handleClearAll() {
		this.selectedRecords = [];
		this.pendingRecord = null;
		this.recordPickerValue = null;
		this.bulkInputValue = '';
	}

	handleBulkInputToggle(event) {
		this.useBulkInput = event.target.checked;
	}

	handleBulkInputChange(event) {
		this.bulkInputValue = event.target.value;
	}

	handleParseBulkInput() {
		if (this.isBulkInputEmpty) {
			this.showToast('Error', 'Please enter at least one record ID or name.', 'error');
			return;
		}

		const ids = this.parsePrefillIds(this.bulkInputValue);
		if (ids.length === 0) {
			this.showToast('Error', 'No valid record IDs found in the input.', 'error');
			return;
		}

		this.addSelectedRecordsFromIds(ids);
		this.showToast('Success', `Added ${ids.length} record(s) to the list.`, 'success');
		this.bulkInputValue = '';
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

	handleCustomSettingsToggle(event) {
		const newValue = event.target.checked;

		// Show confirmation if toggling and records are selected
		if (newValue !== this.useCustomSettings && this.selectedRecords.length > 0) {
			if (!confirm('Changing this setting will clear your selected records. Continue?')) {
				// Revert the toggle
				event.target.checked = this.useCustomSettings;
				return;
			}
		}

		this.useCustomSettings = newValue;
		if (!this.useCustomSettings) {
			this.relatedRecordObjectApiName = 'Training_Request__c';
			this.participantSurveyFieldApiName = 'Participant_Survey__c';
			this.participantSurveyLinkFieldApiName = 'Participant_Survey__c';
			this.participantObjectApiName = 'Participants__c';
			this.participantLookupFieldApiName = 'Training_Request__c';
			this.participantNameFieldApiName = 'Participant_Name__c';
			this.participantEmailFieldApiName = 'Email__c';
			this.customerSurveyFieldApiName = 'Customer_Survey__c';
			this.trainerSurveyFieldApiName = 'Trainer_Survey__c';
			this.trainingTypeFieldApiName = 'Training_Type__c';
			this.regenerateParticipant = true;
			this.handleClearAll();
		}
	}

	handleObjectApiNameChange(event) {
		this.relatedRecordObjectApiName = event.target.value;
		this.handleClearAll();
	}

	handleParticipantFieldChange(event) {
		this.participantSurveyFieldApiName = event.target.value;
	}

	handleParticipantLinkFieldChange(event) {
		this.participantSurveyLinkFieldApiName = event.target.value;
	}

	handleParticipantObjectChange(event) {
		this.participantObjectApiName = event.target.value;
	}

	handleParticipantLookupChange(event) {
		this.participantLookupFieldApiName = event.target.value;
	}

	handleParticipantNameChange(event) {
		this.participantNameFieldApiName = event.target.value;
	}

	handleParticipantEmailChange(event) {
		this.participantEmailFieldApiName = event.target.value;
	}

	handleCustomerFieldChange(event) {
		this.customerSurveyFieldApiName = event.target.value;
	}

	handleTrainerFieldChange(event) {
		this.trainerSurveyFieldApiName = event.target.value;
	}

	handleTrainingTypeFieldChange(event) {
		this.trainingTypeFieldApiName = event.target.value;
	}

	handleNext() {
		if (!this.canProceed) {
			this.showToast('Error', 'Please select records, choose at least one survey type, and complete the required configuration.', 'error');
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
		this.selectedRecords = [];
		this.pendingRecord = null;
		this.recordPickerValue = null;
		this.useBulkInput = false;
		this.bulkInputValue = '';
		this.regenerateParticipant = true;
		this.regenerateCustomer = true;
		this.regenerateTrainer = true;
		this.useCustomSettings = false;
		this.relatedRecordObjectApiName = 'Training_Request__c';
		this.participantSurveyFieldApiName = 'Participant_Survey__c';
		this.participantSurveyLinkFieldApiName = 'Participant_Survey__c';
		this.participantObjectApiName = 'Participants__c';
		this.participantLookupFieldApiName = 'Training_Request__c';
		this.participantNameFieldApiName = 'Participant_Name__c';
		this.participantEmailFieldApiName = 'Email__c';
		this.customerSurveyFieldApiName = 'Customer_Survey__c';
		this.trainerSurveyFieldApiName = 'Trainer_Survey__c';
		this.trainingTypeFieldApiName = 'Training_Type__c';
		this.showConfirmation = false;
		this.showResults = false;
		this.success = false;
		this.message = '';
		this.errorDetails = '';
	}

	executeRegeneration() {
		this.isLoading = true;
		this.loadingMessage = `Processing ${this.selectedRecords.length} record(s)...`;

		const idsArray = this.selectedRecords.map((record) => record.id);

		const request = {
			trainingRequestIds: idsArray,
			regenerateParticipant: this.regenerateParticipant,
			regenerateCustomer: this.regenerateCustomer,
			regenerateTrainer: this.regenerateTrainer,
			relatedRecordObjectApiName: this.useCustomSettings ? this.relatedRecordObjectApiName : null,
			participantSurveyFieldApiName: this.useCustomSettings ? this.participantSurveyFieldApiName : null,
			participantSurveyLinkFieldApiName: this.useCustomSettings ? this.participantSurveyLinkFieldApiName : null,
			participantObjectApiName: this.useCustomSettings ? this.participantObjectApiName : null,
			participantLookupFieldApiName: this.useCustomSettings ? this.participantLookupFieldApiName : null,
			participantNameFieldApiName: this.useCustomSettings ? this.participantNameFieldApiName : null,
			participantEmailFieldApiName: this.useCustomSettings ? this.participantEmailFieldApiName : null,
			customerSurveyFieldApiName: this.useCustomSettings ? this.customerSurveyFieldApiName : null,
			trainerSurveyFieldApiName: this.useCustomSettings ? this.trainerSurveyFieldApiName : null,
			trainingTypeFieldApiName: this.useCustomSettings ? this.trainingTypeFieldApiName : null
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
