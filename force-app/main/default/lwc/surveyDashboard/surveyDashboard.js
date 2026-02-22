import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllSurveys from '@salesforce/apex/SurveyTemplateController.getAllSurveys';

/**
 * Survey operations dashboard providing an overview of survey health and readiness
 * Uses SLDS 2 design patterns for modern, engaging user experience
 */
export default class SurveyDashboard extends NavigationMixin(LightningElement) {
	@track surveys = [];
	@track isLoading = true;
	@track error = null;
	@track selectedTimeframe = 'all';
	@track searchTerm = '';

	// Computed operational metrics
	get totalSurveys() {
		return this.filteredSurveys.length;
	}

	get totalQuestions() {
		return this.filteredSurveys.reduce((sum, survey) => sum + (survey.Questions__c || 0), 0);
	}

	get averageQuestionsPerSurvey() {
		if (this.totalSurveys === 0) return 0;
		return Math.round(this.totalQuestions / this.totalSurveys);
	}

	get surveysWithResponses() {
		return this.filteredSurveys.filter((survey) => (survey.Completed_Surveys__c || 0) > 0);
	}

	get activeSurveysCount() {
		return this.surveysWithResponses.length;
	}

	get draftSurveys() {
		return this.filteredSurveys.filter((survey) => (survey.Questions__c || 0) === 0);
	}

	get draftSurveysCount() {
		return this.draftSurveys.length;
	}

	get readyToLaunchSurveys() {
		return this.filteredSurveys.filter((survey) => (survey.Questions__c || 0) > 0 && (survey.Completed_Surveys__c || 0) === 0 && !this.isSurveyStalled(survey));
	}

	get readyToLaunchCount() {
		return this.readyToLaunchSurveys.length;
	}

	get stalledSurveys() {
		return this.filteredSurveys.filter((survey) => this.isSurveyStalled(survey));
	}

	get stalledSurveysCount() {
		return this.stalledSurveys.length;
	}

	get surveysAwaitingResponses() {
		return this.filteredSurveys.filter((survey) => (survey.Questions__c || 0) > 0 && (survey.Completed_Surveys__c || 0) === 0);
	}

	get surveysAwaitingResponsesCount() {
		return this.surveysAwaitingResponses.length;
	}

	get filteredSurveys() {
		if (!this.surveys) return [];

		let filtered = this.surveys;

		// Apply search filter
		if (this.searchTerm) {
			const term = this.searchTerm.toLowerCase();
			filtered = filtered.filter((survey) => survey.Name.toLowerCase().includes(term));
		}

		// Apply timeframe filter
		const now = new Date();
		if (this.selectedTimeframe === '7days') {
			const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
			filtered = filtered.filter((s) => new Date(s.CreatedDate) >= sevenDaysAgo);
		} else if (this.selectedTimeframe === '30days') {
			const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
			filtered = filtered.filter((s) => new Date(s.CreatedDate) >= thirtyDaysAgo);
		}

		return filtered;
	}

	get needsAttentionSurveys() {
		if (!this.filteredSurveys || this.filteredSurveys.length === 0) return [];

		const attention = [...this.filteredSurveys].filter((survey) => (survey.Questions__c || 0) === 0 || this.isSurveyStalled(survey));

		return attention
			.sort((a, b) => new Date(a.CreatedDate) - new Date(b.CreatedDate))
			.slice(0, 5)
			.map((survey) => this.decorateSurvey(survey));
	}

	get recentSurveys() {
		if (!this.filteredSurveys || this.filteredSurveys.length === 0) return [];

		return [...this.filteredSurveys]
			.sort((a, b) => new Date(b.CreatedDate) - new Date(a.CreatedDate))
			.slice(0, 5)
			.map((survey) => this.decorateSurvey(survey));
	}

	get hasSurveys() {
		return this.surveys && this.surveys.length > 0;
	}

	get hasFilteredResults() {
		return this.filteredSurveys && this.filteredSurveys.length > 0;
	}

