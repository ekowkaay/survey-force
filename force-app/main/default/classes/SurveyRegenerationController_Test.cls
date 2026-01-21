/**
 * @description Test class for SurveyRegenerationController
 */
@isTest
private class SurveyRegenerationController_Test {
	/**
	 * @description Test setup - creates test data
	 */
	@TestSetup
	static void makeData() {
		// Create survey templates
		SurveyTestingUtil.createSurveyTemplates();

		// Create training requests
		List<Training_Request__c> trainingRequests = new List<Training_Request__c>();
		for (Integer i = 0; i < 3; i++) {
			Training_Request__c tr = new Training_Request__c();
			tr.Name = 'Test Training ' + i;
			tr.Training_Type__c = 'EAP Training';
			trainingRequests.add(tr);
		}
		insert trainingRequests;

		// Wait for trigger to create surveys
		Test.getEventBus().deliver();
	}

	/**
	 * @description Test parsing Training Request IDs from file content
	 */
	@isTest
	static void testParseTrainingRequestIds() {
		// Get training requests
		List<Training_Request__c> trs = [SELECT Id FROM Training_Request__c LIMIT 3];

		Test.startTest();

		// Test comma-separated IDs
		String commaSeparated = trs[0].Id + ',' + trs[1].Id + ',' + trs[2].Id;
		List<String> result1 = SurveyRegenerationController.parseTrainingRequestIds(commaSeparated);
		System.assertEquals(3, result1.size(), 'Should parse 3 IDs from comma-separated list');

		// Test newline-separated IDs
		String newlineSeparated = trs[0].Id + '\n' + trs[1].Id + '\n' + trs[2].Id;
		List<String> result2 = SurveyRegenerationController.parseTrainingRequestIds(newlineSeparated);
		System.assertEquals(3, result2.size(), 'Should parse 3 IDs from newline-separated list');

		// Test space-separated IDs
		String spaceSeparated = trs[0].Id + ' ' + trs[1].Id + ' ' + trs[2].Id;
		List<String> result3 = SurveyRegenerationController.parseTrainingRequestIds(spaceSeparated);
		System.assertEquals(3, result3.size(), 'Should parse 3 IDs from space-separated list');

		// Test mixed delimiters
		String mixed = trs[0].Id + ', ' + trs[1].Id + '\n' + trs[2].Id;
		List<String> result4 = SurveyRegenerationController.parseTrainingRequestIds(mixed);
		System.assertEquals(3, result4.size(), 'Should parse 3 IDs from mixed delimiters');

		// Test empty content
		List<String> result5 = SurveyRegenerationController.parseTrainingRequestIds('');
		System.assertEquals(0, result5.size(), 'Should return empty list for empty content');

		Test.stopTest();
	}

	/**
	 * @description Test getting surveys for regeneration
	 */
	@isTest
	static void testGetSurveysForRegeneration() {
		// Get training requests
		List<Training_Request__c> trs = [
			SELECT Id, Name, Participant_Survey__c, Customer_Survey__c, Trainer_Survey__c
			FROM Training_Request__c
			LIMIT 2
		];

		List<String> trIds = new List<String>{ String.valueOf(trs[0].Id), String.valueOf(trs[1].Id) };

		Test.startTest();

		// Test with Customer survey type
		List<String> customerTypes = new List<String>{ 'Customer' };
		SurveyRegenerationController.RegenerationResult result1 = SurveyRegenerationController.getSurveysForRegeneration(trIds, customerTypes);
		System.assert(result1.success, 'Should successfully retrieve customer surveys');
		System.assert(result1.surveys.size() > 0, 'Should find at least one survey');

		// Test with multiple survey types
		List<String> multipleTypes = new List<String>{ 'Customer', 'Trainer', 'Participant' };
		SurveyRegenerationController.RegenerationResult result2 = SurveyRegenerationController.getSurveysForRegeneration(trIds, multipleTypes);
		System.assert(result2.success, 'Should successfully retrieve multiple survey types');
		System.assert(result2.surveys.size() > 0, 'Should find surveys');

		// Test with empty IDs
		SurveyRegenerationController.RegenerationResult result3 = SurveyRegenerationController.getSurveysForRegeneration(new List<String>(), customerTypes);
		System.assertEquals(false, result3.success, 'Should fail with empty IDs');

		// Test with empty survey types
		SurveyRegenerationController.RegenerationResult result4 = SurveyRegenerationController.getSurveysForRegeneration(trIds, new List<String>());
		System.assertEquals(false, result4.success, 'Should fail with empty survey types');

		Test.stopTest();
	}

