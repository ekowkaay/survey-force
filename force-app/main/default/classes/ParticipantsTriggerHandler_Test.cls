/**
 * @description Test class for ParticipantsTriggerHandler
 */
@IsTest
private class ParticipantsTriggerHandler_Test {
	/**
	 * @description Setup test data
	 */
	@TestSetup
	static void setupTestData() {
		// Custom Metadata Types (SiteURL__mdt) are deployed and automatically available in tests

		// Create survey settings
		SurveySettings__c settings = new SurveySettings__c();
		settings.SetupOwnerId = UserInfo.getOrganizationId();
		settings.InvitationExpirationDays__c = 30;
		insert settings;

		// Create survey template
		Survey__c template = new Survey__c();
		template.Name = 'PartcipantSurveyTemplate';
		template.Thank_You_Text__c = 'Thank you for your participation!';
		insert template;

		// Create questions for template
		List<Survey_Question__c> questions = new List<Survey_Question__c>();
		Survey_Question__c q1 = new Survey_Question__c();
		q1.Survey__c = template.Id;
		q1.Question__c = 'How would you rate the training?';
		q1.Type__c = 'Single Select--Vertical';
		q1.Choices__c = 'Excellent\nGood\nFair\nPoor';
		q1.OrderNumber__c = 1;
		questions.add(q1);
		insert questions;

		// Create Training Request
		Training_Request__c tr = new Training_Request__c();
		tr.Training_Type__c = 'EAP Training';
		insert tr;

		// Create main survey for the training request
		String surveyUrl = SurveyUtilities.createSurvey(tr.Id, 'Participant', 'English', 'Main Participant Survey');

		// Update training request with survey URL
		tr.Participant_Survey__c = surveyUrl;
		update tr;
	}

	/**
	 * @description Test automatic survey link generation on participant insert
	 */
	@IsTest
	static void testAutoGenerateSurveyOnInsert() {
		Training_Request__c tr = [SELECT Id, Participant_Survey__c FROM Training_Request__c LIMIT 1];
		System.assertNotEquals(null, tr.Participant_Survey__c, 'Training request should have participant survey URL');

		Test.startTest();

		// Create a new participant
		Participants__c participant = new Participants__c();
		participant.Training_Request__c = tr.Id;
		participant.Participant_Name__c = 'John Doe';
		participant.Email__c = 'john.doe@example.com';
		insert participant;

		Test.stopTest();

		// Verify participant has survey link
		Participants__c insertedParticipant = [
			SELECT Id, Participant_Survey__c
			FROM Participants__c
			WHERE Id = :participant.Id
		];

		System.assertNotEquals(null, insertedParticipant.Participant_Survey__c, 'Participant should have survey link');
		System.assert(insertedParticipant.Participant_Survey__c.contains('token='), 'Participant survey URL should contain token');

		// Verify invitation was created
		List<SurveyInvitation__c> invitations = [
			SELECT Id, ParticipantName__c, Email__c, Status__c
			FROM SurveyInvitation__c
			WHERE Email__c = 'john.doe@example.com'
		];
		System.assertEquals(1, invitations.size(), 'Should create one invitation');
		System.assertEquals('John Doe', invitations[0].ParticipantName__c, 'Should have correct participant name');
		System.assertEquals('Pending', invitations[0].Status__c, 'Invitation should be pending');
	}

