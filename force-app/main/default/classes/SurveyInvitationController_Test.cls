/**
 * @description Test class for SurveyInvitationController
 */
@IsTest
private class SurveyInvitationController_Test {
	@TestSetup
	static void makeData() {
		User u = SurveyTestingUtil.createNewAdminPermissionSetUser();
	}

	@IsTest
	private static void testCreateInvitation() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Test.startTest();
			SurveyInvitationController.InvitationResult result = SurveyInvitationController.createInvitation(tu.surveyId, 'test@example.com', 'Test Participant', null);
			Test.stopTest();

			System.assertEquals(true, result.success, 'Invitation should be created successfully');
			System.assertNotEquals(null, result.invitationId, 'Invitation ID should not be null');
			System.assertNotEquals(null, result.token, 'Token should not be null');
			System.assert(result.surveyUrl.contains(result.token), 'Survey URL should contain token');

			// Verify invitation record
			SurveyInvitation__c invitation = [SELECT Id, Token__c, Status__c, Email__c, ParticipantName__c FROM SurveyInvitation__c WHERE Id = :result.invitationId];
			System.assertEquals('Pending', invitation.Status__c, 'Status should be Pending');
			System.assertEquals('test@example.com', invitation.Email__c, 'Email should match');
			System.assertEquals('Test Participant', invitation.ParticipantName__c, 'Name should match');
		}
	}

	@IsTest
	private static void testCreateInvitationWithNullSurveyId() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			Test.startTest();
			SurveyInvitationController.InvitationResult result = SurveyInvitationController.createInvitation(null, null, null, null);
			Test.stopTest();

			System.assertEquals(false, result.success, 'Should fail with null survey ID');
			System.assert(result.message.contains('Survey ID is required'), 'Message should indicate survey ID required');
		}
	}

	@IsTest
	private static void testCreateBulkInvitations() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Test.startTest();
			SurveyInvitationController.BulkInvitationResult result = SurveyInvitationController.createBulkInvitations(tu.surveyId, 5);
			Test.stopTest();

			System.assertEquals(true, result.success, 'Bulk creation should succeed');
			System.assertEquals(5, result.totalGenerated, 'Should generate 5 invitations');
			System.assertEquals(5, result.invitations.size(), 'Should return 5 invitation records');

			// Verify all have unique tokens
			Set<String> tokens = new Set<String>();
			for (SurveyInvitationController.InvitationData inv : result.invitations) {
				System.assertNotEquals(null, inv.token, 'Token should not be null');
				System.assertEquals(false, tokens.contains(inv.token), 'Tokens should be unique');
				tokens.add(inv.token);
			}
		}
	}

	@IsTest
	private static void testCreateBulkInvitationsValidation() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Test.startTest();
			// Test with invalid count
			SurveyInvitationController.BulkInvitationResult result1 = SurveyInvitationController.createBulkInvitations(tu.surveyId, 0);
			System.assertEquals(false, result1.success, 'Should fail with count 0');

			// Test with too many
			SurveyInvitationController.BulkInvitationResult result2 = SurveyInvitationController.createBulkInvitations(tu.surveyId, 201);
			System.assertEquals(false, result2.success, 'Should fail with count > 200');
			Test.stopTest();
		}
	}

	@IsTest
	private static void testValidateInvitation() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create invitation
			SurveyInvitationController.InvitationResult createResult = SurveyInvitationController.createInvitation(tu.surveyId, null, null, null);

			Test.startTest();
			SurveyInvitationController.ValidationResult result = SurveyInvitationController.validateInvitation(createResult.token);
			Test.stopTest();

			System.assertEquals(true, result.isValid, 'Invitation should be valid');
			System.assertEquals(tu.surveyId, result.surveyId, 'Survey ID should match');
			System.assertEquals('Pending', result.status, 'Status should be Pending');
		}
	}

	@IsTest
	private static void testValidateInvalidToken() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			Test.startTest();
			SurveyInvitationController.ValidationResult result = SurveyInvitationController.validateInvitation('invalid-token-123');
			Test.stopTest();

			System.assertEquals(false, result.isValid, 'Should be invalid');
			System.assert(result.message.contains('Invalid'), 'Message should indicate invalid');
		}
	}

	@IsTest
	private static void testCompleteInvitation() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create invitation
			SurveyInvitationController.InvitationResult createResult = SurveyInvitationController.createInvitation(tu.surveyId, null, null, null);

			Test.startTest();
			Boolean success = SurveyInvitationController.completeInvitation(createResult.token, tu.surveyTakerId);
			Test.stopTest();

			System.assertEquals(true, success, 'Complete should succeed');

			// Verify invitation is completed
			SurveyInvitation__c invitation = [SELECT Id, Status__c, CompletedDate__c FROM SurveyInvitation__c WHERE Id = :createResult.invitationId];
			System.assertEquals('Completed', invitation.Status__c, 'Status should be Completed');
			System.assertNotEquals(null, invitation.CompletedDate__c, 'Completed date should be set');
		}
	}

	@IsTest
	private static void testValidateCompletedInvitation() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create and complete invitation
			SurveyInvitationController.InvitationResult createResult = SurveyInvitationController.createInvitation(tu.surveyId, null, null, null);
			SurveyInvitationController.completeInvitation(createResult.token, tu.surveyTakerId);

			Test.startTest();
			SurveyInvitationController.ValidationResult result = SurveyInvitationController.validateInvitation(createResult.token);
			Test.stopTest();

			System.assertEquals(false, result.isValid, 'Completed invitation should be invalid');
			System.assert(result.message.contains('already been completed'), 'Message should indicate already completed');
		}
	}

	@IsTest
	private static void testGetInvitationsForSurvey() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create invitations
			SurveyInvitationController.createInvitation(tu.surveyId, 'test1@example.com', 'User 1', null);
			SurveyInvitationController.createInvitation(tu.surveyId, 'test2@example.com', 'User 2', null);

			Test.startTest();
			List<SurveyInvitationController.InvitationData> invitations = SurveyInvitationController.getInvitationsForSurvey(tu.surveyId);
			Test.stopTest();

			System.assertEquals(2, invitations.size(), 'Should return 2 invitations');
		}
	}

	@IsTest
	private static void testInvitationWithExpiration() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create custom setting with 30 day expiration
			SurveySettings__c settings = new SurveySettings__c();
			settings.InvitationExpirationDays__c = 30;
			insert settings;

			Test.startTest();
			SurveyInvitationController.InvitationResult result = SurveyInvitationController.createInvitation(tu.surveyId, null, null, null);
			Test.stopTest();

			// Verify expiration date is set
			SurveyInvitation__c invitation = [SELECT Id, ExpirationDate__c FROM SurveyInvitation__c WHERE Id = :result.invitationId];
			System.assertNotEquals(null, invitation.ExpirationDate__c, 'Expiration date should be set');
			System.assert(invitation.ExpirationDate__c > DateTime.now(), 'Expiration date should be in future');
		}
	}

	@IsTest
	private static void testInvitationNoExpiration() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create custom setting with 0 day expiration (no expiration)
			SurveySettings__c settings = new SurveySettings__c();
			settings.InvitationExpirationDays__c = 0;
			insert settings;

			Test.startTest();
			SurveyInvitationController.InvitationResult result = SurveyInvitationController.createInvitation(tu.surveyId, null, null, null);
			Test.stopTest();

			// Verify expiration date is null
			SurveyInvitation__c invitation = [SELECT Id, ExpirationDate__c FROM SurveyInvitation__c WHERE Id = :result.invitationId];
			System.assertEquals(null, invitation.ExpirationDate__c, 'Expiration date should be null when disabled');
		}
	}

	@IsTest
	private static void testExpiredInvitationValidation() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create invitation
			SurveyInvitationController.InvitationResult createResult = SurveyInvitationController.createInvitation(tu.surveyId, null, null, null);

			// Manually set expiration date to past
			SurveyInvitation__c invitation = [SELECT Id FROM SurveyInvitation__c WHERE Id = :createResult.invitationId];
			invitation.ExpirationDate__c = DateTime.now().addDays(-1);
			update invitation;

			Test.startTest();
			SurveyInvitationController.ValidationResult result = SurveyInvitationController.validateInvitation(createResult.token);
			Test.stopTest();

			System.assertEquals(false, result.isValid, 'Expired invitation should be invalid');
			System.assert(result.message.contains('expired'), 'Message should indicate expiration');
		}
	}
}