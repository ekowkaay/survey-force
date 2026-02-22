import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import getSurveyData from '@salesforce/apex/SurveyTakerController.getSurveyData';
import getSurveyDataByToken from '@salesforce/apex/SurveyTakerController.getSurveyDataByToken';
import submitSurveyResponses from '@salesforce/apex/SurveyTakerController.submitSurveyResponses';
import submitSurveyWithToken from '@salesforce/apex/SurveyTakerController.submitSurveyWithToken';

// Question type constants
const QUESTION_TYPE = {
	FREE_TEXT: 'Free Text',
	SINGLE_SELECT_VERTICAL: 'Single Select--Vertical',
	SINGLE_SELECT_HORIZONTAL: 'Single Select--Horizontal',
	MULTI_SELECT_VERTICAL: 'Multi-Select--Vertical'
};

export default class SurveyTaker extends NavigationMixin(LightningElement) {
	@api recordId;
	@api caseId = null;
	@api contactId = null;

	// Internal properties to store URL state values
	_urlRecordId = null;
	_urlCaseId = null;
	_urlContactId = null;
	_urlToken = null;
	_urlPreview = false;

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
		this._urlPreview = state.c__preview === 'true' || false;

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

	/**
	 * Check if component is in preview mode
	 */
	get isPreviewMode() {
		return this._urlPreview === true;
	}

	/**
	 * Get user context options for preview mode
	 */
	get userContextOptions() {
		return [
			{ label: 'Authenticated User', value: 'authenticated' },
			{ label: 'Anonymous User', value: 'anonymous' },
			{ label: 'Guest User', value: 'guest' }
		];
	}

	/**
	 * Get preview mode display context label
	 */
	get previewContextLabel() {
		const option = this.userContextOptions.find((opt) => opt.value === this.previewUserContext);
		return option ? option.label : 'Authenticated User';
	}

