import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getSurveyManagementData from '@salesforce/apex/SurveyManagementController.getSurveyManagementData';
import updateSurveySettings from '@salesforce/apex/SurveyManagementController.updateSurveySettings';
import getSurveyQuestions from '@salesforce/apex/SurveyManagementController.getSurveyQuestions';
import deleteSurveyQuestion from '@salesforce/apex/SurveyManagementController.deleteSurveyQuestion';
import createQuestion from '@salesforce/apex/SurveyBuilderController.createQuestion';
import updateQuestion from '@salesforce/apex/SurveyBuilderController.updateQuestion';
import reorderQuestions from '@salesforce/apex/SurveyBuilderController.reorderQuestions';

export default class SurveyBuilder extends NavigationMixin(LightningElement) {
	@api recordId;

	@track isLoading = true;
	@track isSaving = false;
	@track survey = null;
	@track questions = [];
	@track error = null;

	// Modal state
	@track showQuestionModal = false;
	@track editingQuestion = null;
	@track isNewQuestion = false;

	// Question form fields
	@track questionText = '';
	@track questionType = 'Free Text';
	@track questionRequired = false;
	@track questionChoices = '';
	@track questionOrder = 1;

	// Survey settings modal
	@track showSettingsModal = false;
	@track surveyName = '';
	@track surveyHeader = '';
	@track hideSurveyName = false;
	@track thankYouText = '';
	@track thankYouLink = '';
	@track allResponsesAnonymous = false;
	@track shareWithGuestUser = false;

	get questionTypeOptions() {
		return [
			{ label: 'Free Text', value: 'Free Text' },
			{ label: 'Single Select (Vertical)', value: 'Single Select--Vertical' },
			{ label: 'Single Select (Horizontal)', value: 'Single Select--Horizontal' },
			{ label: 'Multi-Select (Vertical)', value: 'Multi-Select--Vertical' }
		];
	}

	get showChoicesField() {
		return this.questionType !== 'Free Text';
	}

	get hasQuestions() {
		return this.questions && this.questions.length > 0;
	}

	get questionModalTitle() {
		return this.isNewQuestion ? 'Add New Question' : 'Edit Question';
	}

	get saveButtonLabel() {
		return this.isNewQuestion ? 'Add Question' : 'Save Changes';
	}

	connectedCallback() {
		this.loadSurveyData();
	}

	loadSurveyData() {
		this.isLoading = true;
		this.error = null;

		Promise.all([getSurveyManagementData({ surveyId: this.recordId }), getSurveyQuestions({ surveyId: this.recordId })])
			.then(([managementData, questionData]) => {
				this.survey = managementData.survey;
				this.questions = questionData.map((q, index) => ({
					...q,
					displayOrder: index + 1,
					typeLabel: this.getTypeLabel(q.Type__c),
					choicesPreview: this.getChoicesPreview(q.Choices__c)
				}));

				// Initialize survey settings
				this.initializeSurveySettings();
				this.isLoading = false;
			})
			.catch((error) => {
				this.error = error.body?.message || 'Error loading survey data';
				this.isLoading = false;
			});
	}

	initializeSurveySettings() {
		if (this.survey) {
			this.surveyName = this.survey.Name || '';
			this.surveyHeader = this.survey.Survey_Header__c || '';
			this.hideSurveyName = this.survey.Hide_Survey_Name__c || false;
			this.thankYouText = this.survey.Thank_You_Text__c || '';
			this.thankYouLink = this.survey.Thank_You_Link__c || '';
			this.allResponsesAnonymous = this.survey.All_Responses_Anonymous__c || false;
			this.shareWithGuestUser = this.survey.Share_with_Guest_User__c || false;
		}
	}

	getTypeLabel(type) {
		const typeMap = {
			'Free Text': 'Free Text',
			'Single Select--Vertical': 'Single Select',
			'Single Select--Horizontal': 'Single Select',
			'Multi-Select--Vertical': 'Multi-Select'
		};
		return typeMap[type] || type;
	}

	getChoicesPreview(choices) {
		if (!choices) return '';
		const choiceList = choices.split('\n').filter((c) => c.trim());
		if (choiceList.length <= 3) {
			return choiceList.join(', ');
		}
		return choiceList.slice(0, 3).join(', ') + '...';
	}

	// Question Modal handlers
	handleAddQuestion() {
		this.isNewQuestion = true;
		this.editingQuestion = null;
		this.questionText = '';
		this.questionType = 'Free Text';
		this.questionRequired = false;
		this.questionChoices = '';
		this.questionOrder = this.questions.length + 1;
		this.showQuestionModal = true;
	}

	handleEditQuestion(event) {
		const questionId = event.target.dataset.questionId;
		const question = this.questions.find((q) => q.Id === questionId);
		if (question) {
			this.isNewQuestion = false;
			this.editingQuestion = question;
			this.questionText = question.Question__c || '';
			this.questionType = question.Type__c || 'Free Text';
			this.questionRequired = question.Required__c || false;
			this.questionChoices = question.Choices__c || '';
			this.questionOrder = question.OrderNumber__c || 1;
			this.showQuestionModal = true;
		}
	}

	handleDeleteQuestion(event) {
		const questionId = event.target.dataset.questionId;
		if (confirm('Are you sure you want to delete this question? This action cannot be undone.')) {
			this.isSaving = true;
			deleteSurveyQuestion({ questionId: questionId })
				.then(() => {
					this.showToast('Success', 'Question deleted successfully', 'success');
					this.loadSurveyData();
				})
				.catch((error) => {
					this.showToast('Error', error.body?.message || 'Error deleting question', 'error');
					this.isSaving = false;
				});
		}
	}

