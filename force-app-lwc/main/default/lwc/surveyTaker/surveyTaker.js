import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSurveyData from '@salesforce/apex/SurveyTakerController.getSurveyData';
import submitSurveyResponses from '@salesforce/apex/SurveyTakerController.submitSurveyResponses';

export default class SurveyTaker extends LightningElement {
@api recordId;
@api caseId;
@api contactId;

@track survey;
@track surveyName;
@track surveyHeader;
@track showSurveyName = true;
@track questions = [];
@track visibleQuestions = [];
@track thankYouText = '';
@track isLoading = true;
@track isSubmitting = false;
@track isSubmitted = false;
@track error;
@track responses = new Map();
@track canChooseAnonymous = false;
@track anonymousValue = 'User';
@track anonymousOptions = [
{ label: 'Identified', value: 'User' },
{ label: 'Anonymous', value: 'Anonymous' }
];

connectedCallback() {
this.loadSurvey();
}

loadSurvey() {
this.isLoading = true;
this.error = null;

getSurveyData({
surveyId: this.recordId,
caseId: this.caseId || null,
contactId: this.contactId || null
})
.then((data) => {
this.survey = data.survey;
this.surveyName = data.survey.Name;
this.surveyHeader = data.survey.Survey_Header__c;
this.showSurveyName = !data.survey.Hide_Survey_Name__c;
this.questions = data.questions;
this.visibleQuestions = this.questions.filter((q) => !q.hideOnSurvey);

// Set anonymous options
if (data.isInternal && !data.survey.All_Responses_Anonymous__c) {
this.canChooseAnonymous = true;
this.anonymousValue = 'User';
} else {
this.canChooseAnonymous = false;
this.anonymousValue = 'Anonymous';
}

this.isLoading = false;
})
.catch((error) => {
this.error = this.getErrorMessage(error);
this.isLoading = false;
});
}

handleResponseChange(event) {
const detail = event.detail;
const questionId = detail.questionId;

if (!this.responses.has(questionId)) {
this.responses.set(questionId, {
questionId: questionId,
response: '',
responses: []
});
}

const response = this.responses.get(questionId);

if (detail.questionType === 'Multi-Select--Vertical') {
// Handle multi-select
if (detail.checked) {
if (!response.responses.includes(detail.value)) {
response.responses.push(detail.value);
}
} else {
response.responses = response.responses.filter((v) => v !== detail.value);
}
} else {
// Handle single select and free text
response.response = detail.value;
}
}

handleAnonymousChange(event) {
this.anonymousValue = event.detail.value;
}

handleSubmit() {
// Validate required fields
const requiredQuestions = this.visibleQuestions.filter((q) => q.required);
const missingResponses = [];

for (const question of requiredQuestions) {
const response = this.responses.get(question.id);
if (!response || (!response.response && (!response.responses || response.responses.length === 0))) {
missingResponses.push(question);
}
}

if (missingResponses.length > 0) {
this.showToast('Error', 'Please answer all required questions', 'error');
return;
}

this.isSubmitting = true;

// Convert map to array for Apex
const responsesArray = Array.from(this.responses.values());

submitSurveyResponses({
surveyId: this.recordId,
responses: responsesArray,
caseId: this.caseId || null,
contactId: this.contactId || null,
isAnonymous: this.anonymousValue === 'Anonymous'
})
.then((result) => {
if (result.success) {
this.isSubmitted = true;
this.thankYouText = result.thankYouText;
this.showToast('Success', result.message, 'success');
} else {
this.showToast('Error', result.message, 'error');
this.isSubmitting = false;
}
})
.catch((error) => {
this.showToast('Error', this.getErrorMessage(error), 'error');
this.isSubmitting = false;
});
}

getErrorMessage(error) {
if (error.body && error.body.message) {
return error.body.message;
} else if (error.message) {
return error.message;
} else if (typeof error === 'string') {
return error;
}
return 'An unexpected error occurred';
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
