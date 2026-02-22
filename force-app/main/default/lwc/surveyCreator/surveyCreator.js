import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import checkSiteAvailability from '@salesforce/apex/SurveyCreationController.checkSiteAvailability';
import createSurveyWithDetails from '@salesforce/apex/SurveyCreationController.createSurveyWithDetails';
import updateSurveyWithDetails from '@salesforce/apex/SurveyCreationController.updateSurveyWithDetails';
import createSurveyQuestions from '@salesforce/apex/SurveyCreationController.createSurveyQuestions';
import updateSurveyQuestions from '@salesforce/apex/SurveyCreationController.updateSurveyQuestions';
import getRecentSurveys from '@salesforce/apex/SurveyCreationController.getRecentSurveys';
import getSurveyDetails from '@salesforce/apex/SurveyCreationController.getSurveyDetails';

export default class SurveyCreator extends NavigationMixin(LightningElement) {
	// Survey properties
	@track surveyId = null;
	@track surveyName = '';
	@track surveyHeader = '';
	@track surveySubheader = '';
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

	// View mode data
	@track viewSurveyDetails = null;
	@track createdDate = '';
	@track lastModifiedDate = '';
	@track createdByName = '';

	// Question modal state
	@track showQuestionModal = false;
	@track currentQuestion = {
		id: null,
		question: '',
		questionType: 'Free Text',
		required: false,
		choicesText: '',
		scaleStartLabel: '',
		scaleEndLabel: ''
	};
	@track editingQuestionIndex = null;

	// Delete Question Confirmation Modal
	@track showDeleteQuestionModal = false;
	@track deleteQuestionIndex = null;
	@track deleteQuestionText = '';

	// Results placeholders
	@track totalResponses = 0;
	@track completionRate = '0%';
	@track averageTime = 'N/A';

	// Page reference for URL parameters
	currentPageReference;
	_loadedSurveyId = null;
	_loadedEditMode = false;

	@wire(CurrentPageReference)
	getStateParameters(currentPageReference) {
		if (currentPageReference) {
			this.currentPageReference = currentPageReference;
			// Check if surveyId is passed in URL state
			if (currentPageReference.state?.c__surveyId) {
				const editMode = currentPageReference.state?.c__editMode === 'true';
				const surveyId = currentPageReference.state.c__surveyId;

				// Only load if it's a different survey or different mode
				if (surveyId !== this._loadedSurveyId || editMode !== this._loadedEditMode) {
					this._loadedSurveyId = surveyId;
					this._loadedEditMode = editMode;
					this.loadSurveyDetails(surveyId, editMode);
				}
			}
		}
	}

	connectedCallback() {
		this.loadInitialData();
	}

	loadInitialData() {
		Promise.all([checkSiteAvailability(), getRecentSurveys()])
			.then(([siteInfo, surveys]) => {
				this.hasExistingSite = siteInfo.hasExistingSite;
				this.recentSurveys = surveys;
				this.showRecentSurveys = surveys && surveys.length > 0;
				this.isLoading = false;
			})
			.catch((error) => {
				const detail = error.body?.message || error.message || 'Unknown error';
				this.showToast('Error', `Unable to load the survey builder. Please check your network connection and refresh the page. Details: ${detail}`, 'error');
				this.isLoading = false;
			});
	}

