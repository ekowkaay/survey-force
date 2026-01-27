import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getHomePageData from '@salesforce/apex/SurveyHomeController.getHomePageData';

/**
 * Survey Force Home Page - Operations hub with dynamic status and actions
 * Displays readiness, actions, and recent activity
 */
export default class SurveyForceHome extends NavigationMixin(LightningElement) {
	homeData;
	error;
	isLoading = true;

	@wire(getHomePageData)
	wiredHomeData({ error, data }) {
		this.isLoading = false;
		if (data) {
			this.homeData = data;
			this.error = undefined;
		} else if (error) {
			this.error = error;
			this.homeData = undefined;
			console.error('Error loading home page data:', error);
		}
	}

	handleNavigate(event) {
		const action = event.detail.action;
		this.navigateToPage(action);
	}

	navigateToPage(action) {
		const navigationMap = {
			create: 'Create_Survey',
			templates: 'Survey_Templates',
			dashboard: 'Survey_Dashboard',
			drafts: 'Survey_Dashboard',
			links: 'Survey_Link_Generator',
			gettingstarted: 'Getting_Started_LWC'
		};

		const apiName = navigationMap[action];
		if (apiName) {
			this[NavigationMixin.Navigate]({
				type: 'standard__navItemPage',
				attributes: {
					apiName: apiName
				}
			});
		}
	}
}
