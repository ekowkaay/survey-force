/**
 * @description Test class for SurveyUtilities
 */
@IsTest
private class SurveyUtilities_Test {
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

		// Create survey templates
		List<Survey__c> templates = new List<Survey__c>();

		Survey__c participantTemplate = new Survey__c();
		participantTemplate.Name = 'PartcipantSurveyTemplate';
		participantTemplate.Thank_You_Text__c = 'Thank you for your participation!';
		templates.add(participantTemplate);

		Survey__c spanishTemplate = new Survey__c();
		spanishTemplate.Name = 'PartcipantSurveyTemplate Spanish';
		spanishTemplate.Thank_You_Text__c = 'Gracias por su participación!';
		templates.add(spanishTemplate);

		Survey__c customerTemplate = new Survey__c();
		customerTemplate.Name = 'CustomerSurveyTemplate';
		customerTemplate.Thank_You_Text__c = 'Thank you for your feedback!';
		templates.add(customerTemplate);

		Survey__c trainerTemplate = new Survey__c();
		trainerTemplate.Name = 'TrainerSurveyTemplate';
		trainerTemplate.Thank_You_Text__c = 'Thank you for your input!';
		templates.add(trainerTemplate);

		insert templates;

		// Create questions for participant template
		List<Survey_Question__c> questions = new List<Survey_Question__c>();
		Survey_Question__c q1 = new Survey_Question__c();
		q1.Survey__c = participantTemplate.Id;
		q1.Question__c = 'How would you rate the training?';
		q1.Type__c = 'Single Select--Vertical';
		q1.Choices__c = 'Excellent\nGood\nFair\nPoor';
		q1.OrderNumber__c = 1;
		q1.Required__c = true;
		questions.add(q1);

		Survey_Question__c q2 = new Survey_Question__c();
		q2.Survey__c = participantTemplate.Id;
		q2.Question__c = 'Additional comments?';
		q2.Type__c = 'Free Text';
		q2.OrderNumber__c = 2;
		q2.Required__c = false;
		questions.add(q2);

		insert questions;

