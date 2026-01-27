import { LightningElement, api } from 'lwc';

/**
 * Dynamic Hero Banner for Survey Force Home
 * Displays context-driven status summary with primary action
 */
export default class SurveyHomeHero extends LightningElement {
	@api homeData;

	get headline() {
		if (!this.homeData) {
			return 'Welcome to Survey Force';
		}

		const { drafts, readyToLaunch, active, stalled } = this.homeData;

		// Prioritize messaging based on state
		if (drafts > 0) {
			return `${drafts} ${drafts === 1 ? 'survey' : 'surveys'} ${drafts === 1 ? 'needs' : 'need'} questions`;
		}
		if (readyToLaunch > 0) {
			return `${readyToLaunch} ${readyToLaunch === 1 ? 'survey is' : 'surveys are'} ready to launch`;
		}
		if (stalled > 0) {
			return `${stalled} ${stalled === 1 ? 'survey needs' : 'surveys need'} attention`;
		}
		if (active > 0) {
			return `${active} ${active === 1 ? 'survey is' : 'surveys are'} collecting responses`;
		}

		return 'Create your first survey';
	}

	get subheadline() {
		if (!this.homeData) {
			return 'Create, distribute, and analyze surveys with ease';
		}

		const { drafts, readyToLaunch, active, stalled } = this.homeData;

		if (drafts > 0) {
			return 'Add questions to publish your surveys';
		}
		if (readyToLaunch > 0) {
			return 'Generate links to start collecting responses';
		}
		if (stalled > 0) {
			return 'These surveys have had no activity for over 30 days';
		}
		if (active > 0) {
			return 'View analytics and manage your surveys';
		}

		return 'Build surveys quickly with our intuitive creator';
	}

	get primaryAction() {
		if (!this.homeData) {
			return { label: 'Create Survey', variant: 'brand', action: 'create' };
		}

		const { drafts, readyToLaunch, stalled } = this.homeData;

		if (drafts > 0) {
			return { label: 'Review Drafts', variant: 'brand', action: 'drafts' };
		}
		if (readyToLaunch > 0) {
			return { label: 'Generate Links', variant: 'brand', action: 'links' };
		}
		if (stalled > 0) {
			return { label: 'Review Surveys', variant: 'brand', action: 'dashboard' };
		}

		return { label: 'Create Survey', variant: 'brand', action: 'create' };
	}

	handlePrimaryAction() {
		const action = this.primaryAction.action;
		this.dispatchEvent(
			new CustomEvent('navigate', {
				detail: { action }
			})
		);
	}
}
