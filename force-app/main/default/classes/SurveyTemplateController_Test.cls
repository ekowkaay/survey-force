/**
 * Test class for SurveyTemplateController
 * Tests survey listing, deletion, statistics, and search
 */
@isTest
private class SurveyTemplateController_Test {
	@TestSetup
	static void setupTestData() {
		// Create test surveys
		List<Survey__c> surveys = new List<Survey__c>();
		for (Integer i = 1; i <= 5; i++) {
			Survey__c survey = new Survey__c();
			survey.Name = 'Test Survey ' + i;
			survey.Share_with_Guest_User__c = (Math.mod(i, 2) == 0);
			surveys.add(survey);
		}
		insert surveys;

		// Create test questions for first survey
		List<Survey_Question__c> questions = new List<Survey_Question__c>();
		for (Integer i = 1; i <= 3; i++) {
			Survey_Question__c q = new Survey_Question__c();
			q.Survey__c = surveys[0].Id;
			q.Question__c = 'Question ' + i;
			q.Type__c = 'Free Text';
			q.OrderNumber__c = i;
			questions.add(q);
		}
		insert questions;

		// Create test survey taker
		SurveyTaker__c taker = new SurveyTaker__c();
		taker.Survey__c = surveys[0].Id;
		taker.Completed__c = true;
		insert taker;
	}

	@isTest
	static void testGetAllSurveys() {
		Test.startTest();
		List<Survey__c> surveys = SurveyTemplateController.getAllSurveys();
		Test.stopTest();

		System.assertEquals(5, surveys.size(), 'Should return all 5 surveys');

		// Verify ordering (most recent first)
		Boolean isOrderedDesc = true;
		for (Integer i = 1; i < surveys.size(); i++) {
			if (surveys[i].CreatedDate > surveys[i - 1].CreatedDate) {
				isOrderedDesc = false;
				break;
			}
		}
		System.assert(isOrderedDesc, 'Surveys should be ordered by CreatedDate DESC');
	}

	@isTest
	static void testDeleteSurvey() {
		Survey__c surveyToDelete = [SELECT Id FROM Survey__c WHERE Name = 'Test Survey 5' LIMIT 1];

		Test.startTest();
		String result = SurveyTemplateController.deleteSurvey(surveyToDelete.Id);
		Test.stopTest();

		System.assertEquals('Survey deleted successfully', result, 'Delete should succeed');

		List<Survey__c> remainingSurveys = [SELECT Id FROM Survey__c];
		System.assertEquals(4, remainingSurveys.size(), 'Should have 4 surveys remaining');
	}

	@isTest
	static void testDeleteSurveyWithQuestions() {
		Survey__c surveyWithQuestions = [SELECT Id FROM Survey__c WHERE Name = 'Test Survey 1' LIMIT 1];

		// Verify questions exist before deletion
		Integer questionsBefore = [SELECT COUNT() FROM Survey_Question__c WHERE Survey__c = :surveyWithQuestions.Id];
		System.assertEquals(3, questionsBefore, 'Should have 3 questions before deletion');

		Test.startTest();
		String result = SurveyTemplateController.deleteSurvey(surveyWithQuestions.Id);
		Test.stopTest();

		System.assertEquals('Survey deleted successfully', result, 'Delete should succeed');

		// Verify cascade deletion
		Integer questionsAfter = [SELECT COUNT() FROM Survey_Question__c WHERE Survey__c = :surveyWithQuestions.Id];
		System.assertEquals(0, questionsAfter, 'Questions should be deleted with survey');
	}

	@isTest
	static void testGetSurveyStatistics() {
		Test.startTest();
		Map<String, Integer> stats = SurveyTemplateController.getSurveyStatistics();
		Test.stopTest();

		System.assertEquals(5, stats.get('totalSurveys'), 'Should have 5 surveys');
		System.assertEquals(3, stats.get('totalQuestions'), 'Should have 3 questions');
		System.assertEquals(1, stats.get('totalResponses'), 'Should have 1 response');
	}

	@isTest
	static void testSearchSurveys() {
		Test.startTest();
		List<Survey__c> results = SurveyTemplateController.searchSurveys('Survey 1');
		Test.stopTest();

		System.assertEquals(1, results.size(), 'Should find 1 survey matching "Survey 1"');
		System.assertEquals('Test Survey 1', results[0].Name, 'Should find Test Survey 1');
	}

	@isTest
	static void testSearchSurveysPartialMatch() {
		Test.startTest();
		List<Survey__c> results = SurveyTemplateController.searchSurveys('Test');
		Test.stopTest();

		System.assertEquals(5, results.size(), 'Should find all 5 surveys matching "Test"');
	}

	@isTest
	static void testSearchSurveysNoMatch() {
		Test.startTest();
		List<Survey__c> results = SurveyTemplateController.searchSurveys('NonExistent');
		Test.stopTest();

		System.assertEquals(0, results.size(), 'Should find no surveys matching "NonExistent"');
	}

	@isTest
	static void testSearchSurveysEmptyTerm() {
		Test.startTest();
		List<Survey__c> results = SurveyTemplateController.searchSurveys('');
		Test.stopTest();

		System.assertEquals(5, results.size(), 'Empty search should return all surveys');
	}

	@isTest
	static void testSearchSurveysNullTerm() {
		Test.startTest();
		List<Survey__c> results = SurveyTemplateController.searchSurveys(null);
		Test.stopTest();

		System.assertEquals(5, results.size(), 'Null search should return all surveys');
	}

	@isTest
	static void testSearchSurveysSpecialCharacters() {
		// Create survey with special characters in name
		Survey__c specialSurvey = new Survey__c();
		specialSurvey.Name = 'Test\'s Special Survey';
		insert specialSurvey;

		Test.startTest();
		List<Survey__c> results = SurveyTemplateController.searchSurveys('Test\'s');
		Test.stopTest();

		System.assertEquals(1, results.size(), 'Should find survey with special characters');
	}
}