	get timeframeOptions() {
		return [
			{ label: 'All Time', value: 'all' },
			{ label: 'Last 7 Days', value: '7days' },
			{ label: 'Last 30 Days', value: '30days' }
		];
	}

	get lifecycleSummary() {
		const total = this.totalSurveys || 1;
		return [
			{ label: 'Drafts', count: this.draftSurveysCount, tone: 'draft', percent: Math.round((this.draftSurveysCount / total) * 100) },
			{ label: 'Ready to Launch', count: this.readyToLaunchCount, tone: 'ready', percent: Math.round((this.readyToLaunchCount / total) * 100) },
			{ label: 'Active', count: this.activeSurveysCount, tone: 'active', percent: Math.round((this.activeSurveysCount / total) * 100) },
			{ label: 'Stalled', count: this.stalledSurveysCount, tone: 'stalled', percent: Math.round((this.stalledSurveysCount / total) * 100) }
		].map((stage) => ({
			...stage,
			className: `lifecycle-bar__fill lifecycle-${stage.tone}`,
			style: `width:${stage.percent}%;`
		}));
	}

	get checklistItems() {
		return [
			{ id: 'define', title: 'Define survey objective', detail: 'Confirm audience, purpose, and success metrics.' },
			{ id: 'build', title: 'Build question flow', detail: 'Ensure required questions and scale labels are set.' },
			{ id: 'publish', title: 'Publish and generate links', detail: 'Create shareable links for participants.' },
			{ id: 'monitor', title: 'Monitor early responses', detail: 'Check completion trends and update wording.' }
		];
	}

	connectedCallback() {
		this.loadDashboardData();
	}

	loadDashboardData() {
		this.isLoading = true;
		this.error = null;

		getAllSurveys()
			.then((result) => {
				this.surveys = result;
				this.isLoading = false;
			})
			.catch((error) => {
				this.error = 'Unable to load dashboard data. Please check your network connection and try refreshing the page. Details: ' + (error.body?.message || 'Unknown error');
				this.isLoading = false;
				this.showToast('Error', this.error, 'error');
			});
	}

	handleRefresh() {
		this.loadDashboardData();
		this.showToast('Success', 'Dashboard refreshed', 'success');
	}

	handleSearchChange(event) {
		this.searchTerm = event.target.value;
	}

	handleTimeframeChange(event) {
		this.selectedTimeframe = event.detail.value;
	}

	handleCreateSurvey() {
		this[NavigationMixin.Navigate]({
			type: 'standard__navItemPage',
			attributes: {
				apiName: 'Create_Survey'
			}
		});
	}

	handleViewSurvey(event) {
		const surveyId = event.currentTarget.dataset.surveyId;
		this[NavigationMixin.Navigate]({
			type: 'standard__recordPage',
			attributes: {
				recordId: surveyId,
				objectApiName: 'Survey__c',
				actionName: 'view'
			}
		});
	}

	handleViewAllSurveys() {
		this[NavigationMixin.Navigate]({
			type: 'standard__navItemPage',
			attributes: {
				apiName: 'Survey_Dashboard'
			}
		});
	}

	isSurveyStalled(survey) {
		if ((survey.Completed_Surveys__c || 0) > 0 || (survey.Questions__c || 0) === 0) {
			return false;
		}
		const cutoff = new Date();
		cutoff.setDate(cutoff.getDate() - 14);
		return new Date(survey.CreatedDate) < cutoff;
	}

	decorateSurvey(survey) {
		let statusLabel = 'Ready';
		let statusClass = 'status-pill status-ready';

		if ((survey.Questions__c || 0) === 0) {
			statusLabel = 'Draft';
			statusClass = 'status-pill status-draft';
		} else if (this.isSurveyStalled(survey)) {
			statusLabel = 'Stalled';
			statusClass = 'status-pill status-stalled';
		} else if ((survey.Completed_Surveys__c || 0) > 0) {
			statusLabel = 'Active';
			statusClass = 'status-pill status-active';
		}

		return {
			...survey,
			statusLabel,
			statusClass
		};
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
