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
			SurveyInvitationController.InvitationResult result = SurveyInvitationController.createInvitation(tu.surveyId, 'test@example.com', 'Test Participant', null, null, null, null);
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
			SurveyInvitationController.InvitationResult result = SurveyInvitationController.createInvitation(null, null, null, null, null, null);
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
			SurveyInvitationController.BulkInvitationResult result = SurveyInvitationController.createBulkInvitations(tu.surveyId, 5, null, null);
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
			SurveyInvitationController.BulkInvitationResult result1 = SurveyInvitationController.createBulkInvitations(tu.surveyId, 0, null, null);
			System.assertEquals(false, result1.success, 'Should fail with count 0');

			// Test with too many
			SurveyInvitationController.BulkInvitationResult result2 = SurveyInvitationController.createBulkInvitations(tu.surveyId, 201, null, null, null);
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
			SurveyInvitationController.InvitationResult createResult = SurveyInvitationController.createInvitation(tu.surveyId, null, null, null, null, null);

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
			SurveyInvitationController.InvitationResult createResult = SurveyInvitationController.createInvitation(tu.surveyId, null, null, null, null, null);
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
			SurveyInvitationController.createInvitation(tu.surveyId, 'test1@example.com', 'User 1', null, null, null, null);
			SurveyInvitationController.createInvitation(tu.surveyId, 'test2@example.com', 'User 2', null, null, null);

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
			SurveyInvitationController.InvitationResult result = SurveyInvitationController.createInvitation(tu.surveyId, null, null, null, null, null);
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
			SurveyInvitationController.InvitationResult createResult = SurveyInvitationController.createInvitation(tu.surveyId, null, null, null, null, null);

			// Manually set expiration date to past
			SurveyInvitation__c invitation = [SELECT Id FROM SurveyInvitation__c WHERE Id = :createResult.invitationId];
			invitation.ExpirationDate__c = DateTime.now().addDays(-1);
			update invitation;

			Test.startTest();
			SurveyInvitationController.ValidationResult result = SurveyInvitationController.validateInvitation(createResult.token);
			Test.stopTest();

			System.assertEquals(false, result.isValid, 'Expired invitation should be invalid');
			System.assert(result.message.contains('survey window'), 'Message should indicate survey window closed');
		}
	}

	@IsTest
	private static void testInvitationWithEventDateExpiration() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create custom setting with 14 day expiration
			SurveySettings__c settings = new SurveySettings__c();
			settings.InvitationExpirationDays__c = 14;
			insert settings;

			// Set event date to 10 days from now (e.g., training event date)
			DateTime eventDate = DateTime.now().addDays(10);
			String relatedRecordId = 'TRAINING_EVENT_001'; // Example training event reference
			String eventTopic = 'Advanced Salesforce Development';

			Test.startTest();
			SurveyInvitationController.InvitationResult result = SurveyInvitationController.createInvitation(tu.surveyId, null, null, null, eventDate, relatedRecordId, eventTopic);
			Test.stopTest();

			// Verify invitation was created successfully
			System.assertEquals(true, result.success, 'Invitation should be created successfully');

			// Verify event date and related record are stored
			SurveyInvitation__c invitation = [
				SELECT Id, ExpirationDate__c, EventDate__c, RelatedRecordId__c, EventTopic__c
				FROM SurveyInvitation__c
				WHERE Id = :result.invitationId
			];
			System.assertEquals(eventDate, invitation.EventDate__c, 'Event date should be stored');
			System.assertEquals(relatedRecordId, invitation.RelatedRecordId__c, 'Related record ID should be stored');
			System.assertEquals(eventTopic, invitation.EventTopic__c, 'Event topic should be stored');

			// Verify expiration date is calculated from event date (event date + 14 days)
			System.assertNotEquals(null, invitation.ExpirationDate__c, 'Expiration date should be set');
			DateTime expectedExpiration = eventDate.addDays(14);
			System.assertEquals(expectedExpiration, invitation.ExpirationDate__c, 'Expiration should be 14 days after event date');
		}
	}

	@IsTest
	private static void testBulkInvitationsWithEventDate() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create custom setting with 14 day expiration
			SurveySettings__c settings = new SurveySettings__c();
			settings.InvitationExpirationDays__c = 14;
			insert settings;

			// Set event date
			DateTime eventDate = DateTime.now().addDays(7);
			String relatedRecordId = 'TRAINING_EVENT_002'; // Example training event reference
			String eventTopic = 'Introduction to Lightning Web Components';

			Test.startTest();
			SurveyInvitationController.BulkInvitationResult result = SurveyInvitationController.createBulkInvitations(tu.surveyId, 3, eventDate, relatedRecordId, eventTopic);
			Test.stopTest();

			System.assertEquals(true, result.success, 'Bulk creation should succeed');
			System.assertEquals(3, result.totalGenerated, 'Should generate 3 invitations');

			// Verify all invitations have the event date and calculated expiration
			List<SurveyInvitation__c> invitations = [
				SELECT Id, ExpirationDate__c, EventDate__c, RelatedRecordId__c, EventTopic__c
				FROM SurveyInvitation__c
				WHERE Survey__c = :tu.surveyId
			];
			System.assertEquals(3, invitations.size(), 'Should have 3 invitations');

			DateTime expectedExpiration = eventDate.addDays(14);
			for (SurveyInvitation__c inv : invitations) {
				System.assertEquals(eventDate, inv.EventDate__c, 'Event date should match');
				System.assertEquals(relatedRecordId, inv.RelatedRecordId__c, 'Related record ID should match');
				System.assertEquals(eventTopic, inv.EventTopic__c, 'Event topic should match');
				System.assertEquals(expectedExpiration, inv.ExpirationDate__c, 'Expiration should be 14 days after event date');
			}
		}
	}

	@IsTest
	private static void testEventBasedExpirationValidation() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create custom setting with 14 day expiration
			SurveySettings__c settings = new SurveySettings__c();
			settings.InvitationExpirationDays__c = 14;
			insert settings;

			// Set event date to 20 days ago (past event)
			DateTime pastEventDate = DateTime.now().addDays(-20);

			// Create invitation - should expire 14 days after event (6 days ago)
			SurveyInvitationController.InvitationResult createResult = SurveyInvitationController.createInvitation(tu.surveyId, null, null, null, pastEventDate, null, null);

			Test.startTest();
			SurveyInvitationController.ValidationResult result = SurveyInvitationController.validateInvitation(createResult.token);
			Test.stopTest();

			// Invitation should be expired (event was 20 days ago, expiration is 14 days after event)
			System.assertEquals(false, result.isValid, 'Invitation should be expired');
			System.assert(result.message.contains('survey window'), 'Message should indicate survey window closed');
		}
	}
}