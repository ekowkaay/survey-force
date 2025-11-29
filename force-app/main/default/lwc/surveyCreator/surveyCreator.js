import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import checkSiteAvailability from '@salesforce/apex/SurveyCreationController.checkSiteAvailability';
import createSurveyWithDetails from '@salesforce/apex/SurveyCreationController.createSurveyWithDetails';
import createSurveyQuestions from '@salesforce/apex/SurveyCreationController.createSurveyQuestions';
import getRecentSurveys from '@salesforce/apex/SurveyCreationController.getRecentSurveys';
import getSurveyWithQuestions from '@salesforce/apex/SurveyCreationController.getSurveyWithQuestions';

export default class SurveyCreator extends NavigationMixin(LightningElement) {
	// Public API property for viewing existing surveys
	@api recordId;

	// Survey properties
	@track surveyId = null;
	@track surveyName = '';
	@track surveyHeader = '';
	@track thankYouText = '';
	@track thankYouLink = '';
	@track hideSurveyName = false;
	@track allResponsesAnonymous = false;

	// UI state
	@track hasExistingSite = true;
	@track isLoading = true;
	@track isCreating = false;
	@track activeTab = 'build';
	@track showSettings = true;
	@track isViewMode = false;

	// Data
	@track recentSurveys = [];
	@track showRecentSurveys = false;
	@track questions = [];
	@track surveyCreatedDate = null;

	// Question modal state
	@track showQuestionModal = false;
	@track currentQuestion = {
		id: null,
		question: '',
		questionType: 'Free Text',
		required: false,
		choicesText: ''
	};
	@track editingQuestionIndex = null;

	// Results placeholders
	@track totalResponses = 0;
	@track completionRate = '0%';
	@track averageTime = 'N/A';

	connectedCallback() {
		this.loadInitialData();
	}

	loadInitialData() {
		// If recordId is provided, load the existing survey
		if (this.recordId) {
			this.loadExistingSurvey();
		} else {
			this.loadCreateModeData();
		}
	}

	/**
	 * Load data for create mode (new survey)
	 */
	loadCreateModeData() {
		Promise.all([checkSiteAvailability(), getRecentSurveys()])
			.then(([siteInfo, surveys]) => {
				this.hasExistingSite = siteInfo.hasExistingSite;
				this.recentSurveys = surveys;
				this.showRecentSurveys = surveys && surveys.length > 0;
				this.isViewMode = false;
				this.isLoading = false;
			})
			.catch((error) => {
				this.showToast('Error', 'Error loading page: ' + (error.body?.message || error.message), 'error');
				this.isLoading = false;
			});
	}

	/**
	 * Load an existing survey for viewing/editing
	 */
	loadExistingSurvey() {
		Promise.all([checkSiteAvailability(), getSurveyWithQuestions({ surveyId: this.recordId })])
			.then(([siteInfo, surveyData]) => {
				this.hasExistingSite = siteInfo.hasExistingSite;

				// Populate survey data
				this.surveyId = surveyData.survey.Id;
				this.surveyName = surveyData.survey.Name;
				this.surveyHeader = surveyData.survey.Survey_Header__c || '';
				this.thankYouText = surveyData.survey.Thank_You_Text__c || '';
				this.thankYouLink = surveyData.survey.Thank_You_Link__c || '';
				this.hideSurveyName = surveyData.survey.Hide_Survey_Name__c || false;
				this.allResponsesAnonymous = surveyData.survey.All_Responses_Anonymous__c || false;
				this.totalResponses = surveyData.totalResponses || 0;
				this.surveyCreatedDate = surveyData.survey.CreatedDate;

				// Populate questions
				this.questions = surveyData.questions.map((q) => ({
					id: q.id,
					question: q.question,
					questionType: q.questionType,
					required: q.required,
					choices: q.choices || [],
					choicesText: q.choicesText || '',
					orderNumber: q.orderNumber
				}));

				// Set to view mode
				this.isViewMode = true;
				this.isLoading = false;

				// Show recent surveys after loading
				getRecentSurveys()
					.then((surveys) => {
						this.recentSurveys = surveys;
						this.showRecentSurveys = surveys && surveys.length > 0;
					})
					.catch(() => {
						// Ignore error for recent surveys
					});
			})
			.catch((error) => {
				this.showToast('Error', 'Error loading survey: ' + (error.body?.message || error.message), 'error');
				this.isLoading = false;
			});
	}

