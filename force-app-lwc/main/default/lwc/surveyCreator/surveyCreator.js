import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import checkSiteAvailability from '@salesforce/apex/SurveyCreationController.checkSiteAvailability';
import createSurvey from '@salesforce/apex/SurveyCreationController.createSurvey';
import getRecentSurveys from '@salesforce/apex/SurveyCreationController.getRecentSurveys';

export default class SurveyCreator extends NavigationMixin(LightningElement) {
	@track surveyName = '';
	@track hasExistingSite = true;
	@track isLoading = true;
	@track isCreating = false;
	@track recentSurveys = [];
	@track showRecentSurveys = false;

	connectedCallback() {
		this.loadInitialData();
	}

	loadInitialData() {
		Promise.all([checkSiteAvailability(), getRecentSurveys()])
			.then(([siteInfo, surveys]) => {
				this.hasExistingSite = siteInfo.hasExistingSite;
				this.recentSurveys = surveys;
				this.showRecentSurveys = surveys && surveys.length > 0;
				this.isLoading = false;
			})
			.catch((error) => {
				this.showToast('Error', 'Error loading page: ' + (error.body?.message || error.message), 'error');
				this.isLoading = false;
			});
	}

	get canCreate() {
		return this.hasExistingSite && this.surveyName && this.surveyName.trim().length > 0;
	}

	get siteWarningMessage() {
		return 'Please create a Force.com Site before creating surveys for external users.';
	}

	handleNameChange(event) {
		this.surveyName = event.target.value;
	}

	handleCreateSurvey() {
		if (!this.canCreate) {
			this.showToast('Error', 'Please enter a survey name', 'error');
			return;
		}

		this.isCreating = true;

		createSurvey({ surveyName: this.surveyName })
			.then((result) => {
				if (result.success) {
					this.showToast('Success', result.message, 'success');
					// Navigate to the new survey record
					this[NavigationMixin.Navigate]({
						type: 'standard__recordPage',
						attributes: {
							recordId: result.surveyId,
							objectApiName: 'Survey__c',
							actionName: 'view'
						}
					});
				} else {
					this.showToast('Error', result.message, 'error');
					this.isCreating = false;
				}
			})
			.catch((error) => {
				this.showToast('Error', error.body?.message || 'Error creating survey', 'error');
				this.isCreating = false;
			});
	}

	handleViewSurvey(event) {
		const surveyId = event.target.dataset.surveyId;
		this[NavigationMixin.Navigate]({
			type: 'standard__recordPage',
			attributes: {
				recordId: surveyId,
				objectApiName: 'Survey__c',
				actionName: 'view'
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
