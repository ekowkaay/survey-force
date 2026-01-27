import { LightningElement, api } from 'lwc';

/**
 * Guided Resources for Survey Force Home
 * Displays onboarding checklist and contextual resources
 */
export default class SurveyHomeGuidedResources extends LightningElement {
	@api homeData;

	get checklist() {
		if (!this.homeData) {
			return this.defaultChecklist;
		}

		const { totalSurveys, drafts, active } = this.homeData;

		return [
			{
				id: 'create',
				label: 'Create your first survey',
				completed: totalSurveys > 0,
				description: 'Build a survey with our intuitive creator',
				iconName: totalSurveys > 0 ? 'utility:check' : 'utility:chevronright',
				iconVariant: totalSurveys > 0 ? 'success' : 'default'
			},
			{
				id: 'questions',
				label: 'Add questions to a survey',
				completed: totalSurveys > drafts,
				description: 'Design meaningful questions for your audience',
				iconName: totalSurveys > drafts ? 'utility:check' : 'utility:chevronright',
				iconVariant: totalSurveys > drafts ? 'success' : 'default'
			},
			{
				id: 'links',
				label: 'Generate survey links',
				completed: active > 0,
				description: 'Create unique links to share with participants',
				iconName: active > 0 ? 'utility:check' : 'utility:chevronright',
				iconVariant: active > 0 ? 'success' : 'default'
			},
			{
				id: 'responses',
				label: 'Collect survey responses',
				completed: active > 0,
				description: 'Share your survey and gather feedback',
				iconName: active > 0 ? 'utility:check' : 'utility:chevronright',
				iconVariant: active > 0 ? 'success' : 'default'
			},
			{
				id: 'analytics',
				label: 'Review survey analytics',
				completed: active > 0,
				description: 'Analyze results and gain insights',
				iconName: active > 0 ? 'utility:check' : 'utility:chevronright',
				iconVariant: active > 0 ? 'success' : 'default'
			}
		];
	}

	get defaultChecklist() {
		return [
			{
				id: 'create',
				label: 'Create your first survey',
				completed: false,
				description: 'Build a survey with our intuitive creator',
				iconName: 'utility:chevronright',
				iconVariant: 'default'
			},
			{
				id: 'questions',
				label: 'Add questions to a survey',
				completed: false,
				description: 'Design meaningful questions for your audience',
				iconName: 'utility:chevronright',
				iconVariant: 'default'
			},
			{
				id: 'links',
				label: 'Generate survey links',
				completed: false,
				description: 'Create unique links to share with participants',
				iconName: 'utility:chevronright',
				iconVariant: 'default'
			},
			{
				id: 'responses',
				label: 'Collect survey responses',
				completed: false,
				description: 'Share your survey and gather feedback',
				iconName: 'utility:chevronright',
				iconVariant: 'default'
			},
			{
				id: 'analytics',
				label: 'Review survey analytics',
				completed: false,
				description: 'Analyze results and gain insights',
				iconName: 'utility:chevronright',
				iconVariant: 'default'
			}
		];
	}

	get resources() {
		const stage = this.getCurrentStage();

		const allResources = {
			drafting: [
				{
					id: 'tips-questions',
					title: 'Writing Effective Questions',
					description: 'Learn best practices for creating clear, unbiased survey questions',
					icon: 'utility:knowledge_base'
				}
			],
			ready: [
				{
					id: 'tips-distribution',
					title: 'Survey Distribution Tips',
					description: 'Strategies for reaching your target audience',
					icon: 'utility:knowledge_base'
				}
			],
			active: [
				{
					id: 'tips-analytics',
					title: 'Analyzing Survey Results',
					description: 'Make the most of your survey data',
					icon: 'utility:knowledge_base'
				}
			],
			default: [
				{
					id: 'getting-started',
					title: 'Getting Started Guide',
					description: 'Learn the basics of Survey Force',
					icon: 'utility:knowledge_base'
				}
			]
		};

		return allResources[stage] || allResources.default;
	}

	getCurrentStage() {
		if (!this.homeData) {
			return 'default';
		}

		const { drafts, readyToLaunch, active } = this.homeData;

		if (active > 0) {
			return 'active';
		}
		if (readyToLaunch > 0) {
			return 'ready';
		}
		if (drafts > 0) {
			return 'drafting';
		}

		return 'default';
	}

	handleResourceClick(event) {
		const resourceId = event.currentTarget.dataset.resourceId;
		this.dispatchEvent(
			new CustomEvent('navigate', {
				detail: { action: 'gettingstarted', resourceId }
			})
		);
	}

	handleResourceKeyDown(event) {
		// Handle Enter and Space key presses for keyboard accessibility
		if (event.key === 'Enter' || event.key === ' ') {
			event.preventDefault();
			this.handleResourceClick(event);
		}
	}
}