	/**
	 * @description Test bulk participant insert with automatic survey generation
	 */
	@IsTest
	static void testBulkParticipantInsert() {
		Training_Request__c tr = [SELECT Id, Participant_Survey__c FROM Training_Request__c LIMIT 1];

		Test.startTest();

		// Create multiple participants
		List<Participants__c> participants = new List<Participants__c>();
		for (Integer i = 0; i < 20; i++) {
			Participants__c p = new Participants__c();
			p.Training_Request__c = tr.Id;
			p.Participant_Name__c = 'Participant ' + i;
			p.Email__c = 'participant' + i + '@example.com';
			participants.add(p);
		}
		insert participants;

		Test.stopTest();

		// Verify all participants have survey links
		List<Participants__c> insertedParticipants = [
			SELECT Id, Participant_Survey__c, Email__c
			FROM Participants__c
			WHERE Training_Request__c = :tr.Id
		];

		System.assertEquals(20, insertedParticipants.size(), 'Should have 20 participants');

		Integer participantsWithLinks = 0;
		Set<String> uniqueUrls = new Set<String>();

		for (Participants__c p : insertedParticipants) {
			if (String.isNotBlank(p.Participant_Survey__c)) {
				participantsWithLinks++;
				uniqueUrls.add(p.Participant_Survey__c);
			}
		}

		System.assertEquals(20, participantsWithLinks, 'All participants should have survey links');
		System.assertEquals(20, uniqueUrls.size(), 'All survey links should be unique');

		// Verify invitations were created
		List<SurveyInvitation__c> invitations = [
			SELECT Id, ParticipantName__c
			FROM SurveyInvitation__c
			WHERE Email__c LIKE 'participant%@example.com'
		];
		System.assertEquals(20, invitations.size(), 'Should create 20 invitations');
	}

	/**
	 * @description Test participant insert when training request has no survey
	 */
	@IsTest
	static void testParticipantInsert_NoSurvey() {
		// Create a training request without a survey
		Training_Request__c trNoSurvey = new Training_Request__c();
		trNoSurvey.Training_Type__c = 'EAP Training';
		insert trNoSurvey;

		Test.startTest();

		// Create participant
		Participants__c participant = new Participants__c();
		participant.Training_Request__c = trNoSurvey.Id;
		participant.Participant_Name__c = 'Jane Doe';
		participant.Email__c = 'jane.doe@example.com';
		insert participant;

		Test.stopTest();

		// Verify participant was created but has no survey link
		Participants__c insertedParticipant = [
			SELECT Id, Participant_Survey__c
			FROM Participants__c
			WHERE Id = :participant.Id
		];

		System.assertEquals(null, insertedParticipant.Participant_Survey__c, 'Participant should not have survey link');

		// Verify no invitation was created
		List<SurveyInvitation__c> invitations = [
			SELECT Id
			FROM SurveyInvitation__c
			WHERE Email__c = 'jane.doe@example.com'
		];
		System.assertEquals(0, invitations.size(), 'Should not create invitation without survey');
	}

	/**
	 * @description Test trigger recursion prevention
	 */
	@IsTest
	static void testRecursionPrevention() {
		Training_Request__c tr = [SELECT Id, Participant_Survey__c FROM Training_Request__c LIMIT 1];

		Test.startTest();

		// Create participant
		Participants__c participant = new Participants__c();
		participant.Training_Request__c = tr.Id;
		participant.Participant_Name__c = 'Recursion Test';
		participant.Email__c = 'recursion@example.com';
		insert participant;

		// Update the participant multiple times - should not cause recursion
		participant.Participant_Name__c = 'Updated Name 1';
		update participant;

		participant.Participant_Name__c = 'Updated Name 2';
		update participant;

		Test.stopTest();

		// Verify only one invitation was created
		List<SurveyInvitation__c> invitations = [
			SELECT Id
			FROM SurveyInvitation__c
			WHERE Email__c = 'recursion@example.com'
		];
		System.assertEquals(1, invitations.size(), 'Should create only one invitation despite updates');
	}

	/**
	 * @description Test before insert handler (placeholder functionality)
	 */
	@IsTest
	static void testBeforeInsert() {
		Training_Request__c tr = [SELECT Id FROM Training_Request__c LIMIT 1];

		Test.startTest();

		Participants__c participant = new Participants__c();
		participant.Training_Request__c = tr.Id;
		participant.Participant_Name__c = 'Test Before Insert';
		participant.Email__c = 'before@example.com';
		insert participant;

		Test.stopTest();

		// Verify participant was inserted successfully
		List<Participants__c> inserted = [
			SELECT Id
			FROM Participants__c
			WHERE Email__c = 'before@example.com'
		];
		System.assertEquals(1, inserted.size(), 'Participant should be inserted');
	}

