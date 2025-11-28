import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class SurveyLandingPage extends NavigationMixin(LightningElement) {
    
    handleCreateSurvey() {
        // Navigate to the survey creator page
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: 'a00XXXXXXXXXXXX', // Placeholder for new survey ID
                objectApiName: 'Survey__c',
                actionName: 'new'
            }
        });
    }

    handleManageSurveys() {
        // Navigate to the survey list page
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Survey__c',
                actionName: 'list'
            }
        });
    }

    handleViewResults() {
        // Navigate to the survey results page
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'SurveyQuestionResponse__c',
                actionName: 'list'
            }
        });
    }
}
