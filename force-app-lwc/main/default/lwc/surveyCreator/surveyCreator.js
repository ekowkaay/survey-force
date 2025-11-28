import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import checkSiteAvailability from '@salesforce/apex/SurveyCreationController.checkSiteAvailability';
import createSurveyWithDetails from '@salesforce/apex/SurveyCreationController.createSurveyWithDetails';
import createSurveyQuestions from '@salesforce/apex/SurveyCreationController.createSurveyQuestions';
import getRecentSurveys from '@salesforce/apex/SurveyCreationController.getRecentSurveys';

export default class SurveyCreator extends NavigationMixin(LightningElement) {
	@track surveyName = '';
	@track surveyHeader = '';
	@track thankYouText = '';
	@track thankYouLink = '';
	@track hideSurveyName = false;
	@track allResponsesAnonymous = false;
	@track hasExistingSite = true;
	@track isLoading = true;
	@track isCreating = false;
	@track recentSurveys = [];
	@track showRecentSurveys = false;
	@track questions = [];
	@track showQuestionModal = false;
	@track currentQuestion = {
		id: null,
		question: '',
		questionType: 'Free Text',
		required: false,
		choicesText: ''
	};

	@track editingQuestionIndex = null;

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
				this.showToast('Error', 'Error loading page: ' + (error.body?.message || error.message), 'error');
				this.isLoading = false;
			});
	}

	get canCreate() {
		// Allow creation based solely on a valid name; site is recommended but not required
		return this.surveyName && this.surveyName.trim().length > 0;
	}

	get siteWarningMessage() {
		return 'Please create a Force.com Site before creating surveys for external users.';
	}

	get questionTypeOptions() {
		return [
			{ label: 'Free Text', value: 'Free Text' },
			{ label: 'Single Select--Vertical', value: 'Single Select--Vertical' },
			{ label: 'Single Select--Horizontal', value: 'Single Select--Horizontal' },
			{ label: 'Multi-Select--Vertical', value: 'Multi-Select--Vertical' }
		];
	}

	get showChoices() {
		return this.currentQuestion.questionType === 'Single Select--Vertical' ||
			this.currentQuestion.questionType === 'Single Select--Horizontal' ||
			this.currentQuestion.questionType === 'Multi-Select--Vertical';
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
		const index = event.target.dataset.questionIndex;
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

	handleDeleteQuestion(event) {
		const index = event.target.dataset.questionIndex;
		this.questions.splice(index, 1);
	}

	handleQuestionChange(event) {
		this.currentQuestion.question = event.target.value;
	}

	handleQuestionTypeChange(event) {
		this.currentQuestion.questionType = event.detail.value;
	}

	handleRequiredChange(event) {
		this.currentQuestion.required = event.target.checked;
	}

	handleChoicesChange(event) {
		this.currentQuestion.choicesText = event.target.value;
	}

	handleCancelQuestion() {
		this.showQuestionModal = false;
	}

	handleSaveQuestion() {
		// Validate question
		if (!this.currentQuestion.question.trim()) {
			this.showToast('Error', 'Question text is required', 'error');
			return;
		}

		// Process choices if they exist
		let choices = [];
		if (this.currentQuestion.choicesText) {
			choices = this.currentQuestion.choicesText.split('\n')
				.map(choice => choice.trim())
				.filter(choice => choice);
		}

		const questionData = {
			id: this.currentQuestion.id,
			question: this.currentQuestion.question,
			questionType: this.currentQuestion.questionType,
			required: this.currentQuestion.required,
			choices: choices,
			choicesText: this.currentQuestion.choicesText
		};

		// If editing existing question
		if (this.editingQuestionIndex !== null) {
			this.questions[this.editingQuestionIndex] = questionData;
		} else {
			// Add new question
			questionData.orderNumber = this.questions.length + 1;
			questionData.id = 'temp_' + Date.now(); // Temporary ID for UI
			this.questions.push(questionData);
		}

		this.showQuestionModal = false;
	}

	handleCreateSurvey() {
		// Validate survey name
		if (!this.surveyName || this.surveyName.trim().length === 0) {
			this.showToast('Error', 'Please enter a survey name', 'error');
			return;
		}

		this.isCreating = true;

		// Prepare survey data
		const surveyData = {
			surveyName: this.surveyName,
			surveyHeader: this.surveyHeader,
			thankYouText: this.thankYouText,
			thankYouLink: this.thankYouLink,
			hideSurveyName: this.hideSurveyName,
			allResponsesAnonymous: this.allResponsesAnonymous
		};

		// Create the survey first
		createSurveyWithDetails(surveyData)
			.then((result) => {
				if (result.success) {
					// Now create questions if any exist
					if (this.questions.length > 0) {
						const questionData = this.questions.map((q, index) => ({
							question: q.question,
							questionType: q.questionType,
							required: q.required,
							choices: q.choices,
							orderNumber: index + 1
						}));

						createSurveyQuestions({
							surveyId: result.surveyId,
							questions: questionData
						})
							.then(() => {
								this.showToast('Success', 'Survey template created successfully', 'success');
								this.navigateToSurvey(result.surveyId);
							})
							.catch((error) => {
								this.showToast('Error', 'Error creating questions: ' + (error.body?.message || error.message), 'error');
								this.isCreating = false;
							});
					} else {
						// No questions, just navigate to survey
						this.showToast('Success', 'Survey template created successfully', 'success');
						this.navigateToSurvey(result.surveyId);
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