	/**
	 * Load survey details for view or edit mode
	 * @param {String} surveyIdToLoad - The survey ID to load
	 * @param {Boolean} editMode - If true, loads in build/edit mode; if false or undefined, loads in view mode
	 */
	loadSurveyDetails(surveyIdToLoad, editMode = false) {
		this.isLoading = true;
		getSurveyDetails({ surveyId: surveyIdToLoad })
			.then((result) => {
				this.viewSurveyDetails = result;
				this.surveyId = result.survey.Id;
				this.surveyName = result.survey.Name;
				this.surveyHeader = result.survey.Survey_Header__c || '';
				this.surveySubheader = result.survey.Survey_Subheader__c || '';
				this.thankYouText = result.survey.Thank_You_Text__c || '';
				this.thankYouLink = result.survey.Thank_You_Link__c || '';
				this.hideSurveyName = result.survey.Hide_Survey_Name__c || false;
				this.allResponsesAnonymous = result.survey.All_Responses_Anonymous__c || false;
				this.totalResponses = result.totalResponses || 0;
				this.createdDate = result.createdDate;
				this.lastModifiedDate = result.lastModifiedDate;
				this.createdByName = result.createdByName;

				// Map questions for view mode
				this.questions = (result.questions || []).map((q) => ({
					id: q.id,
					question: q.question,
					questionType: q.questionType,
					required: q.required,
					choices: q.choices || [],
					choicesText: (q.choices || []).join('\n'),
					orderNumber: q.orderNumber,
					hideOnSurvey: q.hideOnSurvey,
					scaleStartLabel: q.scaleStartLabel || '',
					scaleEndLabel: q.scaleEndLabel || ''
				}));

				// Set mode based on editMode parameter
				if (editMode) {
					this.isViewMode = false;
					this.activeTab = 'build';
				} else {
					this.isViewMode = true;
					this.activeTab = 'view';
				}
				this.isLoading = false;
			})
			.catch((error) => {
				const detail = error.body?.message || error.message || 'Unknown error';
				this.showToast(
					'Error',
					`Unable to load survey details. The survey may have been deleted or you may lack access. Please try again or contact your administrator. Details: ${detail}`,
					'error'
				);
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
			return 'Saved';
		}
		return this.surveyId ? 'Saved' : 'Draft - Not saved';
	}

	get createButtonLabel() {
		return this.surveyId ? 'Update Survey' : 'Create Survey';
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
			orderNumber: q.orderNumber || index + 1
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

	get showScaleLabels() {
		return this.currentQuestion.questionType === 'Single Select--Horizontal';
	}

	get scaleStartLabelOptions() {
		return [
			{ label: 'Very Difficult', value: 'Very Difficult' },
			{ label: 'Strongly Disagree', value: 'Strongly Disagree' },
			{ label: 'Very Dissatisfied', value: 'Very Dissatisfied' },
			{ label: 'Very Unlikely', value: 'Very Unlikely' },
			{ label: 'Very Poor', value: 'Very Poor' },
			{ label: 'Not at All', value: 'Not at All' },
			{ label: 'Never', value: 'Never' }
		];
	}

	get scaleEndLabelOptions() {
		return [
			{ label: 'Very Easy', value: 'Very Easy' },
			{ label: 'Strongly Agree', value: 'Strongly Agree' },
			{ label: 'Very Satisfied', value: 'Very Satisfied' },
			{ label: 'Very Likely', value: 'Very Likely' },
			{ label: 'Excellent', value: 'Excellent' },
			{ label: 'Extremely', value: 'Extremely' },
			{ label: 'Always', value: 'Always' }
		];
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

	handleSubheaderChange(event) {
		this.surveySubheader = event.target.value;
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
			choicesText: '',
			scaleStartLabel: '',
			scaleEndLabel: ''
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
			choicesText: question.choicesText || '',
			scaleStartLabel: question.scaleStartLabel || '',
			scaleEndLabel: question.scaleEndLabel || ''
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
			scaleStartLabel: question.scaleStartLabel || '',
			scaleEndLabel: question.scaleEndLabel || '',
			orderNumber: this.questions.length + 1
		};

		this.questions = [...this.questions, duplicatedQuestion];
		this.showToast('Success', 'Question duplicated', 'success');
	}

	handleDeleteQuestion(event) {
		const index = parseInt(event.target.dataset.questionIndex, 10);
		const question = this.questions[index];
		this.deleteQuestionIndex = index;
		this.deleteQuestionText = question.question;
		this.showDeleteQuestionModal = true;
	}

	handleCloseDeleteQuestionModal() {
		this.showDeleteQuestionModal = false;
		this.deleteQuestionIndex = null;
		this.deleteQuestionText = '';
	}

	handleConfirmDeleteQuestion() {
		if (this.deleteQuestionIndex !== null) {
			this.questions = this.questions.filter((_, i) => i !== this.deleteQuestionIndex);
			this.showToast('Success', 'Question deleted', 'success');
			this.showDeleteQuestionModal = false;
			this.deleteQuestionIndex = null;
			this.deleteQuestionText = '';
		}
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

	handleScaleStartLabelChange(event) {
		this.currentQuestion = { ...this.currentQuestion, scaleStartLabel: event.detail.value };
	}

	handleScaleEndLabelChange(event) {
		this.currentQuestion = { ...this.currentQuestion, scaleEndLabel: event.detail.value };
	}

	handleCancelQuestion() {
		this.showQuestionModal = false;
	}

	handleSaveQuestion() {
		if (!this.currentQuestion.question.trim()) {
			this.showToast('Error', 'Question text is required. Please enter the question you want to ask respondents.', 'error');
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
			choicesText: this.currentQuestion.choicesText,
			scaleStartLabel: this.currentQuestion.scaleStartLabel || '',
			scaleEndLabel: this.currentQuestion.scaleEndLabel || ''
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
			this[NavigationMixin.Navigate]({
				type: 'standard__navItemPage',
				attributes: {
					apiName: 'Survey_Taker_Page'
				},
				state: {
					c__recordId: this.surveyId,
					c__preview: 'true'
				}
			});
		} else {
			this.showToast('Info', 'Please save the survey first to preview', 'info');
		}
	}

	handleCreateSurvey() {
		if (!this.surveyName || this.surveyName.trim().length === 0) {
			this.showToast('Error', 'Please enter a survey name. A descriptive name helps you identify your survey later.', 'error');
			return;
		}

		this.isCreating = true;

		const surveyData = {
			surveyName: this.surveyName,
			surveyHeader: this.surveyHeader,
			surveySubheader: this.surveySubheader,
			thankYouText: this.thankYouText,
			thankYouLink: this.thankYouLink,
			hideSurveyName: this.hideSurveyName,
			allResponsesAnonymous: this.allResponsesAnonymous
		};

		// Determine if we're creating or updating
		const isUpdate = this.surveyId !== null;
		const surveyMethod = isUpdate
			? updateSurveyWithDetails({
					surveyId: this.surveyId,
					surveyName: surveyData.surveyName,
					surveyHeader: surveyData.surveyHeader,
					surveySubheader: surveyData.surveySubheader,
					thankYouText: surveyData.thankYouText,
					thankYouLink: surveyData.thankYouLink,
					hideSurveyName: surveyData.hideSurveyName,
					allResponsesAnonymous: surveyData.allResponsesAnonymous
				})
			: createSurveyWithDetails(surveyData);

		surveyMethod
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

						// Use update for existing surveys, create for new ones
						const questionMethod = isUpdate
							? updateSurveyQuestions({ surveyId: result.surveyId, questions: questionData })
							: createSurveyQuestions({ surveyId: result.surveyId, questions: questionData });

						return questionMethod
							.then(() => {
								const successMessage = isUpdate ? 'Survey updated successfully' : 'Survey created successfully';
								this.showToast('Success', successMessage, 'success');
								this.isCreating = false;
								this.loadSurveyDetails(result.surveyId);
							})
							.catch((error) => {
								const errorMessage = isUpdate ? 'Error updating questions' : 'Error saving questions';
								this.showToast('Error', `${errorMessage}. Please check your question data and try again. Details: ${error.body?.message || error.message}`, 'error');
								this.isCreating = false;
							});
					} else {
						const successMessage = isUpdate ? 'Survey updated successfully' : 'Survey created successfully';
						this.showToast('Success', successMessage, 'success');
						this.isCreating = false;
						this.loadSurveyDetails(result.surveyId);
					}
				} else {
					this.showToast('Error', result.message, 'error');
					this.isCreating = false;
				}
			})
			.catch((error) => {
				const errorMessage = isUpdate ? 'Error updating survey' : 'Error creating survey';
				this.showToast(
					'Error',
					`${errorMessage}. Please verify your inputs and try again. If the issue persists, contact your administrator. Details: ${error.body?.message || error.message}`,
					'error'
				);
				this.isCreating = false;
			});
	}

	/**
	 * Switch from view mode back to edit/create mode
	 */
	handleEditSurvey() {
		this.isViewMode = false;
		this.activeTab = 'build';
	}

	/**
	 * Create a new survey - resets the form
	 */
	handleCreateNew() {
		this.surveyId = null;
		this.surveyName = '';
		this.surveyHeader = '';
		this.surveySubheader = '';
		this.thankYouText = '';
		this.thankYouLink = '';
		this.hideSurveyName = false;
		this.allResponsesAnonymous = false;
		this.questions = [];
		this.isViewMode = false;
		this.activeTab = 'build';
		this.viewSurveyDetails = null;
		this.totalResponses = 0;
		this.createdDate = '';
		this.lastModifiedDate = '';
		this.createdByName = '';
		this._loadedSurveyId = null;
		this._loadedEditMode = false;
	}

	/**
	 * Navigate to standard record page
	 */
	handleGoToRecord() {
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

	// Navigation handlers - load survey in view mode within component
	handleViewSurvey(event) {
		const surveyIdToView = event.target.dataset.surveyId;
		this.loadSurveyDetails(surveyIdToView);
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