	/**
	 * @description Test update handler
	 */
	@IsTest
	static void testAfterUpdate() {
		Training_Request__c tr = [SELECT Id, Participant_Survey__c FROM Training_Request__c LIMIT 1];

		// Create participant
		Participants__c participant = new Participants__c();
		participant.Training_Request__c = tr.Id;
		participant.Participant_Name__c = 'Update Test';
		participant.Email__c = 'update@example.com';
		insert participant;

		Test.startTest();

		// Update participant
		participant.Participant_Name__c = 'Updated Name';
		update participant;

		Test.stopTest();

		// Verify participant was updated
		Participants__c updated = [
			SELECT Id, Participant_Name__c
			FROM Participants__c
			WHERE Id = :participant.Id
		];
		System.assertEquals('Updated Name', updated.Participant_Name__c, 'Name should be updated');
	}

	/**
	 * @description Test delete handler
	 */
	@IsTest
	static void testAfterDelete() {
		Training_Request__c tr = [SELECT Id FROM Training_Request__c LIMIT 1];

		Participants__c participant = new Participants__c();
		participant.Training_Request__c = tr.Id;
		participant.Participant_Name__c = 'Delete Test';
		participant.Email__c = 'delete@example.com';
		insert participant;

		Test.startTest();

		delete participant;

		Test.stopTest();

		// Verify participant was deleted
		List<Participants__c> deleted = [
			SELECT Id
			FROM Participants__c
			WHERE Email__c = 'delete@example.com'
		];
		System.assertEquals(0, deleted.size(), 'Participant should be deleted');
	}

	/**
	 * @description Test undelete handler
	 */
	@IsTest
	static void testAfterUndelete() {
		Training_Request__c tr = [SELECT Id FROM Training_Request__c LIMIT 1];

		Participants__c participant = new Participants__c();
		participant.Training_Request__c = tr.Id;
		participant.Participant_Name__c = 'Undelete Test';
		participant.Email__c = 'undelete@example.com';
		insert participant;

		delete participant;

		Test.startTest();

		undelete participant;

		Test.stopTest();

		// Verify participant was undeleted
		List<Participants__c> undeleted = [
			SELECT Id
			FROM Participants__c
			WHERE Email__c = 'undelete@example.com'
		];
		System.assertEquals(1, undeleted.size(), 'Participant should be undeleted');
	}

	/**
	 * @description Test URL extraction from various formats
	 */
	@IsTest
	static void testExtractSurveyIdFromUrl() {
		// This tests the private method indirectly through the trigger
		Training_Request__c tr = [SELECT Id FROM Training_Request__c LIMIT 1];

		// Create a survey with known ID
		Survey__c testSurvey = new Survey__c();
		testSurvey.Name = 'URL Test Survey';
		testSurvey.Thank_You_Text__c = 'Thank you';
		insert testSurvey;

		// Update training request with survey URL
		tr.Participant_Survey__c = 'https://example.com/TakeSurvey?id=' + testSurvey.Id;
		update tr;

		Test.startTest();

		// Create participant - should extract survey ID from URL
		Participants__c participant = new Participants__c();
		participant.Training_Request__c = tr.Id;
		participant.Participant_Name__c = 'URL Extract Test';
		participant.Email__c = 'urlextract@example.com';
		insert participant;

		Test.stopTest();

		// Verify participant has survey link
		Participants__c inserted = [
			SELECT Id, Participant_Survey__c
			FROM Participants__c
			WHERE Id = :participant.Id
		];
		System.assertNotEquals(null, inserted.Participant_Survey__c, 'Should have extracted survey ID and generated link');
	}
}