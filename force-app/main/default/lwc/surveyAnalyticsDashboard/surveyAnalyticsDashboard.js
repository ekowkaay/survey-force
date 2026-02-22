import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getSurveyData from '@salesforce/apex/SurveyTakerController.getSurveyData';
import getSurveyResponses from '@salesforce/apex/SurveyTakerController.getSurveyResponses';

const SURVEY_FIELDS = ['Survey__c.Name', 'Survey__c.Questions__c', 'Survey__c.Completed_Surveys__c'];

/**
 * Comprehensive survey analytics dashboard with analytics and visualizations
 * Modern SLDS 2 design for immersive results viewing experience
 */
export default class SurveyAnalyticsDashboard extends LightningElement {
	@api recordId; // Survey ID

	@track isLoading = true;
	@track error = null;
	@track responses = [];
	@track questions = [];
	@track questionsLoading = false;
	@track selectedView = 'overview';
	@track selectedTimeframe = '30days';
	@track searchTerm = '';

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
			this.error = 'Unable to load survey details. Please verify the survey exists and you have access to view it.';
		}
	}

	connectedCallback() {
		if (this.recordId) {
			this.loadResponses();
			this.loadQuestions();
		} else {
			// When used on non-record targets (App Page / Tab), recordId may be undefined.
			// In that case, stop the loading state so the UI does not show an indefinite spinner.
			this.isLoading = false;
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
				this.error = 'Unable to load survey responses. Please check your network connection and try refreshing. Details: ' + (error.body?.message || 'Unknown error');
				this.isLoading = false;
				this.showToast('Error', this.error, 'error');
			});
	}

	loadQuestions() {
		this.questionsLoading = true;
		getSurveyData({ surveyId: this.recordId, caseId: null, contactId: null })
			.then((result) => {
				this.questions = result?.questions || [];
				this.questionsLoading = false;
			})
			.catch((error) => {
				this.questions = [];
				this.questionsLoading = false;
				// Questions are supplementary, so we don't need to show a toast for this failure
			});
	}

	// Computed properties
	get hasResponses() {
		return this.responses && this.responses.length > 0;
	}

	get filteredResponses() {
		if (!this.responses) return [];

		let filtered = [...this.responses];

		if (this.searchTerm) {
			const term = this.searchTerm.toLowerCase();
			filtered = filtered.filter((response) => (response.Name || '').toLowerCase().includes(term));
		}

		if (this.selectedTimeframe !== 'all') {
			const cutoff = new Date();
			if (this.selectedTimeframe === '7days') {
				cutoff.setDate(cutoff.getDate() - 7);
			} else if (this.selectedTimeframe === '30days') {
				cutoff.setDate(cutoff.getDate() - 30);
			} else if (this.selectedTimeframe === '90days') {
				cutoff.setDate(cutoff.getDate() - 90);
			}
			filtered = filtered.filter((response) => new Date(response.CreatedDate) >= cutoff);
		}

		return filtered;
	}

	get averageTimeToComplete() {
		// Placeholder - would need to calculate from response timestamps
		return 'N/A';
	}

	get responsesByDate() {
		if (!this.filteredResponses || this.filteredResponses.length === 0) return [];

		// Group responses by date
		const grouped = {};
		this.filteredResponses.forEach((response) => {
			const date = new Date(response.CreatedDate).toLocaleDateString();
			grouped[date] = (grouped[date] || 0) + 1;
		});

		const maxCount = Math.max(...Object.values(grouped));
		return Object.keys(grouped)
			.sort()
			.map((date) => ({
				date,
				count: grouped[date],
				barStyle: `width:${Math.max(10, Math.round((grouped[date] / maxCount) * 100))}%`
			}))
			.slice(-7); // Last 7 days
	}

	get responsesLastSevenDays() {
		const now = new Date();
		const cutoff = new Date();
		cutoff.setDate(now.getDate() - 7);
		return this.responses.filter((response) => new Date(response.CreatedDate) >= cutoff).length;
	}

	get responsesPreviousSevenDays() {
		const now = new Date();
		const start = new Date();
		start.setDate(now.getDate() - 14);
		const end = new Date();
		end.setDate(now.getDate() - 7);
		return this.responses.filter((response) => {
			const created = new Date(response.CreatedDate);
			return created >= start && created < end;
		}).length;
	}

	get responseTrend() {
		const previous = this.responsesPreviousSevenDays || 0;
		const current = this.responsesLastSevenDays || 0;
		if (previous === 0 && current === 0) {
			return { label: 'No change', className: 'trend-pill trend-neutral' };
		}
		if (previous === 0) {
			return { label: 'New activity', className: 'trend-pill trend-positive' };
		}
		const delta = Math.round(((current - previous) / previous) * 100);
		return {
			label: `${delta >= 0 ? '+' : ''}${delta}% vs last week`,
			className: delta >= 0 ? 'trend-pill trend-positive' : 'trend-pill trend-negative'
		};
	}

	get uniqueRespondents() {
		const unique = new Set(this.responses.filter((response) => response.Contact__c).map((response) => response.Contact__c));
		return unique.size;
	}

	get caseLinkedResponses() {
		return this.responses.filter((response) => response.Case__c).length;
	}

	get lastResponseDate() {
		if (!this.responses.length) return null;
		return this.responses.reduce((latest, response) => {
			const created = new Date(response.CreatedDate);
			return created > latest ? created : latest;
		}, new Date(0));
	}

	get responseWindowLabel() {
		if (!this.responses.length) return 'N/A';
		const dates = this.responses.map((response) => new Date(response.CreatedDate));
		const earliest = new Date(Math.min(...dates));
		const latest = new Date(Math.max(...dates));
		const diffDays = Math.max(1, Math.ceil((latest - earliest) / (1000 * 60 * 60 * 24)));
		return `${diffDays} day window`;
	}

	get responseRows() {
		return this.filteredResponses.map((response) => ({
			...response,
			contactDisplay: response.Contact__c ? 'Linked' : 'Anonymous',
			caseDisplay: response.Case__c ? 'Linked' : '—'
		}));
	}

	get responseColumns() {
		return [
			{ label: 'Response', fieldName: 'Name', type: 'text' },
			{
				label: 'Submitted',
				fieldName: 'CreatedDate',
				type: 'date',
				typeAttributes: { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }
			},
			{ label: 'Contact', fieldName: 'contactDisplay', type: 'text' },
			{ label: 'Case', fieldName: 'caseDisplay', type: 'text' }
		];
	}

	get questionSummary() {
		if (!this.questions || this.questions.length === 0) return [];

		const grouped = this.questions.reduce((acc, question) => {
			const type = question.questionType || 'Other';
			acc[type] = (acc[type] || 0) + 1;
			return acc;
		}, {});

		return Object.keys(grouped)
			.sort((a, b) => grouped[b] - grouped[a])
			.map((type) => ({
				type,
				count: grouped[type]
			}));
	}

	get requiredQuestionsCount() {
		return this.questions.filter((question) => question.required).length;
	}

	get optionalQuestionsCount() {
		return this.questions.length - this.requiredQuestionsCount;
	}

	get viewOptions() {
		return [
			{ label: 'Overview', value: 'overview' },
			{ label: 'Individual Responses', value: 'responses' },
			{ label: 'Question Analysis', value: 'questions' }
		];
	}

	get timeframeOptions() {
		return [
			{ label: 'Last 7 Days', value: '7days' },
			{ label: 'Last 30 Days', value: '30days' },
			{ label: 'Last 90 Days', value: '90days' },
			{ label: 'All Time', value: 'all' }
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

	handleSearchChange(event) {
		this.searchTerm = event.target.value;
	}

	handleTimeframeChange(event) {
		this.selectedTimeframe = event.detail.value;
	}

	handleRefresh() {
		this.loadResponses();
		this.loadQuestions();
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