	/**
	 * @description Test regenerating survey invitations for customer/trainer surveys
	 */
	@isTest
	static void testRegenerateSingleSurveyInvitations() {
		// Get training request with surveys
		Training_Request__c tr = [
			SELECT Id, Customer_Survey__c, Trainer_Survey__c
			FROM Training_Request__c
			WHERE Customer_Survey__c != NULL
			LIMIT 1
		];

		// Extract survey ID from URL
		String customerSurveyUrl = tr.Customer_Survey__c;
		String surveyIdStr = customerSurveyUrl.substringAfter('id=').substringBefore('&');
		Id surveyId = (Id) surveyIdStr;

		Test.startTest();

		// Test regenerating customer survey invitations
		List<String> surveyIds = new List<String>{ String.valueOf(surveyId) };
		List<String> surveyTypes = new List<String>{ 'Customer' };

		SurveyRegenerationController.RegenerationResult result = SurveyRegenerationController.regenerateSurveyInvitations(surveyIds, surveyTypes);

		Test.stopTest();

		System.assert(result.success || result.successCount > 0, 'Should regenerate invitations successfully');
		System.assertEquals(1, result.totalProcessed, 'Should process 1 survey');

		// Verify invitation was created
		List<SurveyInvitation__c> invitations = [
			SELECT Id, Survey__c, Status__c
			FROM SurveyInvitation__c
			WHERE Survey__c = :surveyId
			WITH USER_MODE
		];
		System.assert(invitations.size() > 0, 'Should create at least one invitation');
	}

	/**
	 * @description Test regenerating participant survey invitations
	 */
	@isTest
	static void testRegenerateParticipantSurveyInvitations() {
		// Get training request
		Training_Request__c tr = [
			SELECT Id, Participant_Survey__c
			FROM Training_Request__c
			WHERE Participant_Survey__c != NULL
			LIMIT 1
		];

		// Create participants
		List<Participants__c> participants = new List<Participants__c>();
		for (Integer i = 0; i < 3; i++) {
			Participants__c p = new Participants__c();
			p.Training_Request__c = tr.Id;
			p.Participant_Name__c = 'Test Participant ' + i;
			p.Email__c = 'test' + i + '@example.com';
			participants.add(p);
		}
		insert participants;

		// Wait for trigger to create invitations
		Test.getEventBus().deliver();

		// Extract survey ID
		String participantSurveyUrl = tr.Participant_Survey__c;
		String surveyIdStr = participantSurveyUrl.substringAfter('id=');
		if (surveyIdStr.contains('&')) {
			surveyIdStr = surveyIdStr.substringBefore('&');
		}
		Id surveyId = (Id) surveyIdStr;

		// Get initial invitation count
		Integer initialCount = [SELECT COUNT() FROM SurveyInvitation__c WHERE Survey__c = :surveyId WITH USER_MODE];

		Test.startTest();

		// Regenerate invitations
		List<String> surveyIds = new List<String>{ String.valueOf(surveyId) };
		List<String> surveyTypes = new List<String>{ 'Participant' };

		SurveyRegenerationController.RegenerationResult result = SurveyRegenerationController.regenerateSurveyInvitations(surveyIds, surveyTypes);

		Test.stopTest();

		System.assert(result.success || result.successCount > 0, 'Should regenerate participant invitations');

		// Verify invitations were recreated
		Integer finalCount = [SELECT COUNT() FROM SurveyInvitation__c WHERE Survey__c = :surveyId WITH USER_MODE];
		System.assert(finalCount >= participants.size(), 'Should have invitations for all participants');
	}

	/**
	 * @description Test error handling with invalid data
	 */
	@isTest
	static void testErrorHandling() {
		Test.startTest();

		// Test with invalid survey IDs
		List<String> invalidIds = new List<String>{ 'invalid_id' };
		List<String> surveyTypes = new List<String>{ 'Customer' };

		SurveyRegenerationController.RegenerationResult result1 = SurveyRegenerationController.regenerateSurveyInvitations(invalidIds, surveyTypes);
		System.assertEquals(false, result1.success, 'Should fail with invalid IDs');
		System.assert(result1.errors.size() > 0, 'Should have error messages');

		// Test with mismatched array sizes
		List<String> validIds = new List<String>{ '001000000000001' };
		List<String> mismatchedTypes = new List<String>{ 'Customer', 'Trainer' };

		SurveyRegenerationController.RegenerationResult result2 = SurveyRegenerationController.regenerateSurveyInvitations(validIds, mismatchedTypes);
		System.assertEquals(false, result2.success, 'Should fail with mismatched arrays');

		Test.stopTest();
	}

	/**
	 * @description Test bulk regeneration with multiple surveys
	 */
	@isTest
	static void testBulkRegeneration() {
		// Get training requests
		List<Training_Request__c> trs = [
			SELECT Id, Customer_Survey__c, Trainer_Survey__c
			FROM Training_Request__c
			WHERE Customer_Survey__c != NULL
			LIMIT 2
		];

		// Extract survey IDs
		List<String> surveyIds = new List<String>();
		List<String> surveyTypes = new List<String>();

		for (Training_Request__c tr : trs) {
			String customerSurveyUrl = tr.Customer_Survey__c;
			String surveyIdStr = customerSurveyUrl.substringAfter('id=');
			if (surveyIdStr.contains('&')) {
				surveyIdStr = surveyIdStr.substringBefore('&');
			}
			surveyIds.add(surveyIdStr);
			surveyTypes.add('Customer');
		}

		Test.startTest();

		SurveyRegenerationController.RegenerationResult result = SurveyRegenerationController.regenerateSurveyInvitations(surveyIds, surveyTypes);

		Test.stopTest();

		System.assert(result.totalProcessed > 0, 'Should process multiple surveys');
		System.assert(result.successCount > 0, 'Should have some successes');
	}
}