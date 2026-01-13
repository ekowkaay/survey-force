import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

/**
 * Survey Force Home Page - Immersive entry point with guided workflows
 * Provides modern SLDS 2 design with clear pathways for different user journeys
 */
export default class SurveyForceHome extends NavigationMixin(LightningElement) {
	@track selectedWorkflow = null;

	workflows = [
		{
			id: 'create',
			title: 'Create a Survey',
			description: 'Build a new survey from scratch with our intuitive builder',
			icon: 'utility:add',
			iconBg: 'slds-icon-standard-survey',
			steps: ['Design questions', 'Configure settings', 'Preview and publish'],
			action: 'handleCreateSurvey'
		},
		{
			id: 'generate',
			title: 'Generate Survey Links',
			description: 'Create unique invitation links to share with participants',
			icon: 'utility:link',
			iconBg: 'slds-icon-standard-link',
			steps: ['Generate unique links', 'Copy and share', 'Track responses'],
			action: 'handleGenerateLinks'
		},
		{
			id: 'manage',
			title: 'Manage Surveys',
			description: 'View, edit, and analyze your existing surveys',
			icon: 'utility:list',
			iconBg: 'slds-icon-standard-survey',
			steps: ['View all surveys', 'Edit or clone', 'Review responses'],
			action: 'handleManageSurveys'
		},
		{
			id: 'analytics',
			title: 'View Analytics',
			description: 'Explore insights and performance metrics',
			icon: 'utility:chart',
			iconBg: 'slds-icon-standard-metrics',
			steps: ['Review metrics', 'Analyze responses', 'Export data'],
			action: 'handleViewAnalytics'
		}
	];

	resources = [
		{
			title: 'Getting Started Guide',
			description: 'Learn the basics of Survey Force',
			icon: 'utility:knowledge_base',
			action: 'handleGettingStarted'
		},
		{
			title: 'Sample Survey',
			description: 'Create a sample survey to explore features',
			icon: 'utility:preview',
			action: 'handleCreateSample'
		},
		{
			title: 'Best Practices',
			description: 'Tips for creating effective surveys',
			icon: 'utility:tips',
			action: 'handleBestPractices'
		}
	];

	get hasSelectedWorkflow() {
		return this.selectedWorkflow !== null;
	}

	get currentWorkflow() {
		return this.workflows.find((w) => w.id === this.selectedWorkflow);
	}

	handleWorkflowSelect(event) {
		const workflowId = event.currentTarget.dataset.workflowId;
		const workflow = this.workflows.find((w) => w.id === workflowId);
		if (workflow) {
			this[workflow.action]();
		}
	}

	handleCreateSurvey() {
		this[NavigationMixin.Navigate]({
			type: 'standard__navItemPage',
			attributes: {
				apiName: 'Create_Survey'
			}
		});
	}

	handleGenerateLinks() {
		this[NavigationMixin.Navigate]({
			type: 'standard__navItemPage',
			attributes: {
				apiName: 'Survey_Link_Generator'
			}
		});
	}

	handleManageSurveys() {
		this[NavigationMixin.Navigate]({
			type: 'standard__navItemPage',
			attributes: {
				apiName: 'Survey_Dashboard'
			}
		});
	}

	handleViewAnalytics() {
		this[NavigationMixin.Navigate]({
			type: 'standard__navItemPage',
			attributes: {
				apiName: 'Survey_Analytics'
			}
		});
	}

	handleGettingStarted() {
		this[NavigationMixin.Navigate]({
			type: 'standard__navItemPage',
			attributes: {
				apiName: 'Getting_Started_LWC'
			}
		});
	}

	handleCreateSample() {
		this[NavigationMixin.Navigate]({
			type: 'standard__navItemPage',
			attributes: {
				apiName: 'Getting_Started_LWC'
			}
		});
	}

	handleBestPractices() {
		this[NavigationMixin.Navigate]({
			type: 'standard__navItemPage',
			attributes: {
				apiName: 'Getting_Started_LWC'
			}
		});
	}
}
