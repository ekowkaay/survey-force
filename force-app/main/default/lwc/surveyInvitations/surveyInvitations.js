import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
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
	@track selectedSurveyId = null;

	// Store wired result for refreshApex
	wiredInvitationsResult;

	// Generate modal
	@track showGenerateModal = false;
	@track linkCount = 10;
	@track isGenerating = false;
	@track showSurveyRequiredMessage = false;

	// Links modal
	@track showLinksModal = false;
	@track generatedLinks = [];

	/**
	 * Returns the survey ID to use for operations.
	 * Priority: recordId (from record page) > selectedSurveyId (from user selection)
	 * @returns {String} Survey ID or null
	 */
	get effectiveSurveyId() {
		return this.recordId || this.selectedSurveyId;
	}

	/**
	 * Determines if the survey selector should be displayed.
	 * True when component is on standalone tab (no recordId), false on record pages
	 * @returns {Boolean}
	 */
	get showSurveySelector() {
		return !this.recordId;
	}

	get showContent() {
		return !this.isLoading && !this.error && this.effectiveSurveyId;
	}

	get showSelectSurveyPrompt() {
		return !this.isLoading && !this.error && !this.effectiveSurveyId && this.showSurveySelector;
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

	/**
	 * Determines if the Generate button should be disabled.
	 * Button is disabled when generation is in progress or no survey is selected
	 * @returns {Boolean} True if button should be disabled
	 */
	get isGenerateDisabled() {
		return this.isGenerating || !this.effectiveSurveyId;
	}

	/**
	 * Lifecycle hook called when component is inserted into DOM.
	 * Auto-opens the generate modal when accessed from a standalone tab without a survey.
	 * This provides immediate workflow access for users coming from the Survey Link Generator tab.
	 * Invitation loading for record pages is handled by the wired getInvitationsForSurvey adapter
	 * based on the current effectiveSurveyId.
	 */
	connectedCallback() {
		// Auto-open generate modal when on standalone tab without a survey
		if (!this.recordId && !this.selectedSurveyId) {
			this.isLoading = false;
			this.showGenerateModal = true;
		}
	}

	/**
	 * Wire adapter to fetch invitations for the current survey.
	 * Only fires when effectiveSurveyId is truthy to avoid unnecessary server calls.
	 * Results are cached by Salesforce and can be refreshed using refreshApex
	 * @param {Object} result - Wire adapter result containing data or error
	 */
	@wire(getInvitationsForSurvey, { surveyId: '$effectiveSurveyId' })
	wiredInvitations(result) {
		this.wiredInvitationsResult = result;

		// Skip processing if no survey is selected
		if (!this.effectiveSurveyId) {
			this.isLoading = false;
			this.invitations = [];
			this.error = null;
			return;
		}

		if (result.data) {
			this.invitations = result.data.map((inv) => ({
				...inv,
				statusClass: this.getStatusClass(inv.status)
			}));
			this.isLoading = false;
			this.error = null;
		} else if (result.error) {
			this.error = result.error.body?.message || 'Error loading invitations';
			this.isLoading = false;
			this.invitations = [];
		}
	}

	/**
	 * Handles survey selection from the lightning-record-picker.
	 * Clears validation errors. Wire adapter will automatically load invitations for the selected survey
	 * @param {Event} event - Change event from lightning-record-picker
	 */
	handleSurveyChange(event) {
		this.selectedSurveyId = event.detail.recordId;
		this.showSurveyRequiredMessage = false;
		if (this.selectedSurveyId) {
			this.isLoading = true; // Show loading while wire fetches data
		} else {
			// Survey was deselected, clear loading state immediately
			this.isLoading = false;
		}
	}

	/**
	 * Refreshes the invitations list from the server.
	 * Uses refreshApex to bypass cache and fetch fresh data
	 * Called when the refresh button is clicked
	 */
	handleRefresh() {
		this.isLoading = true;
		return refreshApex(this.wiredInvitationsResult);
	}

	/**
	 * Returns the CSS class for invitation status styling
	 * @param {String} status - Invitation status (Pending, Completed, Expired)
	 * @returns {String} SLDS color class
	 */
	getStatusClass(status) {
		if (status === 'Completed') {
			return 'slds-text-color_success';
		} else if (status === 'Expired') {
			return 'slds-text-color_error';
		}
		return '';
	}

	// Generate Modal
	/**
	 * Opens the generate links modal and resets state.
	 * Resets link count to default of 10 and clears any validation errors
	 */
	handleOpenGenerateModal() {
		this.linkCount = 10;
		this.showSurveyRequiredMessage = false;
		this.showGenerateModal = true;
	}

	/**
	 * Closes the generate links modal and resets validation state
	 */
	handleCloseGenerateModal() {
		this.showGenerateModal = false;
		this.showSurveyRequiredMessage = false;
	}

	/**
	 * Handles changes to the link count input field
	 * @param {Event} event - Input change event
	 */
	handleLinkCountChange(event) {
		this.linkCount = parseInt(event.target.value, 10);
	}

	/**
	 * Generates bulk survey invitation links.
	 * Validates survey selection and link count before calling Apex.
	 * Multi-layer validation:
	 * 1. Checks for survey selection (shows warning message + toast)
	 * 2. Validates link count is between 1-200
	 * 3. Calls Apex to create invitations
	 * 4. Displays generated links in modal on success
	 */
	handleGenerateLinks() {
		if (!this.effectiveSurveyId) {
			this.showSurveyRequiredMessage = true;
			this.showToast('Error', 'Please select a survey first', 'error');
			return;
		}

		if (!this.linkCount || this.linkCount < 1 || this.linkCount > 200) {
			this.showToast('Error', 'Please enter a valid number between 1 and 200', 'error');
			return;
		}

		this.isGenerating = true;
		this.showSurveyRequiredMessage = false;

		createBulkInvitations({ surveyId: this.effectiveSurveyId, count: this.linkCount })
			.then((result) => {
				if (result.success) {
					this.generatedLinks = result.invitations;
					this.showGenerateModal = false;
					this.showLinksModal = true;
					// Refresh to show new invitations
					refreshApex(this.wiredInvitationsResult).catch((error) => {
						this.showToast('Warning', 'Invitations were created but the list could not be refreshed. Please refresh the page.', 'warning');
						// eslint-disable-next-line no-console
						console.error('Error refreshing invitations', error);
					});
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
