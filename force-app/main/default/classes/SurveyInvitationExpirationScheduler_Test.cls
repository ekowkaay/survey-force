/**
 * @description Test class for SurveyInvitationExpirationScheduler
 */
@IsTest
private class SurveyInvitationExpirationScheduler_Test {
	@TestSetup
	static void makeData() {
		User u = SurveyTestingUtil.createNewAdminPermissionSetUser();
	}

	/**
	 * @description Test scheduler executes batch job
	 */
	@IsTest
	private static void testSchedulerExecutesBatch() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create expired invitation
			SurveyInvitation__c invitation = new SurveyInvitation__c();
			invitation.Survey__c = tu.surveyId;
			invitation.Token__c = TokenGeneratorService.generateToken();
			invitation.Status__c = SurveyForceConstants.STATUS_PENDING;
			invitation.ExpirationDate__c = DateTime.now().addDays(-1);
			insert invitation;

			// Verify it's pending
			SurveyInvitation__c beforeInvitation = [
				SELECT Id, Status__c
				FROM SurveyInvitation__c
				WHERE Id = :invitation.Id
			];
			System.assertEquals(SurveyForceConstants.STATUS_PENDING, beforeInvitation.Status__c, 'Should be pending initially');

			Test.startTest();
			// Schedule the job
			String cronExp = '0 0 2 * * ?'; // Daily at 2 AM
			String jobId = System.schedule('Test Survey Invitation Expiration', cronExp, new SurveyInvitationExpirationScheduler());
			Test.stopTest();

			// Verify the scheduled job exists
			System.assertNotEquals(null, jobId, 'Job should be scheduled');

			// Verify the invitation is now expired (batch ran)
			SurveyInvitation__c afterInvitation = [
				SELECT Id, Status__c
				FROM SurveyInvitation__c
				WHERE Id = :invitation.Id
			];
			System.assertEquals(SurveyForceConstants.STATUS_EXPIRED, afterInvitation.Status__c, 'Should be expired after scheduled job runs');
		}
	}

	/**
	 * @description Test multiple scheduler executions
	 */
	@IsTest
	private static void testMultipleSchedulerExecutions() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create expired invitations
			List<SurveyInvitation__c> invitations = new List<SurveyInvitation__c>();
			for (Integer i = 0; i < 10; i++) {
				SurveyInvitation__c invitation = new SurveyInvitation__c();
				invitation.Survey__c = tu.surveyId;
				invitation.Token__c = TokenGeneratorService.generateToken();
				invitation.Status__c = SurveyForceConstants.STATUS_PENDING;
				invitation.ExpirationDate__c = DateTime.now().addDays(-i - 1);
				invitations.add(invitation);
			}
			insert invitations;

			Test.startTest();
			// Execute scheduler manually (simulates scheduled execution)
			SurveyInvitationExpirationScheduler scheduler = new SurveyInvitationExpirationScheduler();
			scheduler.execute(null);
			Test.stopTest();

			// Verify all invitations are expired
			Integer expiredCount = [
				SELECT COUNT()
				FROM SurveyInvitation__c
				WHERE Status__c = :SurveyForceConstants.STATUS_EXPIRED AND Survey__c = :tu.surveyId
			];
			System.assertEquals(10, expiredCount, 'All 10 invitations should be expired');
		}
	}

	/**
	 * @description Test scheduler with empty dataset
	 */
	@IsTest
	private static void testSchedulerWithNoExpiredInvitations() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create only valid invitations
			SurveyInvitationController.createInvitation(tu.surveyId, null, null, null, null, null, null);

			Test.startTest();
			// Execute scheduler
			SurveyInvitationExpirationScheduler scheduler = new SurveyInvitationExpirationScheduler();
			scheduler.execute(null);
			Test.stopTest();

			// Verify no invitations are expired
			Integer expiredCount = [
				SELECT COUNT()
				FROM SurveyInvitation__c
				WHERE Status__c = :SurveyForceConstants.STATUS_EXPIRED
			];
			System.assertEquals(0, expiredCount, 'No invitations should be expired');
		}
	}

	/**
	 * @description Test scheduler can be scheduled with different cron expressions
	 */
	@IsTest
	private static void testDifferentScheduleExpressions() {
		Test.startTest();
		// Test daily schedule
		String jobId1 = System.schedule('Test Daily Expiration', '0 0 2 * * ?', new SurveyInvitationExpirationScheduler());
		System.assertNotEquals(null, jobId1, 'Daily job should be scheduled');

		// Test hourly schedule
		String jobId2 = System.schedule('Test Hourly Expiration', '0 0 * * * ?', new SurveyInvitationExpirationScheduler());
		System.assertNotEquals(null, jobId2, 'Hourly job should be scheduled');
		Test.stopTest();

		// Clean up
		System.abortJob(jobId1);
		System.abortJob(jobId2);
	}
}
