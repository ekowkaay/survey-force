/**
 * Test class for SurveyHomeController
 */
@isTest
private class SurveyHomeController_Test {
	@TestSetup
	static void setupTestData() {
		// Create test surveys with different states
		List<Survey__c> surveys = new List<Survey__c>();

		// Draft survey (no questions)
		Survey__c draft = new Survey__c(Name = 'Draft Survey');
		surveys.add(draft);

		// Ready to launch survey (has questions, no responses)
		Survey__c ready = new Survey__c(Name = 'Ready Survey');
		surveys.add(ready);

		// Active survey (has questions and responses)
		Survey__c active = new Survey__c(Name = 'Active Survey');
		surveys.add(active);

		insert surveys;

		// Create questions for the surveys
		List<Survey_Question__c> questions = new List<Survey_Question__c>();

		// Ready survey - 5 questions
		for (Integer i = 0; i < 5; i++) {
			questions.add(new Survey_Question__c(Survey__c = ready.Id, Question__c = 'Question ' + i, Type__c = 'Free Text'));
		}

		// Active survey - 3 questions
		for (Integer i = 0; i < 3; i++) {
			questions.add(new Survey_Question__c(Survey__c = active.Id, Question__c = 'Question ' + i, Type__c = 'Free Text'));
		}

		insert questions;

		// Stalled survey (has questions, no responses, created 40 days ago)
		// Use Test.setCreatedDate to simulate older record
		Survey__c stalled = new Survey__c(Name = 'Stalled Survey');
		insert stalled;
		Test.setCreatedDate(stalled.Id, DateTime.now().addDays(-40));

		// Create questions for stalled survey
		List<Survey_Question__c> stalledQuestions = new List<Survey_Question__c>();
		for (Integer i = 0; i < 2; i++) {
			stalledQuestions.add(new Survey_Question__c(Survey__c = stalled.Id, Question__c = 'Question ' + i, Type__c = 'Free Text'));
		}
		insert stalledQuestions;

		// Create a survey taker for activity
		SurveyTaker__c taker = new SurveyTaker__c(Survey__c = active.Id);
		insert taker;
	}

	@isTest
	static void testGetHomePageData() {
		Test.startTest();
		SurveyHomeController.HomeData result = SurveyHomeController.getHomePageData();
		Test.stopTest();

		// Verify totals
		System.assertEquals(4, result.totalSurveys, 'Total surveys should be 4');
		System.assertEquals(1, result.drafts, 'Drafts should be 1');
		System.assertEquals(1, result.readyToLaunch, 'Ready to launch should be 1');
		System.assertEquals(1, result.active, 'Active should be 1');
		System.assertEquals(1, result.stalled, 'Stalled should be 1');

		// Verify activities exist
		System.assertNotEquals(null, result.activities, 'Activities should not be null');
		System.assert(result.activities.size() > 0, 'Should have at least one activity');
	}

	@isTest
	static void testGetHomePageDataNoData() {
		// Delete all test data
		delete [SELECT Id FROM Survey__c];
		delete [SELECT Id FROM SurveyTaker__c];

		Test.startTest();
		SurveyHomeController.HomeData result = SurveyHomeController.getHomePageData();
		Test.stopTest();

		// Verify empty state
		System.assertEquals(0, result.totalSurveys, 'Total surveys should be 0');
		System.assertEquals(0, result.drafts, 'Drafts should be 0');
		System.assertEquals(0, result.readyToLaunch, 'Ready to launch should be 0');
		System.assertEquals(0, result.active, 'Active should be 0');
		System.assertEquals(0, result.stalled, 'Stalled should be 0');
		System.assertEquals(0, result.activities.size(), 'Activities should be empty');
	}

	@isTest
	static void testActivitySorting() {
		Test.startTest();
		SurveyHomeController.HomeData result = SurveyHomeController.getHomePageData();
		Test.stopTest();

		// Verify activities are sorted by timestamp descending
		if (result.activities.size() > 1) {
			for (Integer i = 0; i < result.activities.size() - 1; i++) {
				System.assert(result.activities[i].timestamp >= result.activities[i + 1].timestamp, 'Activities should be sorted by timestamp descending');
			}
		}
	}

	@isTest
	static void testActivityLimit() {
		// Create more surveys to generate more activities
		List<Survey__c> extraSurveys = new List<Survey__c>();
		for (Integer i = 0; i < 10; i++) {
			extraSurveys.add(new Survey__c(Name = 'Extra Survey ' + i));
		}
		insert extraSurveys;

		// Create questions for each survey
		List<Survey_Question__c> extraQuestions = new List<Survey_Question__c>();
		for (Survey__c survey : extraSurveys) {
			extraQuestions.add(new Survey_Question__c(Survey__c = survey.Id, Question__c = 'Question 1', Type__c = 'Free Text'));
		}
		insert extraQuestions;

		Test.startTest();
		SurveyHomeController.HomeData result = SurveyHomeController.getHomePageData();
		Test.stopTest();

		// Verify activity limit
		System.assert(result.activities.size() <= 5, 'Should return maximum 5 activities');
	}
}