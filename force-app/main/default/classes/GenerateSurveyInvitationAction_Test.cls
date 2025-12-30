/**
 * @description Test class for GenerateSurveyInvitationAction
 */
@IsTest
private class GenerateSurveyInvitationAction_Test {
	/**
	 * @description Setup test data
	 */
	@TestSetup
	static void setupTestData() {
		// Create survey settings
		SurveySettings__c settings = new SurveySettings__c();
		settings.SetupOwnerId = UserInfo.getOrganizationId();
		settings.InvitationExpirationDays__c = 30;
		insert settings;

		// Create a survey
		Survey__c survey = new Survey__c();
		survey.Name = 'Test Survey';
		survey.Thank_You_Text__c = 'Thank you!';
		insert survey;

		// Create a training request
		Training_Request__c tr = new Training_Request__c();
		tr.Training_Type__c = 'EAP Training';
		insert tr;
	}

	/**
	 * @description Test successful invitation generation
	 */
	@IsTest
	static void testGenerateInvitation_Success() {
		Survey__c survey = [SELECT Id FROM Survey__c LIMIT 1];
		Training_Request__c tr = [SELECT Id FROM Training_Request__c LIMIT 1];

		// Prepare request
		GenerateSurveyInvitationAction.InvitationRequest request = new GenerateSurveyInvitationAction.InvitationRequest();
		request.surveyId = survey.Id;
		request.trainingRequestId = tr.Id;
		request.surveyType = 'Customer';
		request.recipientEmail = 'customer@example.com';
		request.recipientName = 'Test Customer';

		Test.startTest();

		List<GenerateSurveyInvitationAction.InvitationResult> results = GenerateSurveyInvitationAction.generateInvitations(
			new List<GenerateSurveyInvitationAction.InvitationRequest>{ request }
		);

		Test.stopTest();

		// Verify result
		System.assertEquals(1, results.size(), 'Should return one result');
		GenerateSurveyInvitationAction.InvitationResult result = results[0];

		System.assertEquals(true, result.success, 'Generation should be successful');
		System.assertNotEquals(null, result.surveyUrl, 'Should have survey URL');
		System.assertNotEquals(null, result.token, 'Should have token');
		System.assertNotEquals(null, result.invitationId, 'Should have invitation ID');
		System.assert(result.surveyUrl.contains('token='), 'URL should contain token parameter');

		// Verify invitation was created
		List<SurveyInvitation__c> invitations = [
			SELECT Id, Token__c, Survey__c, RelatedRecordId__c, Status__c
			FROM SurveyInvitation__c
			WHERE Survey__c = :survey.Id
		];
		System.assertEquals(1, invitations.size(), 'Should create one invitation');
		System.assertEquals(tr.Id, invitations[0].RelatedRecordId__c, 'Should link to training request');
		System.assertEquals('Pending', invitations[0].Status__c, 'Invitation should be pending');
	}

	/**
	 * @description Test multiple invitation generation
	 */
	@IsTest
	static void testGenerateMultipleInvitations() {
		Survey__c survey = [SELECT Id FROM Survey__c LIMIT 1];
		Training_Request__c tr = [SELECT Id FROM Training_Request__c LIMIT 1];

		// Prepare multiple requests
		List<GenerateSurveyInvitationAction.InvitationRequest> requests = new List<GenerateSurveyInvitationAction.InvitationRequest>();

		GenerateSurveyInvitationAction.InvitationRequest customerRequest = new GenerateSurveyInvitationAction.InvitationRequest();
		customerRequest.surveyId = survey.Id;
		customerRequest.trainingRequestId = tr.Id;
		customerRequest.surveyType = 'Customer';
		customerRequest.recipientEmail = 'customer@example.com';
		requests.add(customerRequest);

		GenerateSurveyInvitationAction.InvitationRequest trainerRequest = new GenerateSurveyInvitationAction.InvitationRequest();
		trainerRequest.surveyId = survey.Id;
		trainerRequest.trainingRequestId = tr.Id;
		trainerRequest.surveyType = 'Trainer';
		trainerRequest.recipientEmail = 'trainer@example.com';
		requests.add(trainerRequest);

		Test.startTest();

		List<GenerateSurveyInvitationAction.InvitationResult> results = GenerateSurveyInvitationAction.generateInvitations(requests);

		Test.stopTest();

		// Verify results
		System.assertEquals(2, results.size(), 'Should return two results');

		for (GenerateSurveyInvitationAction.InvitationResult result : results) {
			System.assertEquals(true, result.success, 'Each generation should be successful');
			System.assertNotEquals(null, result.surveyUrl, 'Each should have survey URL');
			System.assertNotEquals(null, result.token, 'Each should have token');
		}

		// Verify invitations were created
		List<SurveyInvitation__c> invitations = [SELECT Id FROM SurveyInvitation__c WHERE Survey__c = :survey.Id];
		System.assertEquals(2, invitations.size(), 'Should create two invitations');

		// Verify tokens are unique
		Set<String> tokens = new Set<String>();
		for (GenerateSurveyInvitationAction.InvitationResult result : results) {
			tokens.add(result.token);
		}
		System.assertEquals(2, tokens.size(), 'All tokens should be unique');
	}

