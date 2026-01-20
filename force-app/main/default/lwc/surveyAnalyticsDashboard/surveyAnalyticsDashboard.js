import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllSurveys from '@salesforce/apex/SurveyTemplateController.getAllSurveys';

/**
 * Modern analytics dashboard providing immersive overview of all surveys
 * Uses SLDS 2 design patterns for modern, engaging user experience
 */
export default class SurveyAnalyticsDashboard extends NavigationMixin(LightningElement) {
	@track surveys = [];
	@track isLoading = true;
	@track error = null;
	@track selectedTimeframe = 'all';
	@track searchTerm = '';

	workflows = [
		{
			id: 'manage',
			title: 'Manage Surveys',
			description: 'View, edit, and analyze your existing surveys',
			icon: 'utility:list',
			steps: ['View all surveys', 'Edit or clone', 'Review responses'],
			action: 'handleViewAllSurveys'
		},
		{
			id: 'generate',
			title: 'Generate Survey Links',
			description: 'Create unique invitation links to share with participants',
			icon: 'utility:link',
			steps: ['Generate unique links', 'Copy and share', 'Track responses'],
			action: 'handleGenerateLinks'
		},
		{
			id: 'create',
			title: 'Create a Survey',
			description: 'Build a new survey from scratch with our intuitive builder',
			icon: 'utility:add',
			steps: ['Design questions', 'Configure settings', 'Preview and publish'],
			action: 'handleCreateSurvey'
		}
	];

	// Computed analytics
	get totalSurveys() {
		return this.filteredSurveys.length;
	}

	get totalResponses() {
		return this.filteredSurveys.reduce((sum, survey) => sum + (survey.Completed_Surveys__c || 0), 0);
	}

	get totalQuestions() {
		return this.filteredSurveys.reduce((sum, survey) => sum + (survey.Questions__c || 0), 0);
	}

	get averageResponsesPerSurvey() {
		if (this.totalSurveys === 0) return 0;
		return Math.round(this.totalResponses / this.totalSurveys);
	}

	get activeSurveys() {
		return this.filteredSurveys.filter((s) => (s.Completed_Surveys__c || 0) > 0).length;
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

	get topPerformingSurveys() {
		if (!this.filteredSurveys || this.filteredSurveys.length === 0) return [];

		return [...this.filteredSurveys]
			.sort((a, b) => (b.Completed_Surveys__c || 0) - (a.Completed_Surveys__c || 0))
			.slice(0, 5)
			.map((survey) => ({
				...survey,
				responsePercentage: this.totalResponses > 0 ? Math.round(((survey.Completed_Surveys__c || 0) / this.totalResponses) * 100) : 0
			}));
	}

	get recentSurveys() {
		if (!this.filteredSurveys || this.filteredSurveys.length === 0) return [];

		return [...this.filteredSurveys].sort((a, b) => new Date(b.CreatedDate) - new Date(a.CreatedDate)).slice(0, 5);
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
				this.error = error.body?.message || 'Error loading dashboard data';
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

	handleWorkflowSelect(event) {
		const workflowId = event.currentTarget.dataset.workflowId;
		const workflow = this.workflows.find((w) => w.id === workflowId);
		if (workflow) {
			this[workflow.action]();
		}
	}

	handleGenerateLinks() {
		this[NavigationMixin.Navigate]({
			type: 'standard__navItemPage',
			attributes: {
				apiName: 'Survey_Link_Generator'
			}
		});
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

	showToast(title, message, variant) {
		const event = new ShowToastEvent({
			title: title,
			message: message,
			variant: variant
		});
		this.dispatchEvent(event);
	}
}
