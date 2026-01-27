import { LightningElement, api } from 'lwc';

/**
 * Operational Snapshot for Survey Force Home
 * Displays key metrics about survey status
 */
export default class SurveyHomeSnapshot extends LightningElement {
	@api homeData;

	get metrics() {
		if (!this.homeData) {
			return this.emptyMetrics;
		}

		return [
			{
				id: 'drafts',
				label: 'Drafts',
				value: this.homeData.drafts || 0,
				icon: 'utility:edit',
				iconVariant: 'warning',
				description: 'Surveys without questions'
			},
			{
				id: 'ready',
				label: 'Ready to Launch',
				value: this.homeData.readyToLaunch || 0,
				icon: 'utility:rocket',
				iconVariant: 'success',
				description: 'Surveys ready to share'
			},
			{
				id: 'active',
				label: 'Active',
				value: this.homeData.active || 0,
				icon: 'utility:success',
				iconVariant: 'success',
				description: 'Surveys with responses'
			},
			{
				id: 'stalled',
				label: 'Need Attention',
				value: this.homeData.stalled || 0,
				icon: 'utility:warning',
				iconVariant: 'error',
				description: 'No activity for 30+ days'
			}
		];
	}

	get emptyMetrics() {
		return [
			{
				id: 'drafts',
				label: 'Drafts',
				value: 0,
				icon: 'utility:edit',
				iconVariant: 'warning',
				description: 'Surveys without questions'
			},
			{
				id: 'ready',
				label: 'Ready to Launch',
				value: 0,
				icon: 'utility:rocket',
				iconVariant: 'success',
				description: 'Surveys ready to share'
			},
			{
				id: 'active',
				label: 'Active',
				value: 0,
				icon: 'utility:success',
				iconVariant: 'success',
				description: 'Surveys with responses'
			},
			{
				id: 'stalled',
				label: 'Need Attention',
				value: 0,
				icon: 'utility:warning',
				iconVariant: 'error',
				description: 'No activity for 30+ days'
			}
		];
	}
}
