import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInvitationsForSurvey from '@salesforce/apex/SurveyInvitationController.getInvitationsForSurvey';
import createBulkInvitations from '@salesforce/apex/SurveyInvitationController.createBulkInvitations';

const COLUMNS = [
	{ label: 'Invitation #', fieldName: 'name', type: 'text', sortable: true },
	{ label: 'Participant', fieldName: 'participantName', type: 'text' },
	{ label: 'Email', fieldName: 'email', type: 'email' },
	{
		label: 'Status',
		fieldName: 'status',
		type: 'text',
		cellAttributes: {
			class: { fieldName: 'statusClass' }
		}
	},
	{ label: 'Created', fieldName: 'createdDate', type: 'date' },
	{ label: 'Expires', fieldName: 'expirationDate', type: 'date' },
	{ label: 'Completed', fieldName: 'completedDate', type: 'date' },
	{
		type: 'action',
		typeAttributes: {
			rowActions: [{ label: 'Copy Link', name: 'copy' }]
		}
	}
];

export default class SurveyInvitations extends LightningElement {
	@api recordId;

	@track isLoading = true;
	@track error = null;
	@track invitations = [];
	@track columns = COLUMNS;

	// Generate modal
	@track showGenerateModal = false;
	@track linkCount = 10;
	@track isGenerating = false;

	// Links modal
	@track showLinksModal = false;
	@track generatedLinks = [];

	get showContent() {
		return !this.isLoading && !this.error;
	}

	get hasInvitations() {
		return this.invitations && this.invitations.length > 0;
	}

	get totalInvitations() {
		return this.invitations ? this.invitations.length : 0;
	}

	get pendingCount() {
		return this.invitations ? this.invitations.filter((inv) => inv.status === 'Pending').length : 0;
	}

	get completedCount() {
		return this.invitations ? this.invitations.filter((inv) => inv.status === 'Completed').length : 0;
	}

	get generatedCount() {
		return this.generatedLinks ? this.generatedLinks.length : 0;
	}

	connectedCallback() {
		this.loadInvitations();
	}

	loadInvitations() {
		this.isLoading = true;
		this.error = null;

		getInvitationsForSurvey({ surveyId: this.recordId })
			.then((result) => {
				this.invitations = result.map((inv) => ({
					...inv,
					statusClass: this.getStatusClass(inv.status)
				}));
				this.isLoading = false;
			})
			.catch((err) => {
				this.error = err.body?.message || 'Error loading invitations';
				this.isLoading = false;
			});
	}

	getStatusClass(status) {
		if (status === 'Completed') {
			return 'slds-text-color_success';
		} else if (status === 'Expired') {
			return 'slds-text-color_error';
		}
		return '';
	}

	handleRefresh() {
		this.loadInvitations();
	}

	// Generate Modal
	handleOpenGenerateModal() {
		this.linkCount = 10;
		this.showGenerateModal = true;
	}

	handleCloseGenerateModal() {
		this.showGenerateModal = false;
	}

	handleLinkCountChange(event) {
		this.linkCount = parseInt(event.target.value, 10);
	}

	handleGenerateLinks() {
		if (!this.linkCount || this.linkCount < 1 || this.linkCount > 200) {
			this.showToast('Error', 'Please enter a valid number between 1 and 200', 'error');
			return;
		}

		this.isGenerating = true;

		createBulkInvitations({ surveyId: this.recordId, count: this.linkCount })
			.then((result) => {
				if (result.success) {
					this.generatedLinks = result.invitations;
					this.showGenerateModal = false;
					this.showLinksModal = true;
					this.loadInvitations();
					this.showToast('Success', result.message, 'success');
				} else {
					this.showToast('Error', result.message, 'error');
				}
				this.isGenerating = false;
			})
			.catch((err) => {
				this.showToast('Error', err.body?.message || 'Error generating links', 'error');
				this.isGenerating = false;
			});
	}

	// Links Modal
	handleCloseLinksModal() {
		this.showLinksModal = false;
		this.generatedLinks = [];
	}

	handleCopyLink(event) {
		const url = event.currentTarget.dataset.url;
		this.copyToClipboard(url);
		this.showToast('Success', 'Link copied to clipboard', 'success');
	}

	handleCopyAllLinks() {
		const allLinks = this.generatedLinks.map((link) => link.surveyUrl).join('\n');
		this.copyToClipboard(allLinks, true);
	}

	copyToClipboard(text, showSuccessToast = false) {
		if (navigator.clipboard && navigator.clipboard.writeText) {
			navigator.clipboard
				.writeText(text)
				.then(() => {
					if (showSuccessToast) {
						this.showToast('Success', 'All links copied to clipboard', 'success');
					}
				})
				.catch(() => {
					this.showToast('Error', 'Failed to copy to clipboard. Please copy manually.', 'error');
				});
		} else {
			// Fallback for browsers that don't support clipboard API
			this.showToast('Error', 'Clipboard not supported in this browser', 'error');
		}
	}

	// Row Actions
	handleRowAction(event) {
		const action = event.detail.action;
		const row = event.detail.row;

		if (action.name === 'copy') {
			this.copyToClipboard(row.surveyUrl);
			this.showToast('Success', 'Link copied to clipboard', 'success');
		}
	}

	showToast(title, message, variant) {
		const event = new ShowToastEvent({
			title,
			message,
			variant
		});
		this.dispatchEvent(event);
	}
}
