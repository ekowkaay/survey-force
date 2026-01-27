/**
 * @description Test class for SurveyRegenerationBatch
 */
@isTest
private class SurveyRegenerationBatch_Test {
	@TestSetup
	static void setup() {
		// Create test data using SurveyTestingUtil
		Training_Request__c tr = SurveyTestingUtil.createTrainingRequest();
		insert tr;

		Survey__c survey = SurveyTestingUtil.createSurvey();
		insert survey;

		// Create survey URL for training request
		tr.Customer_Survey__c = '/apex/ViewSurvey?id=' + survey.Id;
		update tr;
	}

	@isTest
	static void testBatchProcessing() {
		// Get test data
		Training_Request__c tr = [SELECT Id, Customer_Survey__c FROM Training_Request__c LIMIT 1];
		Survey__c survey = [SELECT Id, Name FROM Survey__c LIMIT 1];

		// Create survey data for batch processing
		SurveyRegenerationController.SurveyData surveyData = new SurveyRegenerationController.SurveyData();
		surveyData.trainingRequestId = tr.Id;
		surveyData.trainingRequestName = 'Test TR';
		surveyData.surveyId = survey.Id;
		surveyData.surveyName = survey.Name;
		surveyData.surveyType = SurveyForceConstants.SURVEY_TYPE_CUSTOMER;
		surveyData.invitationCount = 0;

		List<SurveyRegenerationController.SurveyData> surveysToProcess = new List<SurveyRegenerationController.SurveyData>{ surveyData };

		Test.startTest();
		// Execute batch
		SurveyRegenerationBatch batchJob = new SurveyRegenerationBatch(surveysToProcess);
		Id batchJobId = Database.executeBatch(batchJob, 10);
		Test.stopTest();

		// Verify batch job was queued
		System.assertNotEquals(null, batchJobId, 'Batch job ID should not be null');

		// Verify invitations were created
		List<SurveyInvitation__c> invitations = [
			SELECT Id, Survey__c, Status__c
			FROM SurveyInvitation__c
			WHERE Survey__c = :survey.Id
		];
		System.assert(!invitations.isEmpty(), 'At least one invitation should be created');
	}

	@isTest
	static void testBatchWithMultipleSurveys() {
		// Get test data
		Training_Request__c tr = [SELECT Id, Customer_Survey__c FROM Training_Request__c LIMIT 1];

		// Create multiple surveys
		List<Survey__c> surveys = new List<Survey__c>();
		for (Integer i = 0; i < 5; i++) {
			surveys.add(SurveyTestingUtil.createSurvey());
		}
		insert surveys;

		// Create survey data for batch processing
		List<SurveyRegenerationController.SurveyData> surveysToProcess = new List<SurveyRegenerationController.SurveyData>();
		for (Survey__c survey : surveys) {
			SurveyRegenerationController.SurveyData surveyData = new SurveyRegenerationController.SurveyData();
			surveyData.trainingRequestId = tr.Id;
			surveyData.trainingRequestName = 'Test TR';
			surveyData.surveyId = survey.Id;
			surveyData.surveyName = survey.Name;
			surveyData.surveyType = SurveyForceConstants.SURVEY_TYPE_CUSTOMER;
			surveyData.invitationCount = 0;
			surveysToProcess.add(surveyData);
		}

		Test.startTest();
		// Execute batch
		SurveyRegenerationBatch batchJob = new SurveyRegenerationBatch(surveysToProcess);
		Id batchJobId = Database.executeBatch(batchJob, 2); // Process 2 at a time
		Test.stopTest();

		// Verify batch job was queued
		System.assertNotEquals(null, batchJobId, 'Batch job ID should not be null');

		// Verify invitations were created for all surveys
		List<SurveyInvitation__c> invitations = [
			SELECT Id, Survey__c
			FROM SurveyInvitation__c
			WHERE Survey__c IN :surveys
		];
		System.assertEquals(5, invitations.size(), 'Should create 5 invitations, one for each survey');
	}

	@isTest
	static void testAutoAsyncProcessing() {
		// Get test data
		Training_Request__c tr = [SELECT Id, Customer_Survey__c FROM Training_Request__c LIMIT 1];

		// Create more than MAX_SYNC_REGENERATION_LIMIT surveys (51 surveys)
		List<Survey__c> surveys = new List<Survey__c>();
		for (Integer i = 0; i < 51; i++) {
			surveys.add(SurveyTestingUtil.createSurvey());
		}
		insert surveys;

		// Prepare survey IDs and types
		List<String> surveyIds = new List<String>();
		List<String> surveyTypes = new List<String>();
		for (Survey__c survey : surveys) {
			surveyIds.add(survey.Id);
			surveyTypes.add(SurveyForceConstants.SURVEY_TYPE_CUSTOMER);
		}

		Test.startTest();
		// Call regeneration - should automatically trigger batch processing
		SurveyRegenerationController.RegenerationResult result = SurveyRegenerationController.regenerateSurveyInvitations(surveyIds, surveyTypes);
		Test.stopTest();

		// Verify batch processing was initiated
		System.assertEquals(true, result.success, 'Batch initiation should be successful');
		System.assert(result.message.contains('Batch regeneration initiated'), 'Message should indicate batch processing');
		System.assert(result.message.contains('Job ID'), 'Message should include batch job ID');
		System.assertEquals(51, result.totalProcessed, 'Should process 51 surveys');
	}

	@isTest
	static void testSyncProcessingWithinLimit() {
		// Get test data
		Training_Request__c tr = [SELECT Id, Customer_Survey__c FROM Training_Request__c LIMIT 1];

		// Create surveys within sync limit (5 surveys)
		List<Survey__c> surveys = new List<Survey__c>();
		for (Integer i = 0; i < 5; i++) {
			surveys.add(SurveyTestingUtil.createSurvey());
		}
		insert surveys;

		// Prepare survey IDs and types
		List<String> surveyIds = new List<String>();
		List<String> surveyTypes = new List<String>();
		for (Survey__c survey : surveys) {
			surveyIds.add(survey.Id);
			surveyTypes.add(SurveyForceConstants.SURVEY_TYPE_CUSTOMER);
		}

		Test.startTest();
		// Call regeneration - should process synchronously
		SurveyRegenerationController.RegenerationResult result = SurveyRegenerationController.regenerateSurveyInvitations(surveyIds, surveyTypes);
		Test.stopTest();

		// Verify synchronous processing was used
		System.assert(!result.message.contains('Batch'), 'Should not mention batch processing');
		System.assert(result.message.contains('complete'), 'Should indicate completion');
	}
}