import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import getSurveyData from '@salesforce/apex/SurveyTakerController.getSurveyData';
import submitSurveyResponses from '@salesforce/apex/SurveyTakerController.submitSurveyResponses';

export default class SurveyTaker extends LightningElement {
	@api recordId;
	@api caseId = null;
	@api contactId = null;

	/**
	 * Wire adapter to get current page reference and extract URL state parameters
	 * This enables the component to read c__recordId from URL when navigating via tabs
	 */
	@wire(CurrentPageReference)
	handlePageReference(pageRef) {
		if (pageRef && pageRef.state) {
			// Read recordId from URL state if not already set via @api property
			if (pageRef.state.c__recordId && !this.recordId) {
				this.recordId = pageRef.state.c__recordId;
				// Load survey data if component already initialized
				if (this._isConnected) {
					this.loadSurveyData();
				}
			}
			// Read caseId from URL state if not already set
			if (pageRef.state.c__caseId && !this.caseId) {
				this.caseId = pageRef.state.c__caseId;
			}
			// Read contactId from URL state if not already set
			if (pageRef.state.c__contactId && !this.contactId) {
				this.contactId = pageRef.state.c__contactId;
			}
		}
	}

	_isConnected = false;

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
		this._isConnected = true;
		// Only load survey data if recordId is available
		// If recordId comes from URL state via wire adapter, it will load there instead
		if (this.recordId) {
			this.loadSurveyData();
		}
	}

	loadSurveyData() {
		this.isLoading = true;
		this.error = null;

		getSurveyData({
			surveyId: this.recordId,
			caseId: this.caseId,
			contactId: this.contactId
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
			surveyId: this.recordId,
			responses: responseArray,
			caseId: this.caseId,
			contactId: this.contactId,
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
