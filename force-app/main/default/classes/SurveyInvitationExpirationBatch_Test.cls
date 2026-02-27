/**
 * @description Test class for SurveyInvitationExpirationBatch
 */
@IsTest
private class SurveyInvitationExpirationBatch_Test {
	@TestSetup
	static void makeData() {
		User u = SurveyTestingUtil.createNewAdminPermissionSetUser();
	}

	/**
	 * @description Test batch expiration of invitations
	 */
	@IsTest
	private static void testBatchExpiresInvitations() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create 5 invitations with past expiration dates
			List<SurveyInvitation__c> expiredInvitations = new List<SurveyInvitation__c>();
			for (Integer i = 0; i < 5; i++) {
				SurveyInvitation__c invitation = new SurveyInvitation__c();
				invitation.Survey__c = tu.surveyId;
				invitation.Token__c = TokenGeneratorService.generateToken();
				invitation.Status__c = SurveyForceConstants.STATUS_PENDING;
				invitation.ExpirationDate__c = DateTime.now().addDays(-1); // Expired yesterday
				expiredInvitations.add(invitation);
			}
			insert expiredInvitations;

			// Create 3 invitations with future expiration dates
			List<SurveyInvitation__c> validInvitations = new List<SurveyInvitation__c>();
			for (Integer i = 0; i < 3; i++) {
				SurveyInvitation__c invitation = new SurveyInvitation__c();
				invitation.Survey__c = tu.surveyId;
				invitation.Token__c = TokenGeneratorService.generateToken();
				invitation.Status__c = SurveyForceConstants.STATUS_PENDING;
				invitation.ExpirationDate__c = DateTime.now().addDays(7); // Valid for 7 more days
				validInvitations.add(invitation);
			}
			insert validInvitations;

			// Verify initial state
			Integer initialPendingCount = [
				SELECT COUNT()
				FROM SurveyInvitation__c
				WHERE Status__c = :SurveyForceConstants.STATUS_PENDING
			];
			System.assertEquals(8, initialPendingCount, 'Should have 8 pending invitations initially');

			Test.startTest();
			// Execute batch job
			SurveyInvitationExpirationBatch batch = new SurveyInvitationExpirationBatch();
			Database.executeBatch(batch);
			Test.stopTest();

			// Verify results - 5 should be expired, 3 should remain pending
			Integer expiredCount = [
				SELECT COUNT()
				FROM SurveyInvitation__c
				WHERE Status__c = :SurveyForceConstants.STATUS_EXPIRED
			];
			System.assertEquals(5, expiredCount, 'Should have 5 expired invitations after batch');

