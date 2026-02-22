/**
 * @description Batch class to automatically expire survey invitations that have passed their expiration date.
 * This batch job queries all SurveyInvitation__c records with Status__c = 'Pending' and
 * ExpirationDate__c < NOW, then updates their status to 'Expired'.
 *
 * Schedule this to run nightly to ensure expired invitations are properly marked.
 *
 * Example scheduling (run daily at 2 AM):
 * System.schedule('Survey Invitation Expiration', '0 0 2 * * ?', new SurveyInvitationExpirationScheduler());
 */
public with sharing class SurveyInvitationExpirationBatch implements Database.Batchable<SObject>, Database.Stateful {
	// Track counts across batches for logging in finish method
	private Integer processedCount = 0;
	private Integer expiredCount = 0;

	/**
	 * @description Start method - queries all pending invitations that have expired
	 * @param bc BatchableContext
	 * @return Database.QueryLocator Query locator for expired invitations
	 */
	public Database.QueryLocator start(Database.BatchableContext bc) {
		DateTime now = DateTime.now();
		return Database.getQueryLocator(
			[
				SELECT Id, Status__c, ExpirationDate__c
				FROM SurveyInvitation__c
				WHERE Status__c = :SurveyForceConstants.STATUS_PENDING AND ExpirationDate__c != NULL AND ExpirationDate__c < :now
				WITH USER_MODE
			]
		);
	}

	/**
	 * @description Execute method - updates invitations to Expired status
	 * @param bc BatchableContext
	 * @param scope List of invitations to process in this batch
	 */
	public void execute(Database.BatchableContext bc, List<SObject> scope) {
		List<SurveyInvitation__c> invitationsToUpdate = new List<SurveyInvitation__c>();

		for (SObject obj : scope) {
			SurveyInvitation__c invitation = (SurveyInvitation__c) obj;
			invitation.Status__c = SurveyForceConstants.STATUS_EXPIRED;
			invitationsToUpdate.add(invitation);
			processedCount++;
		}

		if (!invitationsToUpdate.isEmpty()) {
			try {
				Database.SaveResult[] results = Database.update(invitationsToUpdate, AccessLevel.USER_MODE);

				// Count successful updates
				for (Database.SaveResult result : results) {
					if (result.isSuccess()) {
						expiredCount++;
					} else {
						// Log errors
						for (Database.Error error : result.getErrors()) {
							SurveyForceUtil.log('SurveyInvitationExpirationBatch:execute() - Error updating invitation: ' + error.getMessage());
						}
					}
				}
			} catch (Exception e) {
				SurveyForceUtil.log('SurveyInvitationExpirationBatch:execute() - Exception: ' + e.getMessage());
			}
		}
	}

	/**
	 * @description Finish method - logs completion status
	 * @param bc BatchableContext
	 */
	public void finish(Database.BatchableContext bc) {
		String message = 'Survey Invitation Expiration Batch completed. Processed: ' + processedCount + ', Successfully Expired: ' + expiredCount;
		SurveyForceUtil.log('SurveyInvitationExpirationBatch:finish() - ' + message);
	}
}