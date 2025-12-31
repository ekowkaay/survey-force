import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import getSurveyData from '@salesforce/apex/SurveyTakerController.getSurveyData';
import getSurveyDataByToken from '@salesforce/apex/SurveyTakerController.getSurveyDataByToken';
import submitSurveyResponses from '@salesforce/apex/SurveyTakerController.submitSurveyResponses';
import submitSurveyWithToken from '@salesforce/apex/SurveyTakerController.submitSurveyWithToken';

export default class SurveyTaker extends LightningElement {
	@api recordId;
	@api caseId = null;
	@api contactId = null;

	// Internal properties to store URL state values
	_urlRecordId = null;
	_urlCaseId = null;
	_urlContactId = null;
	_urlToken = null;

	/**
	 * Wire adapter to get current page reference and extract URL state parameters
	 * This enables the component to read c__recordId from URL when navigating via tabs
	 */
	@wire(CurrentPageReference)
	handlePageReference(pageRef) {
		if (!pageRef) {
			return;
		}
		// Update URL state values - set to value from URL or null if not present
		const state = pageRef.state || {};
		this._urlRecordId = state.c__recordId || null;
		this._urlCaseId = state.c__caseId || null;
		this._urlContactId = state.c__contactId || null;
		this._urlToken = state.c__token || state.token || null;

		// Load survey data if we have a new recordId or token that differs from what was already loaded
		// and not currently loading to prevent race conditions
		if (this.shouldLoadSurveyData()) {
			this.loadSurveyData();
		}
	}

