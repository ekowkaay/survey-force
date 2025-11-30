import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import getSurveyData from '@salesforce/apex/SurveyTakerController.getSurveyData';
import submitSurveyResponses from '@salesforce/apex/SurveyTakerController.submitSurveyResponses';

export default class SurveyTaker extends LightningElement {
	@api recordId;
	@api caseId = null;
	@api contactId = null;

	// Internal properties to store URL state values
	_urlRecordId = null;
	_urlCaseId = null;
	_urlContactId = null;

	/**
	 * Wire adapter to get current page reference and extract URL state parameters
	 * This enables the component to read c__recordId from URL when navigating via tabs
	 */
	@wire(CurrentPageReference)
	handlePageReference(pageRef) {
		if (!pageRef) {
			return;
		}
		if (pageRef.state) {
			// Store URL state values in internal properties
			if (pageRef.state.c__recordId) {
				this._urlRecordId = pageRef.state.c__recordId;
			}
			if (pageRef.state.c__caseId) {
				this._urlCaseId = pageRef.state.c__caseId;
			}
			if (pageRef.state.c__contactId) {
				this._urlContactId = pageRef.state.c__contactId;
			}
			// Load survey data if we have a new recordId that differs from what was already loaded
			const currentId = this.effectiveRecordId;
			if (currentId && currentId !== this._loadedRecordId) {
				this.loadSurveyData();
			}
		}
	}

	/**
	 * Computed getter for effective recordId - prefers @api property, falls back to URL state
	 */
	get effectiveRecordId() {
		return this.recordId || this._urlRecordId;
	}

	/**
	 * Computed getter for effective caseId - prefers @api property, falls back to URL state
	 */
	get effectiveCaseId() {
		return this.caseId || this._urlCaseId;
	}

	/**
	 * Computed getter for effective contactId - prefers @api property, falls back to URL state
	 */
	get effectiveContactId() {
		return this.contactId || this._urlContactId;
	}

	// Track the recordId that was successfully loaded to prevent double-loading
	_loadedRecordId = null;

	@track isLoading = true;
	@track isSubmitting = false;
	@track isSubmitted = false;
	@track error = null;

	@track surveyName = '';
	@track surveyHeader = '';
	@track showSurveyName = true;
	@track thankYouText = '';
	@track questions = [];
	@track responses = {};
	@track isInternal = true;
	@track anonymousOption = 'User';
	@track anonymousValue = 'named';
	@track canChooseAnonymous = false;

	get visibleQuestions() {
		return this.questions.filter((q) => !q.hideOnSurvey);
	}

	get anonymousOptions() {
		return [
			{ label: 'Submit with my name', value: 'named' },
			{ label: 'Submit anonymously', value: 'anonymous' }
		];
	}

	connectedCallback() {
		// Only load survey data if recordId is available and not already loaded
		// If recordId comes from URL state via wire adapter, it will load there instead
		const currentId = this.effectiveRecordId;
		if (currentId && currentId !== this._loadedRecordId) {
			this.loadSurveyData();
		}
	}

	loadSurveyData() {
		this.isLoading = true;
		this.error = null;
		const recordIdToLoad = this.effectiveRecordId;

		getSurveyData({
			surveyId: recordIdToLoad,
			caseId: this.effectiveCaseId,
			contactId: this.effectiveContactId
		})
			.then((result) => {
				if (result && result.survey) {
					this.surveyName = result.survey.Name;
					this.surveyHeader = result.survey.Survey_Header__c || '';
					this.showSurveyName = !result.survey.Hide_Survey_Name__c;
					this.thankYouText = result.survey.Thank_You_Text__c || 'Your survey response has been recorded. Thank you!';
					this.questions = result.questions || [];
					this.isInternal = result.isInternal;
					this.anonymousOption = result.anonymousOption;

					// Can choose anonymous only if internal user and survey allows non-anonymous
					this.canChooseAnonymous = this.isInternal && this.anonymousOption !== 'Anonymous';

					// Initialize responses map
					this.initializeResponses();
					// Track which recordId was successfully loaded to prevent duplicate loads
					this._loadedRecordId = recordIdToLoad;
				} else {
					this.error = 'Survey not found or not available';
				}
				this.isLoading = false;
			})
			.catch((error) => {
				this.error = error.body?.message || error.message || 'Error loading survey';
				this.isLoading = false;
			});
	}

	initializeResponses() {
		this.responses = {};
		this.questions.forEach((q) => {
			if (q.questionType === 'Multi-Select--Vertical') {
				this.responses[q.id] = { questionId: q.id, response: '', responses: [] };
			} else {
				this.responses[q.id] = { questionId: q.id, response: '', responses: null };
			}
		});
	}

	handleResponseChange(event) {
		const { questionId, value, checked, questionType } = event.detail;

		if (!this.responses[questionId]) {
			this.responses[questionId] = { questionId, response: '', responses: [] };
		}

		if (questionType === 'Multi-Select--Vertical') {
			// Handle checkbox changes
			if (!this.responses[questionId].responses) {
				this.responses[questionId].responses = [];
			}

			if (checked) {
				if (!this.responses[questionId].responses.includes(value)) {
					this.responses[questionId].responses.push(value);
				}
			} else {
				this.responses[questionId].responses = this.responses[questionId].responses.filter((v) => v !== value);
			}
		} else {
			// Handle single value changes (free text, single select)
			this.responses[questionId].response = value;
		}
	}

	handleAnonymousChange(event) {
		this.anonymousValue = event.detail.value;
	}

	handleSubmit() {
		// Validate required fields
		const validationError = this.validateResponses();
		if (validationError) {
			this.showToast('Validation Error', validationError, 'error');
			return;
		}

		this.isSubmitting = true;

		// Convert responses object to array
		const responseArray = Object.values(this.responses).filter((r) => r.response || (r.responses && r.responses.length > 0));

		const isAnonymous = this.anonymousValue === 'anonymous' || this.anonymousOption === 'Anonymous';

		submitSurveyResponses({
			surveyId: this.effectiveRecordId,
			responses: responseArray,
			caseId: this.effectiveCaseId,
			contactId: this.effectiveContactId,
			isAnonymous: isAnonymous
		})
			.then((result) => {
				if (result.success) {
					this.thankYouText = result.thankYouText || this.thankYouText;
					this.isSubmitted = true;
					this.showToast('Success', 'Survey submitted successfully!', 'success');
				} else {
					this.showToast('Error', result.message || 'Error submitting survey', 'error');
				}
				this.isSubmitting = false;
			})
			.catch((error) => {
				this.showToast('Error', error.body?.message || 'Error submitting survey', 'error');
				this.isSubmitting = false;
			});
	}

	validateResponses() {
		for (const question of this.visibleQuestions) {
			if (question.required) {
				const response = this.responses[question.id];
				if (!response) {
					return `Please answer question ${question.orderNumber}: ${question.question}`;
				}

				if (question.questionType === 'Multi-Select--Vertical') {
					if (!response.responses || response.responses.length === 0) {
						return `Please answer question ${question.orderNumber}: ${question.question}`;
					}
				} else {
					if (!response.response || response.response.trim() === '') {
						return `Please answer question ${question.orderNumber}: ${question.question}`;
					}
				}
			}
		}
		return null;
	}

	showToast(title, message, variant) {
		const event = new ShowToastEvent({
			title: title,
			message: message,
			variant: variant
		});
		this.dispatchEvent(event);
	}
}
