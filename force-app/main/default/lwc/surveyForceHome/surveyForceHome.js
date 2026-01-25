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
			id: 'templates',
			title: 'Manage Survey Templates',
			description: 'View, create, edit, and clone survey templates',
			icon: 'utility:layers',
			iconBg: 'slds-icon-standard-survey',
			steps: ['View templates', 'Create or clone', 'Edit and customize'],
			action: 'handleManageTemplates'
		},
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
			id: 'manage',
			title: 'Manage Surveys',
			description: 'View, edit, and analyze your existing surveys',
			icon: 'utility:list',
			iconBg: 'slds-icon-standard-survey',
			steps: ['View all surveys', 'Edit or clone', 'Review responses'],
			action: 'handleManageSurveys'
		},
		{
			id: 'regenerate',
			title: 'Regenerate Survey Invitations',
			description: 'Regenerate survey invitations in bulk',
			icon: 'utility:refresh',
			iconBg: 'slds-icon-standard-link',
			steps: ['Upload training requests', 'Process invitations', 'Track regeneration'],
			action: 'handleRegenerateInvitations'
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

	handleManageTemplates() {
		this[NavigationMixin.Navigate]({
			type: 'standard__navItemPage',
			attributes: {
				apiName: 'Survey_Templates'
			}
		});
	}

	handleRegenerateInvitations() {
		this[NavigationMixin.Navigate]({
			type: 'standard__navItemPage',
			attributes: {
				apiName: 'Survey_Regeneration'
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