			Integer pendingCount = [
				SELECT COUNT()
				FROM SurveyInvitation__c
				WHERE Status__c = :SurveyForceConstants.STATUS_PENDING
			];
			System.assertEquals(3, pendingCount, 'Should have 3 pending invitations after batch');
		}
	}

	/**
	 * @description Test batch does not expire invitations without expiration dates
	 */
	@IsTest
	private static void testBatchIgnoresNullExpirationDates() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create custom setting with 0 day expiration (no expiration)
			SurveySettings__c settings = new SurveySettings__c();
			settings.InvitationExpirationDays__c = 0;
			insert settings;

			// Create invitations with null expiration dates
			SurveyInvitationController.InvitationResult result1 = SurveyInvitationController.createInvitation(tu.surveyId, null, null, null, null, null, null);
			SurveyInvitationController.InvitationResult result2 = SurveyInvitationController.createInvitation(tu.surveyId, null, null, null, null, null, null);

			// Verify invitations have null expiration dates
			List<SurveyInvitation__c> invitations = [
				SELECT Id, ExpirationDate__c, Status__c
				FROM SurveyInvitation__c
				WHERE Id IN (:result1.invitationId, :result2.invitationId)
			];
			for (SurveyInvitation__c inv : invitations) {
				System.assertEquals(null, inv.ExpirationDate__c, 'Expiration date should be null');
				System.assertEquals(SurveyForceConstants.STATUS_PENDING, inv.Status__c, 'Status should be pending');
			}

			Test.startTest();
			// Execute batch job
			SurveyInvitationExpirationBatch batch = new SurveyInvitationExpirationBatch();
			Database.executeBatch(batch);
			Test.stopTest();

			// Verify invitations are still pending (not expired)
			invitations = [
				SELECT Id, Status__c
				FROM SurveyInvitation__c
				WHERE Id IN (:result1.invitationId, :result2.invitationId)
			];
			for (SurveyInvitation__c inv : invitations) {
				System.assertEquals(SurveyForceConstants.STATUS_PENDING, inv.Status__c, 'Should remain pending when no expiration date');
			}
		}
	}

	/**
	 * @description Test batch does not expire completed invitations
	 */
	@IsTest
	private static void testBatchIgnoresCompletedInvitations() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create invitation with past expiration but completed status
			SurveyInvitation__c invitation = new SurveyInvitation__c();
			invitation.Survey__c = tu.surveyId;
			invitation.Token__c = TokenGeneratorService.generateToken();
			invitation.Status__c = SurveyForceConstants.STATUS_COMPLETED;
			invitation.ExpirationDate__c = DateTime.now().addDays(-5); // Expired 5 days ago
			invitation.CompletedDate__c = DateTime.now().addDays(-10); // Completed 10 days ago
			insert invitation;

			Test.startTest();
			// Execute batch job
			SurveyInvitationExpirationBatch batch = new SurveyInvitationExpirationBatch();
			Database.executeBatch(batch);
			Test.stopTest();

			// Verify invitation remains completed
			SurveyInvitation__c updatedInvitation = [
				SELECT Id, Status__c
				FROM SurveyInvitation__c
				WHERE Id = :invitation.Id
			];
			System.assertEquals(SurveyForceConstants.STATUS_COMPLETED, updatedInvitation.Status__c, 'Completed status should not change');
		}
	}

	/**
	 * @description Test batch handles large number of invitations
	 */
	@IsTest
	private static void testBatchHandlesLargeDataset() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create 250 expired invitations
			List<SurveyInvitation__c> expiredInvitations = new List<SurveyInvitation__c>();
			for (Integer i = 0; i < 250; i++) {
				SurveyInvitation__c invitation = new SurveyInvitation__c();
				invitation.Survey__c = tu.surveyId;
				invitation.Token__c = TokenGeneratorService.generateToken();
				invitation.Status__c = SurveyForceConstants.STATUS_PENDING;
				invitation.ExpirationDate__c = DateTime.now().addDays(-1);
				expiredInvitations.add(invitation);
			}
			insert expiredInvitations;

			Test.startTest();
			// Execute batch job
			SurveyInvitationExpirationBatch batch = new SurveyInvitationExpirationBatch();
			Database.executeBatch(batch, 200); // Process 200 at a time
			Test.stopTest();

			// Verify all are expired
			Integer expiredCount = [
				SELECT COUNT()
				FROM SurveyInvitation__c
				WHERE Status__c = :SurveyForceConstants.STATUS_EXPIRED
			];
			System.assertEquals(250, expiredCount, 'All 250 invitations should be expired');
		}
	}

	/**
	 * @description Test batch with no expired invitations
	 */
	@IsTest
	private static void testBatchWithNoExpiredInvitations() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create only valid invitations
			SurveyInvitationController.createInvitation(tu.surveyId, null, null, null, null, null, null);
			SurveyInvitationController.createInvitation(tu.surveyId, null, null, null, null, null, null);

			// Manually set future expiration dates
			List<SurveyInvitation__c> invitations = [
				SELECT Id, ExpirationDate__c
				FROM SurveyInvitation__c
				WHERE Survey__c = :tu.surveyId
			];
			for (SurveyInvitation__c inv : invitations) {
				inv.ExpirationDate__c = DateTime.now().addDays(30);
			}
			update invitations;

			Test.startTest();
			// Execute batch job
			SurveyInvitationExpirationBatch batch = new SurveyInvitationExpirationBatch();
			Database.executeBatch(batch);
			Test.stopTest();

			// Verify none are expired
			Integer expiredCount = [
				SELECT COUNT()
				FROM SurveyInvitation__c
				WHERE Status__c = :SurveyForceConstants.STATUS_EXPIRED
			];
			System.assertEquals(0, expiredCount, 'No invitations should be expired');

			Integer pendingCount = [
				SELECT COUNT()
				FROM SurveyInvitation__c
				WHERE Status__c = :SurveyForceConstants.STATUS_PENDING
			];
			System.assertEquals(2, pendingCount, 'Both invitations should remain pending');
		}
	}
}
