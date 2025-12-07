import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getSurveyResponses from '@salesforce/apex/SurveyTakerController.getSurveyResponses';

const SURVEY_FIELDS = ['Survey__c.Name', 'Survey__c.Questions__c', 'Survey__c.Completed_Surveys__c'];

/**
 * Comprehensive survey results dashboard with analytics and visualizations
 * Modern SLDS 2 design for immersive results viewing experience
 */
export default class SurveyResultsDashboard extends LightningElement {
	@api recordId; // Survey ID

	@track isLoading = true;
	@track error = null;
	@track responses = [];
	@track selectedView = 'overview';
	@track selectedQuestion = null;

	// Survey data from record
	surveyName;
	totalQuestions;
	totalResponses;

	@wire(getRecord, { recordId: '$recordId', fields: SURVEY_FIELDS })
	wiredSurvey({ error, data }) {
		if (data) {
			this.surveyName = getFieldValue(data, 'Survey__c.Name');
			this.totalQuestions = getFieldValue(data, 'Survey__c.Questions__c');
			this.totalResponses = getFieldValue(data, 'Survey__c.Completed_Surveys__c');
		} else if (error) {
			this.error = 'Error loading survey details';
		}
	}

	connectedCallback() {
		if (this.recordId) {
			this.loadResponses();
		}
	}

	loadResponses() {
		this.isLoading = true;
		this.error = null;

		getSurveyResponses({ surveyId: this.recordId })
			.then((result) => {
				this.responses = result || [];
				this.isLoading = false;
			})
			.catch((error) => {
				this.error = error.body?.message || 'Error loading responses';
				this.isLoading = false;
				this.showToast('Error', this.error, 'error');
			});
	}

	// Computed properties
	get hasResponses() {
		return this.responses && this.responses.length > 0;
	}

	get completionRate() {
		if (!this.totalQuestions || this.totalQuestions === 0) return '0%';
		return '100%'; // Since we only have completed surveys
	}

	get averageTimeToComplete() {
		// Placeholder - would need to calculate from response timestamps
		return 'N/A';
	}

	get responsesByDate() {
		if (!this.responses || this.responses.length === 0) return [];

		// Group responses by date
		const grouped = {};
		this.responses.forEach((response) => {
			const date = new Date(response.CreatedDate).toLocaleDateString();
			grouped[date] = (grouped[date] || 0) + 1;
		});

		return Object.keys(grouped)
			.sort()
			.map((date) => ({
				date,
				count: grouped[date]
			}))
			.slice(-7); // Last 7 days
	}

	get viewOptions() {
		return [
			{ label: 'Overview', value: 'overview' },
			{ label: 'Individual Responses', value: 'responses' },
			{ label: 'Question Analysis', value: 'questions' }
		];
	}

	get isOverviewView() {
		return this.selectedView === 'overview';
	}

	get isResponsesView() {
		return this.selectedView === 'responses';
	}

	get isQuestionsView() {
		return this.selectedView === 'questions';
	}

	// Event handlers
	handleViewChange(event) {
		this.selectedView = event.detail.value;
	}

	handleRefresh() {
		this.loadResponses();
		this.showToast('Success', 'Results refreshed', 'success');
	}

	handleExport() {
		// Placeholder for export functionality
		this.showToast('Info', 'Export functionality coming soon', 'info');
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
