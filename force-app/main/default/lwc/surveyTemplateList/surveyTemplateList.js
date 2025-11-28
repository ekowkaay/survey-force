import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRecentSurveys from '@salesforce/apex/SurveyCreationController.getRecentSurveys';
import createSurvey from '@salesforce/apex/SurveyCreationController.createSurvey';
import cloneSurvey from '@salesforce/apex/SurveyCreationController.cloneSurvey';
import getAllSurveys from '@salesforce/apex/SurveyTemplateController.getAllSurveys';
import deleteSurvey from '@salesforce/apex/SurveyTemplateController.deleteSurvey';

const COLUMNS = [
	{
		label: 'Survey Name',
		fieldName: 'nameUrl',
		type: 'url',
		typeAttributes: { label: { fieldName: 'Name' }, target: '_self' },
		sortable: true
	},
	{ label: 'Questions', fieldName: 'Questions__c', type: 'number', sortable: true },
	{ label: 'Responses', fieldName: 'Completed_Surveys__c', type: 'number', sortable: true },
	{ label: 'Public', fieldName: 'Share_with_Guest_User__c', type: 'boolean' },
	{ label: 'Created Date', fieldName: 'CreatedDate', type: 'date', sortable: true },
	{
		type: 'action',
		typeAttributes: {
			rowActions: [
				{ label: 'Edit', name: 'edit' },
				{ label: 'Clone', name: 'clone' },
				{ label: 'Preview', name: 'preview' },
				{ label: 'Delete', name: 'delete' }
			]
		}
	}
];

export default class SurveyTemplateList extends NavigationMixin(LightningElement) {
	@track surveys = [];
	@track isLoading = true;
	@track error = null;
	@track columns = COLUMNS;

	// Sorting
	@track sortedBy = 'CreatedDate';
	@track sortedDirection = 'desc';

	// Create Modal
	@track showCreateModal = false;
	@track newSurveyName = '';
	@track isCreating = false;

	// Clone Modal
	@track showCloneModal = false;
	@track cloneSurveyName = '';
	@track cloneSourceId = null;
	@track isCloning = false;

	get hasSurveys() {
		return this.surveys && this.surveys.length > 0;
	}

	get totalSurveys() {
		return this.surveys ? this.surveys.length : 0;
	}

	get totalResponses() {
		if (!this.surveys) return 0;
		return this.surveys.reduce((sum, survey) => sum + (survey.Completed_Surveys__c || 0), 0);
	}

	connectedCallback() {
		this.loadSurveys();
	}

	loadSurveys() {
		this.isLoading = true;
		this.error = null;

		getAllSurveys()
			.then((result) => {
				this.surveys = result.map((survey) => ({
					...survey,
					nameUrl: '/' + survey.Id
				}));
				this.isLoading = false;
			})
			.catch((error) => {
				this.error = error.body?.message || 'Error loading surveys';
				this.isLoading = false;
			});
	}

	handleRefresh() {
		this.loadSurveys();
	}

	// Sorting
	handleSort(event) {
		const { fieldName, sortDirection } = event.detail;
		this.sortedBy = fieldName;
		this.sortedDirection = sortDirection;

		const cloneData = [...this.surveys];
		cloneData.sort(this.sortBy(fieldName, sortDirection === 'asc' ? 1 : -1));
		this.surveys = cloneData;
	}

	sortBy(field, reverse) {
		const key = (x) => x[field];
		return (a, b) => {
			let aVal = key(a);
			let bVal = key(b);
			if (aVal === undefined || aVal === null) aVal = '';
			if (bVal === undefined || bVal === null) bVal = '';
			return reverse * ((aVal > bVal) - (bVal > aVal));
		};
	}

	// Row Actions
	handleRowAction(event) {
		const action = event.detail.action;
		const row = event.detail.row;

		switch (action.name) {
			case 'edit':
				this.navigateToBuilder(row.Id);
				break;
			case 'clone':
				this.openCloneModal(row);
				break;
			case 'preview':
				this.navigateToPreview(row.Id);
				break;
			case 'delete':
				this.handleDeleteSurvey(row.Id);
				break;
			default:
				break;
		}
	}

	navigateToBuilder(surveyId) {
		this[NavigationMixin.Navigate]({
			type: 'standard__recordPage',
			attributes: {
				recordId: surveyId,
				objectApiName: 'Survey__c',
				actionName: 'view'
			}
		});
	}

	navigateToPreview(surveyId) {
		this[NavigationMixin.Navigate]({
			type: 'standard__navItemPage',
			attributes: {
				apiName: 'Survey_Taker_Page'
			},
			state: {
				c__recordId: surveyId
			}
		});
	}

	handleDeleteSurvey(surveyId) {
		if (confirm('Are you sure you want to delete this survey? This will also delete all questions and responses.')) {
			this.isLoading = true;
			deleteSurvey({ surveyId: surveyId })
				.then(() => {
					this.showToast('Success', 'Survey deleted successfully', 'success');
					this.loadSurveys();
				})
				.catch((error) => {
					this.showToast('Error', error.body?.message || 'Error deleting survey', 'error');
					this.isLoading = false;
				});
		}
	}

	// Create Modal
	handleOpenCreateModal() {
		this.newSurveyName = '';
		this.showCreateModal = true;
	}

	handleCloseCreateModal() {
		this.showCreateModal = false;
	}

	handleNewSurveyNameChange(event) {
		this.newSurveyName = event.target.value;
	}

	handleCreateSurvey() {
		if (!this.newSurveyName || this.newSurveyName.trim() === '') {
			this.showToast('Error', 'Please enter a survey name', 'error');
			return;
		}

		this.isCreating = true;

		createSurvey({ surveyName: this.newSurveyName })
			.then((result) => {
				if (result.success) {
					this.showToast('Success', 'Survey created successfully', 'success');
					this.showCreateModal = false;
					this.navigateToBuilder(result.surveyId);
				} else {
					this.showToast('Error', result.message, 'error');
				}
				this.isCreating = false;
			})
			.catch((error) => {
				this.showToast('Error', error.body?.message || 'Error creating survey', 'error');
				this.isCreating = false;
			});
	}

	// Clone Modal
	openCloneModal(survey) {
		this.cloneSourceId = survey.Id;
		this.cloneSurveyName = 'Copy of ' + survey.Name;
		this.showCloneModal = true;
	}

	handleCloseCloneModal() {
		this.showCloneModal = false;
	}

	handleCloneSurveyNameChange(event) {
		this.cloneSurveyName = event.target.value;
	}

	handleCloneSurvey() {
		if (!this.cloneSurveyName || this.cloneSurveyName.trim() === '') {
			this.showToast('Error', 'Please enter a name for the cloned survey', 'error');
			return;
		}

		this.isCloning = true;

		cloneSurvey({ sourceSurveyId: this.cloneSourceId, newSurveyName: this.cloneSurveyName })
			.then((result) => {
				if (result.success) {
					this.showToast('Success', 'Survey cloned successfully', 'success');
					this.showCloneModal = false;
					this.navigateToBuilder(result.surveyId);
				} else {
					this.showToast('Error', result.message, 'error');
				}
				this.isCloning = false;
			})
			.catch((error) => {
				this.showToast('Error', error.body?.message || 'Error cloning survey', 'error');
				this.isCloning = false;
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