	/**
	 * Helper method to determine if survey data should be loaded
	 * @returns {boolean} True if survey data should be loaded
	 */
	shouldLoadSurveyData() {
		const currentId = this.effectiveRecordId;
		const currentToken = this.effectiveToken;
		const hasIdentifier = currentId || currentToken;
		const isNewData = currentId !== this._loadedRecordId || currentToken !== this._loadedToken;
		const notCurrentlyLoading = !this.isLoading;

		return hasIdentifier && isNewData && notCurrentlyLoading;
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

	/**
	 * Computed getter for effective token - from URL state
	 */
	get effectiveToken() {
		return this._urlToken;
	}

	// Track the recordId and token that was successfully loaded to prevent double-loading
	_loadedRecordId = null;
	_loadedToken = null;

	@track isLoading = false;
	@track isSubmitting = false;
	@track isSubmitted = false;
	@track error = null;

	@track surveyName = '';
	@track surveyHeader = '';
	@track invitationHeader = '';
	@track showSurveyName = true;
	@track thankYouText = '';
	@track questions = [];
	@track responses = {};
	@track isInternal = true;
	@track anonymousOption = 'User';
	@track anonymousValue = 'named';
	@track canChooseAnonymous = false;

	// New properties for one-question-at-a-time navigation
	@track currentQuestionIndex = 0;
	@track showAnonymousSelection = false;

	get visibleQuestions() {
		return this.questions.filter((q) => !q.hideOnSurvey);
	}

	get currentQuestion() {
		const visible = this.visibleQuestions;
		return visible[this.currentQuestionIndex] || null;
	}

	get currentQuestionNumber() {
		return this.currentQuestionIndex + 1;
	}

	get totalQuestions() {
		return this.visibleQuestions.length;
	}

	get hasQuestions() {
		return this.totalQuestions > 0;
	}

	get headerTitle() {
		if (this.showSurveyName && this.surveyName) {
			return this.surveyName;
		}
		return 'SurveyApp';
	}

	get introHeading() {
		if (this.showSurveyName && this.surveyName) {
			return this.surveyName;
		}
		return 'We value your feedback!';
	}

	get introSubheading() {
		if (this.invitationHeader) {
			return this.invitationHeader;
		}

		if (this.surveyHeader) {
			return this.surveyHeader;
		}

		return 'Please take a moment to complete this evaluation.';
	}

	get questionHelpText() {
		if (this.currentQuestion) {
			if (this.currentQuestion.helpText) {
				return this.currentQuestion.helpText;
			}

			if (this.currentQuestion.description) {
				return this.currentQuestion.description;
			}
		}

		return 'Please share your perspective with the options below.';
	}

	get progressPercentage() {
		if (this.totalQuestions === 0) return 0;
		return Math.round((this.currentQuestionNumber / this.totalQuestions) * 100);
	}

	get isFirstQuestion() {
		return this.currentQuestionIndex === 0;
	}

	get isLastQuestion() {
		return this.currentQuestionIndex === this.totalQuestions - 1;
	}

	get isFreeText() {
		return this.currentQuestion && this.currentQuestion.questionType === 'Free Text';
	}

	get isSingleSelect() {
		if (!this.currentQuestion) return false;
		const type = this.currentQuestion.questionType;
		return type === 'Single Select--Vertical' || type === 'Single Select--Horizontal';
	}

	get isMultiSelect() {
		if (!this.currentQuestion) return false;
		return this.currentQuestion.questionType === 'Multi-Select--Vertical';
	}

	get isHorizontalLayout() {
		if (!this.currentQuestion) return false;
		return this.currentQuestion.questionType === 'Single Select--Horizontal';
	}

	get radioGroupClass() {
		return this.isHorizontalLayout ? 'radio-horizontal' : 'radio-vertical';
	}

	get currentResponse() {
		if (!this.currentQuestion) return '';
		const response = this.responses[this.currentQuestion.id];
		return response ? response.response : '';
	}

	get progressBarStyle() {
		return `width: ${this.progressPercentage}%`;
	}

	get anonymousOptions() {
		return [
			{ label: 'Submit with my name', value: 'named' },
			{ label: 'Submit anonymously', value: 'anonymous' }
		];
	}

	connectedCallback() {
		// Only load survey data if recordId or token is available and not already loaded
		// Also check if not currently loading to prevent race conditions
		// If recordId comes from URL state via wire adapter, it will load there instead
		if (this.shouldLoadSurveyData()) {
			this.loadSurveyData();
		}
	}

	loadSurveyData() {
		this.isLoading = true;
		this.error = null;
		const recordIdToLoad = this.effectiveRecordId;
		const tokenToLoad = this.effectiveToken;

		// Use token-based loading if token is provided
		let dataPromise;
		if (tokenToLoad) {
			dataPromise = getSurveyDataByToken({ token: tokenToLoad });
		} else {
			dataPromise = getSurveyData({
				surveyId: recordIdToLoad,
				caseId: this.effectiveCaseId,
				contactId: this.effectiveContactId
			});
		}

		dataPromise
			.then((result) => {
				// Track which recordId/token was loaded to prevent duplicate loads
				// Set this regardless of result to avoid unnecessary retry attempts
				this._loadedRecordId = recordIdToLoad;
				this._loadedToken = tokenToLoad;

				if (result && result.survey) {
					this.surveyName = result.survey.Name;
					this.surveyHeader = result.survey.Survey_Header__c || '';
					this.invitationHeader = result.invitationHeader || '';
					this.showSurveyName = !result.survey.Hide_Survey_Name__c;
					this.thankYouText = result.survey.Thank_You_Text__c || 'Your survey response has been recorded. Thank you!';
					this.questions = result.questions || [];
					this.isInternal = result.isInternal;
					this.anonymousOption = result.anonymousOption;

					// When using token, always anonymous (no choice)
					if (tokenToLoad) {
						this.canChooseAnonymous = false;
					} else {
						// Can choose anonymous only if internal user and survey allows non-anonymous
						this.canChooseAnonymous = this.isInternal && this.anonymousOption !== 'Anonymous';
					}

					// Initialize responses map
					this.initializeResponses();
				} else {
					this.error = 'Survey not found or not available';
				}
				this.isLoading = false;
			})
			.catch((err) => {
				this.error = err.body?.message || err.message || 'Error loading survey';
				this.isLoading = false;
			});
	}

	initializeResponses() {
		this.responses = {};
		this.questions.forEach((q) => {
			if (q.questionType === 'Multi-Select--Vertical') {
				this.responses[q.id] = { questionId: q.id, response: '', responses: [] };
				// Initialize checkbox checked state
				if (q.choices) {
					q.choices.forEach((choice) => {
						choice.checked = false;
					});
				}
			} else {
				this.responses[q.id] = { questionId: q.id, response: '', responses: null };
			}
		});
		// Reset to first question
		this.currentQuestionIndex = 0;
		this.showAnonymousSelection = false;
	}

	handleCurrentResponseChange(event) {
		if (!this.currentQuestion) return;

		const value = event.detail.value;
		const questionId = this.currentQuestion.id;

		if (!this.responses[questionId]) {
			this.responses[questionId] = { questionId, response: '', responses: null };
		}

		this.responses[questionId].response = value;
	}

	handleCheckboxChange(event) {
		if (!this.currentQuestion) return;

		const value = event.target.value;
		const checked = event.target.checked;
		const questionId = this.currentQuestion.id;

		if (!this.responses[questionId]) {
			this.responses[questionId] = { questionId, response: '', responses: [] };
		}

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

		// Update checked state in the choice object
		const choice = this.currentQuestion.choices.find((c) => c.value === value);
		if (choice) {
			choice.checked = checked;
		}
	}

	handleNext() {
		// Validate current question if required
		if (this.currentQuestion && this.currentQuestion.required) {
			const response = this.responses[this.currentQuestion.id];
			if (!response || (!response.response && (!response.responses || response.responses.length === 0))) {
				this.showToast('Required Field', 'Please answer this question before continuing.', 'error');
				return;
			}
		}

		if (this.isLastQuestion) {
			// Show anonymous selection if applicable, otherwise submit
			if (this.canChooseAnonymous) {
				this.showAnonymousSelection = true;
			} else {
				this.handleSubmit();
			}
		} else {
			this.currentQuestionIndex++;
		}
	}

	handlePrevious() {
		if (this.currentQuestionIndex > 0) {
			this.currentQuestionIndex--;
			this.showAnonymousSelection = false;
		}
	}

	handleBackToLastQuestion() {
		this.showAnonymousSelection = false;
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

		// Use token-based submission if token is provided
		let submitPromise;
		if (this.effectiveToken) {
			submitPromise = submitSurveyWithToken({
				token: this.effectiveToken,
				responses: responseArray
			});
		} else {
			submitPromise = submitSurveyResponses({
				surveyId: this.effectiveRecordId,
				responses: responseArray,
				caseId: this.effectiveCaseId,
				contactId: this.effectiveContactId,
				isAnonymous: isAnonymous
			});
		}

		submitPromise
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
			.catch((err) => {
				this.showToast('Error', err.body?.message || 'Error submitting survey', 'error');
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