		// Create Training Request
		Training_Request__c tr = new Training_Request__c();
		tr.Training_Type__c = 'EAP Training';
		insert tr;
	}

	/**
	 * @description Test getSurveyTemplateName method
	 */
	@IsTest
	static void testGetSurveyTemplateName() {
		Test.startTest();

		// Test Participant English
		String result1 = SurveyUtilities.getSurveyTemplateName('Participant', 'English');
		System.assertEquals('PartcipantSurveyTemplate', result1, 'Should return English participant template');

		// Test Participant Spanish
		String result2 = SurveyUtilities.getSurveyTemplateName('Participant', 'Spanish');
		System.assertEquals('PartcipantSurveyTemplate Spanish', result2, 'Should return Spanish participant template');

		// Test Customer
		String result3 = SurveyUtilities.getSurveyTemplateName('Customer', 'English');
		System.assertEquals('CustomerSurveyTemplate', result3, 'Should return customer template');

		// Test Trainer
		String result4 = SurveyUtilities.getSurveyTemplateName('Trainer', 'English');
		System.assertEquals('TrainerSurveyTemplate', result4, 'Should return trainer template');

		// Test invalid input
		String result5 = SurveyUtilities.getSurveyTemplateName(null, 'English');
		System.assertEquals(null, result5, 'Should return null for invalid input');

		Test.stopTest();
	}

	/**
	 * @description Test createSurvey method with valid inputs
	 */
	@IsTest
	static void testCreateSurvey_Success() {
		Training_Request__c tr = [SELECT Id FROM Training_Request__c LIMIT 1];

		Test.startTest();

		String surveyUrl = SurveyUtilities.createSurvey(tr.Id, 'Participant', 'English', 'Test Survey');

		Test.stopTest();

		System.assertNotEquals(null, surveyUrl, 'Survey URL should not be null');
		System.assert(surveyUrl.contains('/TakeSurvey?id='), 'Survey URL should contain correct path');

		// Verify survey was created
		List<Survey__c> createdSurveys = [SELECT Id, Name FROM Survey__c WHERE Name = 'Test Survey'];
		System.assertEquals(1, createdSurveys.size(), 'Survey should be created');

		// Verify questions were cloned
		List<Survey_Question__c> clonedQuestions = [
			SELECT Id
			FROM Survey_Question__c
			WHERE Survey__c = :createdSurveys[0].Id
		];
		System.assertEquals(2, clonedQuestions.size(), 'Questions should be cloned');
	}

	/**
	 * @description Test createSurvey with invalid template
	 */
	@IsTest
	static void testCreateSurvey_InvalidTemplate() {
		Training_Request__c tr = [SELECT Id FROM Training_Request__c LIMIT 1];

		Test.startTest();

		String surveyUrl = SurveyUtilities.createSurvey(tr.Id, 'Invalid', 'English', 'Test Survey');

		Test.stopTest();

		System.assertEquals(null, surveyUrl, 'Survey URL should be null for invalid template');
	}

	/**
	 * @description Test createSurveyWithResult for detailed error handling
	 */
	@IsTest
	static void testCreateSurveyWithResult() {
		Training_Request__c tr = [SELECT Id FROM Training_Request__c LIMIT 1];

		Test.startTest();

		// Test successful creation
		SurveyUtilities.SurveyCreationResult result1 = SurveyUtilities.createSurveyWithResult(tr.Id, 'Participant', 'English', 'Test Survey 1');

		System.assertEquals(true, result1.success, 'Should be successful');
		System.assertNotEquals(null, result1.surveyId, 'Should have survey ID');
		System.assertNotEquals(null, result1.surveyUrl, 'Should have survey URL');

		// Test with null parent ID
		SurveyUtilities.SurveyCreationResult result2 = SurveyUtilities.createSurveyWithResult(null, 'Participant', 'English', 'Test Survey 2');

		System.assertEquals(false, result2.success, 'Should fail with null parent ID');
		System.assert(result2.message.contains('required'), 'Should have error message');

		// Test with blank survey name
		SurveyUtilities.SurveyCreationResult result3 = SurveyUtilities.createSurveyWithResult(tr.Id, 'Participant', 'English', '');

		System.assertEquals(false, result3.success, 'Should fail with blank survey name');

		Test.stopTest();
	}

	/**
	 * @description Test bulk survey link generation for participants
	 */
	@IsTest
	static void testGenerateParticipantSurveyLinks_Bulk() {
		Training_Request__c tr = [SELECT Id FROM Training_Request__c LIMIT 1];

		// Create a survey
		Survey__c survey = new Survey__c();
		survey.Name = 'Test Participant Survey';
		survey.Thank_You_Text__c = 'Thank you!';
		insert survey;

		// Create multiple participants
		List<Participants__c> participants = new List<Participants__c>();
		for (Integer i = 0; i < 10; i++) {
			Participants__c p = new Participants__c();
			p.Training_Request__c = tr.Id;
			p.Participant_Name__c = 'Test Participant ' + i;
			p.Email__c = 'test' + i + '@example.com';
			participants.add(p);
		}
		insert participants;

		Set<Id> participantIds = new Set<Id>();
		for (Participants__c p : participants) {
			participantIds.add(p.Id);
		}

		Test.startTest();

		Map<Id, SurveyUtilities.ParticipantSurveyResult> results = SurveyUtilities.generateParticipantSurveyLinks(participantIds, survey.Id);

		Test.stopTest();

		System.assertEquals(10, results.size(), 'Should generate links for all participants');

		// Verify all were successful
		for (Id participantId : results.keySet()) {
			SurveyUtilities.ParticipantSurveyResult result = results.get(participantId);
			System.assertEquals(true, result.success, 'Each link generation should be successful');
			System.assertNotEquals(null, result.surveyUrl, 'Each participant should have a survey URL');
			System.assert(result.surveyUrl.contains('token='), 'Survey URL should contain token');
		}

		// Verify invitations were created
		List<SurveyInvitation__c> invitations = [
			SELECT Id, Token__c, Survey__c, Email__c
			FROM SurveyInvitation__c
			WHERE Survey__c = :survey.Id
		];
		System.assertEquals(10, invitations.size(), 'Should create 10 survey invitations');
	}

	/**
	 * @description Test single participant survey link generation
	 */
	@IsTest
	static void testGenerateParticipantSurveyLink_Single() {
		Training_Request__c tr = [SELECT Id FROM Training_Request__c LIMIT 1];

		// Create a survey
		Survey__c survey = new Survey__c();
		survey.Name = 'Test Survey';
		survey.Thank_You_Text__c = 'Thank you!';
		insert survey;

		// Create a participant
		Participants__c participant = new Participants__c();
		participant.Training_Request__c = tr.Id;
		participant.Participant_Name__c = 'Test Participant';
		participant.Email__c = 'test@example.com';
		insert participant;

		Test.startTest();

		String surveyUrl = SurveyUtilities.generateParticipantSurveyLink(participant.Id, survey.Id);

		Test.stopTest();

		System.assertNotEquals(null, surveyUrl, 'Survey URL should not be null');
		System.assert(surveyUrl.contains('token='), 'Survey URL should contain token');

		// Verify invitation was created
		List<SurveyInvitation__c> invitations = [
			SELECT Id, ParticipantName__c, Email__c
			FROM SurveyInvitation__c
			WHERE Survey__c = :survey.Id
		];
		System.assertEquals(1, invitations.size(), 'Should create one invitation');
		System.assertEquals('Test Participant', invitations[0].ParticipantName__c, 'Should have participant name');
		System.assertEquals('test@example.com', invitations[0].Email__c, 'Should have participant email');
	}

	/**
	 * @description Test createParticipantSurveys method
	 */
	@IsTest
	static void testCreateParticipantSurveys() {
		Training_Request__c tr = [SELECT Id FROM Training_Request__c LIMIT 1];

		// Create a survey
		Survey__c survey = new Survey__c();
		survey.Name = 'Test Survey';
		survey.Thank_You_Text__c = 'Thank you!';
		insert survey;

		// Create participants
		List<Participants__c> participants = new List<Participants__c>();
		for (Integer i = 0; i < 5; i++) {
			Participants__c p = new Participants__c();
			p.Training_Request__c = tr.Id;
			p.Participant_Name__c = 'Participant ' + i;
			p.Email__c = 'participant' + i + '@example.com';
			participants.add(p);
		}
		insert participants;

		Test.startTest();

		Map<Id, String> participantSurveys = SurveyUtilities.createParticipantSurveys(tr.Id, survey.Id);

		Test.stopTest();

		System.assertEquals(5, participantSurveys.size(), 'Should create surveys for all participants');

		// Verify all URLs are unique
		Set<String> uniqueUrls = new Set<String>(participantSurveys.values());
		System.assertEquals(5, uniqueUrls.size(), 'All survey URLs should be unique');
	}

	/**
	 * @description Test error handling with invalid inputs
	 */
	@IsTest
	static void testErrorHandling() {
		Test.startTest();

		// Test with null IDs
		Map<Id, SurveyUtilities.ParticipantSurveyResult> results1 = SurveyUtilities.generateParticipantSurveyLinks(null, null);
		System.assertEquals(0, results1.size(), 'Should return empty map for null inputs');

		// Test with empty set
		Map<Id, SurveyUtilities.ParticipantSurveyResult> results2 = SurveyUtilities.generateParticipantSurveyLinks(new Set<Id>(), null);
		System.assertEquals(0, results2.size(), 'Should return empty map for empty set');

		// Test single link with null participant
		String result3 = SurveyUtilities.generateParticipantSurveyLink(null, null);
		System.assertEquals(null, result3, 'Should return null for invalid inputs');

		Test.stopTest();
	}

	/**
	 * @description Test bulk survey creation with mixed valid and invalid requests
	 * This test ensures the index mapping works correctly when some requests fail validation
	 */
	@IsTest
	static void testCreateSurveysInBulk_MixedRequests() {
		Training_Request__c tr = [SELECT Id FROM Training_Request__c LIMIT 1];

		Test.startTest();

		// Create a mix of valid and invalid requests
		List<SurveyUtilities.SurveyCreationRequest> requests = new List<SurveyUtilities.SurveyCreationRequest>();

		// Invalid request - null training request ID (should fail)
		requests.add(new SurveyUtilities.SurveyCreationRequest(null, 'Participant', 'English', 'Invalid Survey 1'));

		// Valid request
		requests.add(new SurveyUtilities.SurveyCreationRequest(tr.Id, 'Participant', 'English', 'Valid Survey 1'));

		// Invalid request - blank survey name (should fail)
		requests.add(new SurveyUtilities.SurveyCreationRequest(tr.Id, 'Customer', 'English', ''));

		// Valid request
		requests.add(new SurveyUtilities.SurveyCreationRequest(tr.Id, 'Customer', 'English', 'Valid Survey 2'));

		// Invalid request - invalid survey type (should fail)
		requests.add(new SurveyUtilities.SurveyCreationRequest(tr.Id, 'InvalidType', 'English', 'Invalid Survey 2'));

		// Valid request
		requests.add(new SurveyUtilities.SurveyCreationRequest(tr.Id, 'Trainer', 'English', 'Valid Survey 3'));

		// Call bulk creation
		Map<String, SurveyUtilities.SurveyCreationResult> results = SurveyUtilities.createSurveysInBulk(requests);

		Test.stopTest();

		// Verify results for all requests
		System.assertEquals(6, results.size(), 'Should have results for all 6 requests');

		// Verify invalid requests failed with appropriate messages
		String key1 = 'null_Participant';
		System.assert(results.containsKey(key1), 'Should have result for request 1');
		System.assertEquals(false, results.get(key1).success, 'Request 1 should fail');
		System.assert(results.get(key1).message.contains('required'), 'Request 1 should have error about required ID');

		// Verify valid request succeeded
		String key2 = tr.Id + '_Participant';
		System.assert(results.containsKey(key2), 'Should have result for request 2');
		System.assertEquals(true, results.get(key2).success, 'Request 2 should succeed');
		System.assertNotEquals(null, results.get(key2).surveyId, 'Request 2 should have survey ID');

		// Verify invalid request (blank name) failed
		String key3 = tr.Id + '_Customer';
		System.assert(results.containsKey(key3), 'Should have result for request 3/4');
		// Note: Request 4 with same key will overwrite request 3 result
		System.assertEquals(true, results.get(key3).success, 'Request 4 (valid Customer) should succeed');

		// Verify invalid request (invalid type) failed
		String key5 = tr.Id + '_InvalidType';
		System.assert(results.containsKey(key5), 'Should have result for request 5');
		System.assertEquals(false, results.get(key5).success, 'Request 5 should fail');
		System.assert(results.get(key5).message.contains('Invalid'), 'Request 5 should have error about invalid type');

		// Verify valid request succeeded
		String key6 = tr.Id + '_Trainer';
		System.assert(results.containsKey(key6), 'Should have result for request 6');
		System.assertEquals(true, results.get(key6).success, 'Request 6 should succeed');
		System.assertNotEquals(null, results.get(key6).surveyId, 'Request 6 should have survey ID');

		// Verify only valid surveys were created
		List<Survey__c> createdSurveys = [
			SELECT Id, Name
			FROM Survey__c
			WHERE Name IN ('Valid Survey 1', 'Valid Survey 2', 'Valid Survey 3')
		];
		System.assertEquals(3, createdSurveys.size(), 'Should create 3 valid surveys');

		// Verify questions were cloned for all valid surveys
		for (Survey__c survey : createdSurveys) {
			List<Survey_Question__c> questions = [
				SELECT Id
				FROM Survey_Question__c
				WHERE Survey__c = :survey.Id
			];
			System.assert(questions.size() > 0, 'Each valid survey should have questions cloned: ' + survey.Name);
		}
	}
}