	/**
	 * Switch to edit mode from view mode
	 */
	handleEditSurvey() {
		this.isViewMode = false;
		this.showSettings = true;
	}

	/**
	 * Create a new survey (reset all fields)
	 */
	handleNewSurvey() {
		this.surveyId = null;
		this.surveyName = '';
		this.surveyHeader = '';
		this.thankYouText = '';
		this.thankYouLink = '';
		this.hideSurveyName = false;
		this.allResponsesAnonymous = false;
		this.questions = [];
		this.totalResponses = 0;
		this.surveyCreatedDate = null;
		this.isViewMode = false;
		this.showSettings = true;
		this.activeTab = 'build';
	}

	/**
	 * Load a survey from the recent surveys list
	 */
	handleLoadSurvey(event) {
		const surveyIdToLoad = event.target.dataset.surveyId;
		this.isLoading = true;

		getSurveyWithQuestions({ surveyId: surveyIdToLoad })
			.then((surveyData) => {
				// Populate survey data
				this.surveyId = surveyData.survey.Id;
				this.surveyName = surveyData.survey.Name;
				this.surveyHeader = surveyData.survey.Survey_Header__c || '';
				this.thankYouText = surveyData.survey.Thank_You_Text__c || '';
				this.thankYouLink = surveyData.survey.Thank_You_Link__c || '';
				this.hideSurveyName = surveyData.survey.Hide_Survey_Name__c || false;
				this.allResponsesAnonymous = surveyData.survey.All_Responses_Anonymous__c || false;
				this.totalResponses = surveyData.totalResponses || 0;
				this.surveyCreatedDate = surveyData.survey.CreatedDate;

				// Populate questions
				this.questions = surveyData.questions.map((q) => ({
					id: q.id,
					question: q.question,
					questionType: q.questionType,
					required: q.required,
					choices: q.choices || [],
					choicesText: q.choicesText || '',
					orderNumber: q.orderNumber
				}));

				// Switch to view mode
				this.isViewMode = true;
				this.activeTab = 'build';
				this.isLoading = false;

				this.showToast('Success', 'Survey loaded successfully', 'success');
			})
			.catch((error) => {
				this.showToast('Error', 'Error loading survey: ' + (error.body?.message || error.message), 'error');
				this.isLoading = false;
			});
	}

	// Computed properties
	get canCreate() {
		return this.surveyName && this.surveyName.trim().length > 0;
	}

	get siteWarningMessage() {
		return 'Please create a Force.com Site before creating surveys for external users.';
	}

	get showSiteWarning() {
		return !this.hasExistingSite;
	}

	get displaySurveyName() {
		return this.surveyName || 'New Survey';
	}

	get surveyStatusText() {
		if (this.isViewMode) {
			return 'Viewing Survey';
		}
		return this.surveyId ? 'Saved' : 'Draft - Not saved';
	}

	get createButtonLabel() {
		if (this.isViewMode) {
			return 'Edit Survey';
		}
		return this.surveyId ? 'Update Survey' : 'Create Survey';
	}

	get showCreateButton() {
		return !this.isViewMode;
	}

	get showEditButton() {
		return this.isViewMode;
	}

	get showNewSurveyButton() {
		return this.surveyId !== null;
	}

	get isFieldsDisabled() {
		return this.isCreating || this.isViewMode;
	}

	get questionCount() {
		return this.questions.length;
	}

	get hasQuestions() {
		return this.questions.length > 0;
	}

	get questionsWithIndex() {
		return this.questions.map((q, index) => ({
			...q,
			index: index,
			orderNumber: index + 1
		}));
	}

	get settingsToggleIcon() {
		return this.showSettings ? 'utility:chevronup' : 'utility:chevrondown';
	}

	get anonymousText() {
		return this.allResponsesAnonymous ? 'Yes' : 'No';
	}

	get hideNameText() {
		return this.hideSurveyName ? 'Yes' : 'No';
	}

