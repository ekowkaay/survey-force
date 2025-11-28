import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SurveyShareLwc extends LightningElement {
    // Properties
    @track isLoading = true;
    @track error = null;
    
    // Sharing options
    @track selectedURLType = 'Chatter';
    @track surveySite = '';
    
    // URLs
    @track surveyURLBase = 'https://example.com/';
    @track surveyURL = 'survey/12345';
    
    // Picklists
    @track urlTypeOptions = [
        { label: 'Chatter', value: 'Chatter' },
        { label: 'Site', value: 'Site' }
    ];
    
    @track sitesPicklist = [
        { label: 'Public Site 1', value: 'site1' },
        { label: 'Public Site 2', value: 'site2' }
    ];

    connectedCallback() {
        // Simulate loading data
        setTimeout(() => {
            this.isLoading = false;
        }, 1000);
    }

    // Computed properties
    get fullSurveyUrl() {
        return this.surveyURLBase + this.surveyURL;
    }

    get fullPreviewUrl() {
        return this.surveyURLBase + this.surveyURL + '&preview=true';
    }

    get showChatterOption() {
        return this.selectedURLType === 'Chatter';
    }

    // Event handlers
    handleURLTypeChange(event) {
        this.selectedURLType = event.detail.value;
    }

    handleSiteChange(event) {
        this.surveySite = event.detail.value;
    }

    handleOpenSurvey() {
        window.open(this.fullSurveyUrl, '_blank');
    }
}
