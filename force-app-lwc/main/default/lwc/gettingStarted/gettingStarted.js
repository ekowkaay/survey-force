import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createSurvey from '@salesforce/apex/SurveyCreationController.createSurvey';

export default class GettingStarted extends NavigationMixin(LightningElement) {
	@track sampleSurveyCreated = false;
	@track isCreatingSample = false;

	get welcomeMessage() {
		return 'Welcome to Survey Force';
	}

	get nextStepsMessage() {
		return 'Next Steps';
	}

	get instructionsMessage() {
		return 'Your next few steps are easy';
	}

	handleCreateSampleSurvey() {
		this.isCreatingSample = true;

		createSurvey({ surveyName: 'Sample Survey - ' + new Date().toLocaleString() })
			.then((result) => {
				if (result.success) {
					this.sampleSurveyCreated = true;
					this.sampleSurveyId = result.surveyId;
					this.showToast('Success', 'Sample survey created successfully!', 'success');
				} else {
					this.showToast('Error', result.message, 'error');
				}
				this.isCreatingSample = false;
			})
			.catch((error) => {
				this.showToast('Error', error.body?.message || 'Error creating sample survey', 'error');
				this.isCreatingSample = false;
			});
	}

	handleViewSampleSurvey() {
		if (this.sampleSurveyId) {
			this[NavigationMixin.Navigate]({
				type: 'standard__recordPage',
				attributes: {
					recordId: this.sampleSurveyId,
					objectApiName: 'Survey__c',
					actionName: 'view'
				}
			});
		}
	}

	handleNavigateToCreateSurvey() {
		this[NavigationMixin.Navigate]({
			type: 'standard__objectPage',
			attributes: {
				objectApiName: 'Survey__c',
				actionName: 'new'
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
