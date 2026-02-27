/**
 * @description Schedulable class to run the SurveyInvitationExpirationBatch job.
 * This class can be scheduled to run automatically at specified intervals (e.g., nightly).
 *
 * Usage Examples:
 *
 * Schedule to run daily at 2 AM:
 * System.schedule('Survey Invitation Expiration - Daily', '0 0 2 * * ?', new SurveyInvitationExpirationScheduler());
 *
 * Schedule to run every hour:
 * System.schedule('Survey Invitation Expiration - Hourly', '0 0 * * * ?', new SurveyInvitationExpirationScheduler());
 *
 * For more cron expression syntax:
 * https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_scheduler.htm
 */
public with sharing class SurveyInvitationExpirationScheduler implements Schedulable {
	/**
	 * @description Execute method called by the scheduler
	 * @param sc SchedulableContext
	 */
	public void execute(SchedulableContext sc) {
		// Execute the batch job with a chosen batch size of 200 (tuned for this job, not the platform maximum)
		SurveyInvitationExpirationBatch batch = new SurveyInvitationExpirationBatch();
		Database.executeBatch(batch, 200);
	}
}