	/**
	 * Get mobile preview class
	 */
	get surveyShellClass() {
		return this.previewMobileMode ? 'survey-shell mobile-preview' : 'survey-shell';
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
	@track surveySubheader = '';
	@track invitationHeader = '';
	@track showSurveyName = true;
	@track thankYouText = '';
	@track expirationMessage = '';
	@track alreadySubmittedMessage = '';
	@track eventTopic = '';
	@track eventDate = '';
	@track questions = [];
	@track responses = {};
	@track isInternal = true;
	@track anonymousOption = 'User';
	@track anonymousValue = 'named';
	@track canChooseAnonymous = false;

	// New properties for one-question-at-a-time navigation
	@track currentQuestionIndex = 0;
	@track showAnonymousSelection = false;

	// Preview mode enhancements
	@track previewUserContext = 'authenticated'; // authenticated, anonymous, guest
	@track previewMobileMode = false;

	get visibleQuestions() {
		return this.questions.filter((q) => !q.hideOnSurvey);
	}

	get currentQuestion() {
		const visible = this.visibleQuestions;
		return visible[this.currentQuestionIndex] || null;
	}

	/**
	 * Get current question's choices with updated checked state and safe HTML IDs
	 */
	get currentQuestionChoices() {
		if (!this.currentQuestion || !this.currentQuestion.choices) {
			return [];
		}

		const currentResponse = this.currentResponse;
		return this.currentQuestion.choices.map((choice, index) => ({
			...choice,
			checked: choice.value === currentResponse,
			// Create a safe HTML ID by combining question ID with choice index
			safeId: `radio-${this.currentQuestion.id}-${index}`
		}));
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
		const rawHeading = this.invitationHeader || this.surveyHeader || 'We value your feedback!!!';
		return this.applyHeaderTokens(this.stripHtml(rawHeading));
	}

	get introSubheading() {
		const rawSubheading = this.surveySubheader || this.buildDefaultSubheading();
		return this.applyHeaderTokens(this.stripHtml(rawSubheading));
	}

	buildDefaultSubheading() {
		const topic = this.eventTopic || this.surveyName || 'the training';
		const dateText = this.eventDate ? ` on ${this.eventDate}` : '';
		return `Please take a moment to complete the evaluation survey for ${topic}${dateText}.`;
	}

	applyHeaderTokens(text) {
		if (!text) {
			return '';
		}

		const topic = this.eventTopic || this.surveyName || 'the training';
		const date = this.eventDate || '';
		const surveyName = this.surveyName || topic;

		return text
			.replace(/{{\s*Topic\s*}}/gi, topic)
			.replace(/{{\s*Date\s*}}/gi, date)
			.replace(/{{\s*Name\s*}}/gi, surveyName)
			.replace(/{{\s*SurveyName\s*}}/gi, surveyName)
			.replace(/{\s*Topic\s*}/gi, topic)
			.replace(/{\s*Date\s*}/gi, date)
			.replace(/{\s*Name\s*}/gi, surveyName)
			.replace(/{\s*SurveyName\s*}/gi, surveyName);
	}

	/**
	 * Safely strips HTML tags from a string by extracting only text content
	 * Note: This is safe because the temp element is never attached to the DOM,
	 * and we only extract textContent. The input comes from trusted Salesforce field data.
	 * @param {string} html - HTML string to strip tags from
	 * @returns {string} Plain text without HTML tags
	 */
	stripHtml(html) {
		if (!html) {
			return '';
		}
		const temp = document.createElement('div');
		temp.innerHTML = html;
		return temp.textContent || temp.innerText || '';
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

	get progressAriaLabel() {
		return `Survey progress: Question ${this.currentQuestionNumber} of ${this.totalQuestions}`;
	}

	get isFirstQuestion() {
		return this.currentQuestionIndex === 0;
	}

	get isLastQuestion() {
		return this.currentQuestionIndex === this.totalQuestions - 1;
	}

	get isFreeText() {
		return this.currentQuestion && this.currentQuestion.questionType === QUESTION_TYPE.FREE_TEXT;
	}

	get isSingleSelect() {
		if (!this.currentQuestion) return false;
		const type = this.currentQuestion.questionType;
		return type === QUESTION_TYPE.SINGLE_SELECT_VERTICAL || type === QUESTION_TYPE.SINGLE_SELECT_HORIZONTAL;
	}

	get isMultiSelect() {
		if (!this.currentQuestion) return false;
		return this.currentQuestion.questionType === QUESTION_TYPE.MULTI_SELECT_VERTICAL;
	}

	get isHorizontalLayout() {
		if (!this.currentQuestion) return false;
		return this.currentQuestion.questionType === QUESTION_TYPE.SINGLE_SELECT_HORIZONTAL;
	}

	get scaleChoices() {
		if (!this.currentQuestion || !this.currentQuestion.choices) {
			return [];
		}

		const total = this.currentQuestion.choices.length;
		const selected = this.currentResponse;

		return this.currentQuestion.choices.map((choice, index) => ({
			...choice,
			buttonText: choice.label || choice.value,
			showLabel: !!choice.label && (index === 0 || index === total - 1),
			buttonClass: selected === choice.value ? 'scaleButton active' : 'scaleButton',
			checked: selected === choice.value,
			radioId: `radio-${this.currentQuestion.id}-scale-${index}`
		}));
	}

	/**
	 * Check if scale has end labels (for horizontal layout)
	 * Returns true if both start and end labels are defined
	 */
	get hasScaleEndLabels() {
		if (!this.currentQuestion) {
			return false;
		}
		// Require both labels to be set for proper display
		return !!this.currentQuestion.scaleStartLabel && !!this.currentQuestion.scaleEndLabel;
	}

	/**
	 * Get the start label for the scale (e.g., "Very Difficult")
	 * Uses the static Scale_Start_Label__c field from the question
	 */
	get scaleStartLabel() {
		if (!this.currentQuestion) {
			return '';
		}
		return this.currentQuestion.scaleStartLabel || '';
	}

	/**
	 * Get the end label for the scale (e.g., "Very Easy")
	 * Uses the static Scale_End_Label__c field from the question
	 */
	get scaleEndLabel() {
		if (!this.currentQuestion) {
			return '';
		}
		return this.currentQuestion.scaleEndLabel || '';
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

	// Bound function reference for event listener cleanup
	boundHandleKeyDown = this.handleKeyDown.bind(this);

	connectedCallback() {
		// Only load survey data if recordId or token is available and not already loaded
		// Also check if not currently loading to prevent race conditions
		// If recordId comes from URL state via wire adapter, it will load there instead
		if (this.shouldLoadSurveyData()) {
			this.loadSurveyData();
		}

		// Add keyboard event listener for accessibility
		window.addEventListener('keydown', this.boundHandleKeyDown);
	}

	disconnectedCallback() {
		// Clean up event listener using the same bound reference
		window.removeEventListener('keydown', this.boundHandleKeyDown);
	}

	/**
	 * Handle keyboard shortcuts for better accessibility
	 * @param {KeyboardEvent} event - The keyboard event
	 */
	handleKeyDown(event) {
		// Don't handle keyboard events if in preview mode or survey is submitted/loading
		if (this.isPreviewMode || this.isSubmitted || this.isLoading || this.isSubmitting) {
			return;
		}

		// Don't interfere with typing in text inputs
		const target = event.target;
		if (target.tagName === 'TEXTAREA' || (target.tagName === 'INPUT' && target.type === 'text')) {
			return;
		}

		// Arrow key navigation
		if (event.key === 'ArrowRight' || event.key === 'ArrowDown') {
			event.preventDefault();
			if (!this.isLastQuestion && !this.showAnonymousSelection) {
				this.handleNext();
			}
		} else if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') {
			event.preventDefault();
			if (!this.isFirstQuestion || this.showAnonymousSelection) {
				this.handlePrevious();
			}
		}
		// Ctrl/Cmd + Enter to submit
		else if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
			event.preventDefault();
			if (this.isLastQuestion || this.showAnonymousSelection) {
				this.handleSubmit();
			}
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
					this.surveySubheader = result.survey.Survey_Subheader__c || '';
					this.invitationHeader = result.invitationHeader || '';
					this.eventTopic = result.eventTopic || '';
					this.eventDate = result.eventDate || '';
					this.showSurveyName = !result.survey.Hide_Survey_Name__c;
					this.thankYouText = result.survey.Thank_You_Text__c || 'Your survey response has been recorded. Thank you!';
					this.expirationMessage = result.expirationMessage || 'Thank you so much for your interest in sharing feedback. The survey window for this training has now closed.';
					this.alreadySubmittedMessage = result.alreadySubmittedMessage || 'This survey has already been completed.';
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
				// Enhanced error handling with user-friendly messages
				const errorMessage = err.body?.message || err.message || 'Unknown error';

				// Parse specific error types and provide actionable guidance
				if (errorMessage.toLowerCase().includes('survey not found')) {
					this.error = 'Survey not found. The survey may have been deleted or the link is incorrect. Please contact the survey administrator for a valid link.';
				} else if (errorMessage.toLowerCase().includes('permission') || errorMessage.toLowerCase().includes('access')) {
					this.error = "You don't have permission to access this survey. If you believe this is an error, please contact your administrator.";
				} else if (errorMessage.toLowerCase().includes('expired')) {
					this.error = 'This survey link has expired. Please request a new survey link from the survey administrator.';
				} else if (errorMessage.toLowerCase().includes('already submitted') || errorMessage.toLowerCase().includes('already completed')) {
					this.error = 'You have already submitted this survey. Each survey link can only be used once. Thank you for your response!';
				} else if (errorMessage.toLowerCase().includes('network') || errorMessage.toLowerCase().includes('connection')) {
					this.error = 'Network connection error. Please check your internet connection and try refreshing the page.';
				} else {
					this.error = `Unable to load survey: ${errorMessage}. Please try refreshing the page or contact support if the problem persists.`;
				}
				this.isLoading = false;
			});
	}

