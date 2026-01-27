import { LightningElement, api } from 'lwc';

/**
 * Action Center for Survey Force Home
 * Displays contextual action buttons based on survey state
 */
export default class SurveyHomeActionCenter extends LightningElement {
	@api homeData;

	get actions() {
		if (!this.homeData) {
			return this.defaultActions;
		}

		const actionList = [];
		const { drafts, readyToLaunch, active } = this.homeData;

		// Draft completion CTA when drafts exist
		if (drafts > 0) {
			actionList.push({
				id: 'drafts',
				title: 'Complete Draft Surveys',
				description: `${drafts} ${drafts === 1 ? 'survey needs' : 'surveys need'} questions`,
				icon: 'utility:edit',
				iconBg: 'slds-icon-standard-drafts',
				action: 'drafts',
				variant: 'brand'
			});
		}

		// Generate Links CTA when surveys are ready but have no responses
		if (readyToLaunch > 0) {
			actionList.push({
				id: 'links',
				title: 'Generate Survey Links',
				description: `${readyToLaunch} ${readyToLaunch === 1 ? 'survey is' : 'surveys are'} ready to share`,
				icon: 'utility:link',
				iconBg: 'slds-icon-standard-link',
				action: 'links',
				variant: 'brand'
			});
		}

		// View Dashboard CTA when active surveys exist
		if (active > 0) {
			actionList.push({
				id: 'dashboard',
				title: 'View Survey Dashboard',
				description: `${active} ${active === 1 ? 'survey is' : 'surveys are'} collecting responses`,
				icon: 'utility:list',
				iconBg: 'slds-icon-standard-survey',
				action: 'dashboard',
				variant: 'neutral'
			});
		}

		// Always show Create Survey
		actionList.push({
			id: 'create',
			title: 'Create New Survey',
			description: 'Build a new survey from scratch',
			icon: 'utility:add',
			iconBg: 'slds-icon-standard-survey',
			action: 'create',
			variant: actionList.length === 0 ? 'brand' : 'neutral'
		});

		return actionList.slice(0, 4); // Limit to 4 actions
	}

	get defaultActions() {
		return [
			{
				id: 'create',
				title: 'Create New Survey',
				description: 'Build a new survey from scratch',
				icon: 'utility:add',
				iconBg: 'slds-icon-standard-survey',
				action: 'create',
				variant: 'brand'
			},
			{
				id: 'templates',
				title: 'Manage Templates',
				description: 'View and manage survey templates',
				icon: 'utility:layers',
				iconBg: 'slds-icon-standard-survey',
				action: 'templates',
				variant: 'neutral'
			}
		];
	}

	handleActionClick(event) {
		const actionId = event.currentTarget.dataset.actionId;
		this.dispatchEvent(
			new CustomEvent('navigate', {
				detail: { action: actionId }
			})
		);
	}
}