	handleCloseQuestionModal() {
		this.showQuestionModal = false;
		this.editingQuestion = null;
	}

	handleQuestionTextChange(event) {
		this.questionText = event.target.value;
	}

	handleQuestionTypeChange(event) {
		this.questionType = event.detail.value;
	}

	handleQuestionRequiredChange(event) {
		this.questionRequired = event.target.checked;
	}

	handleQuestionChoicesChange(event) {
		this.questionChoices = event.target.value;
	}

	handleQuestionOrderChange(event) {
		this.questionOrder = parseInt(event.target.value, 10);
	}

	handleSaveQuestion() {
		if (!this.questionText || this.questionText.trim() === '') {
			this.showToast('Error', 'Question text is required', 'error');
			return;
		}

		if (this.showChoicesField && (!this.questionChoices || this.questionChoices.trim() === '')) {
			this.showToast('Error', 'Please provide choices for this question type', 'error');
			return;
		}

		this.isSaving = true;

		const questionData = {
			Question__c: this.questionText,
			Type__c: this.questionType,
			Required__c: this.questionRequired,
			Choices__c: this.showChoicesField ? this.questionChoices : '',
			OrderNumber__c: this.questionOrder,
			Survey__c: this.recordId
		};

		if (this.isNewQuestion) {
			createQuestion({ questionData: questionData })
				.then(() => {
					this.showToast('Success', 'Question added successfully', 'success');
					this.showQuestionModal = false;
					this.loadSurveyData();
				})
				.catch((error) => {
					this.showToast('Error', error.body?.message || 'Error creating question', 'error');
					this.isSaving = false;
				});
		} else {
			questionData.Id = this.editingQuestion.Id;
			updateQuestion({ questionData: questionData })
				.then(() => {
					this.showToast('Success', 'Question updated successfully', 'success');
					this.showQuestionModal = false;
					this.loadSurveyData();
				})
				.catch((error) => {
					this.showToast('Error', error.body?.message || 'Error updating question', 'error');
					this.isSaving = false;
				});
		}
	}

	// Survey Settings handlers
	handleOpenSettings() {
		this.initializeSurveySettings();
		this.showSettingsModal = true;
	}

	handleCloseSettingsModal() {
		this.showSettingsModal = false;
	}

	handleSurveyNameChange(event) {
		this.surveyName = event.target.value;
	}

	handleSurveyHeaderChange(event) {
		this.surveyHeader = event.target.value;
	}

	handleHideSurveyNameChange(event) {
		this.hideSurveyName = event.target.checked;
	}

	handleThankYouTextChange(event) {
		this.thankYouText = event.target.value;
	}

	handleThankYouLinkChange(event) {
		this.thankYouLink = event.target.value;
	}

	handleAllResponsesAnonymousChange(event) {
		this.allResponsesAnonymous = event.target.checked;
	}

	handleShareWithGuestUserChange(event) {
		this.shareWithGuestUser = event.target.checked;
	}

	handleSaveSettings() {
		if (!this.surveyName || this.surveyName.trim() === '') {
			this.showToast('Error', 'Survey name is required', 'error');
			return;
		}

		this.isSaving = true;

		const surveyData = {
			Name: this.surveyName,
			Survey_Header__c: this.surveyHeader,
			Hide_Survey_Name__c: this.hideSurveyName,
			Thank_You_Text__c: this.thankYouText,
			Thank_You_Link__c: this.thankYouLink,
			All_Responses_Anonymous__c: this.allResponsesAnonymous,
			Share_with_Guest_User__c: this.shareWithGuestUser
		};

		updateSurveySettings({ surveyId: this.recordId, surveyData: surveyData })
			.then(() => {
				this.showToast('Success', 'Survey settings updated successfully', 'success');
				this.showSettingsModal = false;
				this.loadSurveyData();
			})
			.catch((error) => {
				this.showToast('Error', error.body?.message || 'Error updating settings', 'error');
				this.isSaving = false;
			});
	}

	// Move question handlers
	handleMoveUp(event) {
		const questionId = event.target.dataset.questionId;
		const index = this.questions.findIndex((q) => q.Id === questionId);
		if (index > 0) {
			this.swapQuestions(index, index - 1);
		}
	}

	handleMoveDown(event) {
		const questionId = event.target.dataset.questionId;
		const index = this.questions.findIndex((q) => q.Id === questionId);
		if (index < this.questions.length - 1) {
			this.swapQuestions(index, index + 1);
		}
	}

	swapQuestions(fromIndex, toIndex) {
		this.isSaving = true;
		const questionIds = this.questions.map((q) => q.Id);
		const temp = questionIds[fromIndex];
		questionIds[fromIndex] = questionIds[toIndex];
		questionIds[toIndex] = temp;

		reorderQuestions({ questionIds: questionIds })
			.then(() => {
				this.showToast('Success', 'Question order updated', 'success');
				this.loadSurveyData();
			})
			.catch((error) => {
				this.showToast('Error', error.body?.message || 'Error reordering questions', 'error');
				this.isSaving = false;
			});
	}

	// Navigation
	handlePreviewSurvey() {
		this[NavigationMixin.Navigate]({
			type: 'standard__navItemPage',
			attributes: {
				apiName: 'Survey_Taker_Page'
			},
			state: {
				c__recordId: this.recordId
			}
		});
	}

	handleViewResponses() {
		this[NavigationMixin.Navigate]({
			type: 'standard__recordRelationshipPage',
			attributes: {
				recordId: this.recordId,
				objectApiName: 'Survey__c',
				relationshipApiName: 'SurveyTakers__r',
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
