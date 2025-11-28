import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SurveyBuilderLwc extends LightningElement {
    // Survey properties
    @track surveyId = null;
    @track surveyName = 'New Survey';

    // UI state
    @track isLoading = true;
    @track error = null;

    // Data
    @track questions = [];

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

    connectedCallback() {
        // Initialize with sample data for demonstration purposes
        this.initializeSampleData();
    }

    initializeSampleData() {
        // Simulate loading survey data
        setTimeout(() => {
            this.questions = [
                {
                    id: '1',
                    question: 'How satisfied are you with our service?',
                    questionType: 'Single Select--Vertical',
                    required: true,
                    choicesText: 'Very Satisfied\nSatisfied\nNeutral\nDissatisfied\nVery Dissatisfied'
                },
                {
                    id: '2',
                    question: 'What features would you like to see improved?',
                    questionType: 'Free Text',
                    required: false,
                    choicesText: ''
                }
            ];
            this.isLoading = false;
        }, 1000);
    }

    // Computed properties
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
            choicesText: question.choicesText || ''
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

        const questionData = {
            id: this.currentQuestion.id || 'temp_' + Date.now(),
            question: this.currentQuestion.question,
            questionType: this.currentQuestion.questionType,
            required: this.currentQuestion.required,
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
    handleSaveSurvey() {
        this.showToast('Success', 'Survey saved successfully', 'success');
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