	get surveyLink() {
		return this.surveyId ? window.location.origin + '/survey/' + this.surveyId : '';
	}

	get questionModalTitle() {
		return this.editingQuestionIndex !== null ? 'Edit Question' : 'Add Question';
	}

	get questionTypeOptions() {
		return [
			{ label: 'Free Text', value: 'Free Text' },
			{ label: 'Single Select - Vertical', value: 'Single Select--Vertical' },
			{ label: 'Single Select - Horizontal', value: 'Single Select--Horizontal' },
			{ label: 'Multi-Select - Vertical', value: 'Multi-Select--Vertical' }
		];
	}

	get showChoices() {
		return (
			this.currentQuestion.questionType === 'Single Select--Vertical' ||
			this.currentQuestion.questionType === 'Single Select--Horizontal' ||
			this.currentQuestion.questionType === 'Multi-Select--Vertical'
		);
	}

	get formattedCreatedDate() {
		if (!this.surveyCreatedDate) {
			return 'N/A';
		}
		return new Date(this.surveyCreatedDate).toLocaleDateString();
	}

	// Event handlers
	handleToggleSettings() {
		this.showSettings = !this.showSettings;
	}

	handleNameChange(event) {
		this.surveyName = event.target.value;
	}

	handleHeaderChange(event) {
		this.surveyHeader = event.target.value;
	}

	handleThankYouTextChange(event) {
		this.thankYouText = event.target.value;
	}

	handleThankYouLinkChange(event) {
		this.thankYouLink = event.target.value;
	}

	handleHideSurveyNameChange(event) {
		this.hideSurveyName = event.target.checked;
	}

	handleAllResponsesAnonymousChange(event) {
		this.allResponsesAnonymous = event.target.checked;
	}

	// Question handlers
	handleAddQuestion() {
		this.editingQuestionIndex = null;
		this.currentQuestion = {
			id: null,
			question: '',
			questionType: 'Free Text',
			required: false,
			choicesText: ''
		};
		this.showQuestionModal = true;
	}

	handleEditQuestion(event) {
		const index = parseInt(event.target.dataset.questionIndex, 10);
		const question = this.questions[index];

		this.editingQuestionIndex = index;
		this.currentQuestion = {
			id: question.id,
			question: question.question,
			questionType: question.questionType,
			required: question.required,
			choicesText: question.choicesText || ''
		};
		this.showQuestionModal = true;
	}

	handleDuplicateQuestion(event) {
		const index = parseInt(event.target.dataset.questionIndex, 10);
		const question = this.questions[index];

		const duplicatedQuestion = {
			id: 'temp_' + Date.now(),
			question: question.question + ' (Copy)',
			questionType: question.questionType,
			required: question.required,
			choices: question.choices ? [...question.choices] : [],
			choicesText: question.choicesText || '',
			orderNumber: this.questions.length + 1
		};

		this.questions = [...this.questions, duplicatedQuestion];
		this.showToast('Success', 'Question duplicated', 'success');
	}

	handleDeleteQuestion(event) {
		const index = parseInt(event.target.dataset.questionIndex, 10);
		this.questions = this.questions.filter((_, i) => i !== index);
		this.showToast('Success', 'Question deleted', 'success');
	}

	handleQuestionChange(event) {
		this.currentQuestion = { ...this.currentQuestion, question: event.target.value };
	}

	handleQuestionTypeChange(event) {
		this.currentQuestion = { ...this.currentQuestion, questionType: event.detail.value };
	}

	handleRequiredChange(event) {
		this.currentQuestion = { ...this.currentQuestion, required: event.target.checked };
	}

	handleChoicesChange(event) {
		this.currentQuestion = { ...this.currentQuestion, choicesText: event.target.value };
	}

	handleCancelQuestion() {
		this.showQuestionModal = false;
	}