	/**
	 * @description Test with null survey ID
	 */
	@IsTest
	static void testGenerateInvitation_NullSurveyId() {
		GenerateSurveyInvitationAction.InvitationRequest request = new GenerateSurveyInvitationAction.InvitationRequest();
		request.surveyId = null;
		request.surveyType = 'Customer';

		Test.startTest();

		List<GenerateSurveyInvitationAction.InvitationResult> results = GenerateSurveyInvitationAction.generateInvitations(
			new List<GenerateSurveyInvitationAction.InvitationRequest>{ request }
		);

		Test.stopTest();

		// Verify result
		System.assertEquals(1, results.size(), 'Should return one result');
		GenerateSurveyInvitationAction.InvitationResult result = results[0];

		System.assertEquals(false, result.success, 'Generation should fail');
		System.assertEquals('Survey ID is required', result.errorMessage, 'Should have error message');
		System.assertEquals(null, result.surveyUrl, 'Should not have survey URL');
	}

	/**
	 * @description Test with invalid survey ID
	 */
	@IsTest
	static void testGenerateInvitation_InvalidSurveyId() {
		GenerateSurveyInvitationAction.InvitationRequest request = new GenerateSurveyInvitationAction.InvitationRequest();
		request.surveyId = '000000000000000'; // Invalid ID
		request.surveyType = 'Customer';

		Test.startTest();

		List<GenerateSurveyInvitationAction.InvitationResult> results = GenerateSurveyInvitationAction.generateInvitations(
			new List<GenerateSurveyInvitationAction.InvitationRequest>{ request }
		);

		Test.stopTest();

		// Verify result
		System.assertEquals(1, results.size(), 'Should return one result');
		GenerateSurveyInvitationAction.InvitationResult result = results[0];

		System.assertEquals(false, result.success, 'Generation should fail');
		System.assertEquals('Survey not found', result.errorMessage, 'Should have error message');
	}

	/**
	 * @description Test with empty request list
	 */
	@IsTest
	static void testGenerateInvitation_EmptyList() {
		Test.startTest();

		List<GenerateSurveyInvitationAction.InvitationResult> results = GenerateSurveyInvitationAction.generateInvitations(
			new List<GenerateSurveyInvitationAction.InvitationRequest>()
		);

		Test.stopTest();

		// Verify result
		System.assertEquals(0, results.size(), 'Should return empty list');
	}

	/**
	 * @description Test without training request (should still work)
	 */
	@IsTest
	static void testGenerateInvitation_NoTrainingRequest() {
		Survey__c survey = [SELECT Id FROM Survey__c LIMIT 1];

		GenerateSurveyInvitationAction.InvitationRequest request = new GenerateSurveyInvitationAction.InvitationRequest();
		request.surveyId = survey.Id;
		request.surveyType = 'General';
		request.recipientEmail = 'user@example.com';

		Test.startTest();

		List<GenerateSurveyInvitationAction.InvitationResult> results = GenerateSurveyInvitationAction.generateInvitations(
			new List<GenerateSurveyInvitationAction.InvitationRequest>{ request }
		);

		Test.stopTest();

		// Verify result
		System.assertEquals(1, results.size(), 'Should return one result');
		GenerateSurveyInvitationAction.InvitationResult result = results[0];

		System.assertEquals(true, result.success, 'Generation should be successful even without training request');
		System.assertNotEquals(null, result.surveyUrl, 'Should have survey URL');
		System.assertNotEquals(null, result.token, 'Should have token');
	}
}