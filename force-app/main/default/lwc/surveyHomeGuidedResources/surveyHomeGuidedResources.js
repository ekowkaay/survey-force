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

		const { totalSurveys, drafts, readyToLaunch, active } = this.homeData;

		return [
			{
				id: 'create',
				label: 'Create your first survey',
				completed: totalSurveys > 0,
				description: 'Build a survey with our intuitive creator'
			},
			{
				id: 'questions',
				label: 'Add questions to a survey',
				completed: totalSurveys > drafts,
				description: 'Design meaningful questions for your audience'
			},
			{
				id: 'links',
				label: 'Generate survey links',
				completed: active > 0 || (totalSurveys > 0 && readyToLaunch < totalSurveys),
				description: 'Create unique links to share with participants'
			},
			{
				id: 'responses',
				label: 'Collect survey responses',
				completed: active > 0,
				description: 'Share your survey and gather feedback'
			},
			{
				id: 'analytics',
				label: 'Review survey analytics',
				completed: active > 0,
				description: 'Analyze results and gain insights'
			}
		];
	}

	get defaultChecklist() {
		return [
			{
				id: 'create',
				label: 'Create your first survey',
				completed: false,
				description: 'Build a survey with our intuitive creator'
			},
			{
				id: 'questions',
				label: 'Add questions to a survey',
				completed: false,
				description: 'Design meaningful questions for your audience'
			},
			{
				id: 'links',
				label: 'Generate survey links',
				completed: false,
				description: 'Create unique links to share with participants'
			},
			{
				id: 'responses',
				label: 'Collect survey responses',
				completed: false,
				description: 'Share your survey and gather feedback'
			},
			{
				id: 'analytics',
				label: 'Review survey analytics',
				completed: false,
				description: 'Analyze results and gain insights'
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
}