	handleSaveQuestion() {
		if (!this.currentQuestion.question.trim()) {
			this.showToast('Error', 'Question text is required', 'error');
			return;
		}

		let choices = [];
		if (this.currentQuestion.choicesText) {
			choices = this.currentQuestion.choicesText
				.split('\n')
				.map((choice) => choice.trim())
				.filter((choice) => choice);
		}

		const questionData = {
			id: this.currentQuestion.id || 'temp_' + Date.now(),
			question: this.currentQuestion.question,
			questionType: this.currentQuestion.questionType,
			required: this.currentQuestion.required,
			choices: choices,
			choicesText: this.currentQuestion.choicesText
		};

		if (this.editingQuestionIndex !== null) {
			const updatedQuestions = [...this.questions];
			updatedQuestions[this.editingQuestionIndex] = questionData;
			this.questions = updatedQuestions;
		} else {
			questionData.orderNumber = this.questions.length + 1;
			this.questions = [...this.questions, questionData];
		}

		this.showQuestionModal = false;
		this.showToast('Success', 'Question saved', 'success');
	}

	// Survey actions
	handlePreview() {
		if (this.surveyId) {
			window.open('/apex/TakeSurvey?id=' + this.surveyId + '&preview=true', '_blank');
		} else {
			this.showToast('Info', 'Please save the survey first to preview', 'info');
		}
	}

	handleCreateSurvey() {
		if (!this.surveyName || this.surveyName.trim().length === 0) {
			this.showToast('Error', 'Please enter a survey name', 'error');
			return;
		}

		this.isCreating = true;

		const surveyData = {
			surveyName: this.surveyName,
			surveyHeader: this.surveyHeader,
			thankYouText: this.thankYouText,
			thankYouLink: this.thankYouLink,
			hideSurveyName: this.hideSurveyName,
			allResponsesAnonymous: this.allResponsesAnonymous
		};

		createSurveyWithDetails(surveyData)
			.then((result) => {
				if (result.success) {
					this.surveyId = result.surveyId;

					if (this.questions.length > 0) {
						const questionData = this.questions.map((q, index) => ({
							question: q.question,
							questionType: q.questionType,
							required: q.required,
							choices: q.choices,
							orderNumber: index + 1
						}));

						return createSurveyQuestions({
							surveyId: result.surveyId,
							questions: questionData
						})
							.then(() => {
								this.showToast('Success', 'Survey created successfully', 'success');
								this.isCreating = false;
								// Switch to view mode after successful creation
								this.isViewMode = true;
								this.surveyCreatedDate = new Date().toISOString();
							})
							.catch((error) => {
								this.showToast('Error', 'Error creating questions: ' + (error.body?.message || error.message), 'error');
								this.isCreating = false;
							});
					} else {
						this.showToast('Success', 'Survey created successfully', 'success');
						this.isCreating = false;
						// Switch to view mode after successful creation
						this.isViewMode = true;
						this.surveyCreatedDate = new Date().toISOString();
					}
				} else {
					this.showToast('Error', result.message, 'error');
					this.isCreating = false;
				}
			})
			.catch((error) => {
				this.showToast('Error', 'Error creating survey: ' + (error.body?.message || error.message), 'error');
				this.isCreating = false;
			});
	}

	// Share tab handlers
	handleCopyLink() {
		if (this.surveyLink) {
			navigator.clipboard
				.writeText(this.surveyLink)
				.then(() => {
					this.showToast('Success', 'Link copied to clipboard', 'success');
				})
				.catch(() => {
					this.showToast('Error', 'Failed to copy link', 'error');
				});
		}
	}

	handleComposeEmail() {
		if (this.surveyLink) {
			const subject = encodeURIComponent('Survey: ' + this.surveyName);
			const body = encodeURIComponent('Please take our survey: ' + this.surveyLink);
			window.open('mailto:?subject=' + subject + '&body=' + body, '_blank');
		}
	}

	// Results tab handlers
	handleViewResults() {
		if (this.surveyId) {
			this[NavigationMixin.Navigate]({
				type: 'standard__recordPage',
				attributes: {
					recordId: this.surveyId,
					objectApiName: 'Survey__c',
					actionName: 'view'
				}
			});
		}
	}

	// Navigation handlers
	handleViewSurvey(event) {
		const surveyId = event.target.dataset.surveyId;
		this.navigateToSurvey(surveyId);
	}

	navigateToSurvey(surveyId) {
		this[NavigationMixin.Navigate]({
			type: 'standard__recordPage',
			attributes: {
				recordId: surveyId,
				objectApiName: 'Survey__c',
				actionName: 'view'
			}
		});
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