	initializeResponses() {
		this.responses = {};
		this.questions.forEach((q) => {
			if (q.questionType === QUESTION_TYPE.MULTI_SELECT_VERTICAL) {
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

		// Force LWC reactivity by reassigning the responses object
		this.responses = { ...this.responses };
	}

	handleRadioChange(event) {
		if (!this.currentQuestion) return;

		// Convert native input event to Lightning event format for handleCurrentResponseChange
		const syntheticEvent = {
			detail: {
				value: event.target.value
			}
		};

		this.handleCurrentResponseChange(syntheticEvent);
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

		// Force LWC reactivity by reassigning the responses object
		this.responses = { ...this.responses };
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
				// Focus on anonymous selection after render
				this.focusOnElement('#anonymous-heading');
			} else {
				this.handleSubmit();
			}
		} else {
			this.currentQuestionIndex++;
			// Focus on the question title after navigation for accessibility
			this.focusOnElement('#question-title');
		}
	}

	handlePrevious() {
		if (this.currentQuestionIndex > 0) {
			this.currentQuestionIndex--;
			this.showAnonymousSelection = false;
			// Focus on the question title after navigation for accessibility
			this.focusOnElement('#question-title');
		}
	}

	/**
	 * Helper method to set focus on an element after DOM updates
	 * @param {string} selector - CSS selector for the element to focus
	 */
	focusOnElement(selector) {
		// Use requestAnimationFrame to ensure DOM has been updated before focusing
		requestAnimationFrame(() => {
			const element = this.template.querySelector(selector);
			if (element && typeof element.focus === 'function') {
				element.focus();
			}
		});
	}

	handleBackToLastQuestion() {
		this.showAnonymousSelection = false;
	}

	handleResponseChange(event) {
		const { questionId, value, checked, questionType } = event.detail;

		if (!this.responses[questionId]) {
			this.responses[questionId] = { questionId, response: '', responses: [] };
		}

		if (questionType === QUESTION_TYPE.MULTI_SELECT_VERTICAL) {
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

		// Force LWC reactivity by reassigning the responses object
		this.responses = { ...this.responses };
	}

	handleAnonymousChange(event) {
		this.anonymousValue = event.detail.value;
	}

	/**
	 * Handle preview mode user context change
	 */
	handlePreviewContextChange(event) {
		this.previewUserContext = event.detail.value;
	}

	/**
	 * Handle preview mode mobile toggle
	 */
	handleMobileToggle() {
		this.previewMobileMode = !this.previewMobileMode;
	}

	/**
	 * Handle return to builder navigation
	 */
	handleReturnToBuilder() {
		if (this.effectiveRecordId) {
			this[NavigationMixin.Navigate]({
				type: 'standard__navItemPage',
				attributes: {
					apiName: 'Survey_Creator_Page'
				},
				state: {
					c__recordId: this.effectiveRecordId
				}
			});
		}
	}

	handleSubmit() {
		// If in preview mode, don't submit - just show a message
		if (this.isPreviewMode) {
			this.showToast('Preview Mode', 'This is a preview. Survey responses will not be saved.', 'info');
			// Show the thank you page without actually submitting
			this.isSubmitted = true;
			return;
		}

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
					this.showToast('Success', 'Thank you! Your survey has been submitted successfully.', 'success');
				} else {
					// Provide specific error message from server
					const errorMsg = result.message || 'Unable to submit survey';
					this.showToast('Submission Error', errorMsg + '. Please try again or contact support if the problem continues.', 'error');
				}
				this.isSubmitting = false;
			})
			.catch((err) => {
				// Enhanced error handling for submission failures
				const errorMessage = err.body?.message || err.message || 'Unknown error';

				let userMessage = '';
				if (errorMessage.toLowerCase().includes('duplicate') || errorMessage.toLowerCase().includes('already submitted')) {
					userMessage = 'This survey has already been submitted. Each survey link can only be used once.';
				} else if (errorMessage.toLowerCase().includes('expired')) {
					userMessage = 'This survey link has expired. Please request a new link from the survey administrator.';
				} else if (errorMessage.toLowerCase().includes('permission') || errorMessage.toLowerCase().includes('access')) {
					userMessage = "You don't have permission to submit this survey. Please contact your administrator.";
				} else if (errorMessage.toLowerCase().includes('network') || errorMessage.toLowerCase().includes('connection')) {
					userMessage = 'Network connection error. Your responses have not been saved. Please check your connection and try again.';
				} else if (errorMessage.toLowerCase().includes('timeout')) {
					userMessage = 'The request timed out. Your responses may not have been saved. Please try submitting again.';
				} else {
					userMessage = `Unable to submit survey: ${errorMessage}. Your responses have not been saved. Please try again.`;
				}

				this.showToast('Submission Failed', userMessage, 'error');
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

				if (question.questionType === QUESTION_TYPE.MULTI_SELECT_VERTICAL) {
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
