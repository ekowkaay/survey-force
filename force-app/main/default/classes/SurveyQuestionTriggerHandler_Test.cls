/**
 * @description Test class for SurveyQuestionTriggerHandler
 * Validates automatic name field population from question text
 */
@IsTest
private class SurveyQuestionTriggerHandler_Test {
	/**
	 * @description Test setup - creates test survey
	 */
	@TestSetup
	static void setupTestData() {
		// Create test survey
		Survey__c testSurvey = new Survey__c(Name = 'Test Survey for Questions');
		insert testSurvey;
	}

	/**
	 * @description Test name field is set from question on insert
	 */
	@IsTest
	static void testBeforeInsertSetsName() {
		// Setup
		Survey__c survey = [SELECT Id FROM Survey__c LIMIT 1];

		// Test
		Test.startTest();
		Survey_Question__c question = new Survey_Question__c();
		question.Survey__c = survey.Id;
		question.Question__c = 'What is your favorite color?';
		question.Type__c = 'Free Text';
		insert question;
		Test.stopTest();

		// Assert
		Survey_Question__c inserted = [SELECT Id, Name, Question__c FROM Survey_Question__c WHERE Id = :question.Id];
		System.assertEquals('What is your favorite color?', inserted.Name, 'Name should be set from question text');
	}

	/**
	 * @description Test name field is truncated when question is too long
	 */
	@IsTest
	static void testBeforeInsertTruncatesLongQuestion() {
		// Setup
		Survey__c survey = [SELECT Id FROM Survey__c LIMIT 1];
		String longQuestion = 'This is a very long question that exceeds the maximum length allowed for the name field which is 80 characters';

		// Test
		Test.startTest();
		Survey_Question__c question = new Survey_Question__c();
		question.Survey__c = survey.Id;
		question.Question__c = longQuestion;
		question.Type__c = 'Free Text';
		insert question;
		Test.stopTest();

		// Assert
		Survey_Question__c inserted = [SELECT Id, Name, Question__c FROM Survey_Question__c WHERE Id = :question.Id];
		System.assertEquals(79, inserted.Name.length(), 'Name should be truncated to 79 characters');
		System.assert(inserted.Name.startsWith('This is a very long question'), 'Name should start with question text');
	}

	/**
	 * @description Test apostrophes are preserved in name field (not escaped)
	 */
	@IsTest
	static void testBeforeInsertPreservesApostrophes() {
		// Setup
		Survey__c survey = [SELECT Id FROM Survey__c LIMIT 1];

		// Test
		Test.startTest();
		Survey_Question__c question = new Survey_Question__c();
		question.Survey__c = survey.Id;
		question.Question__c = 'What\'s your role?';
		question.Type__c = 'Free Text';
		insert question;
		Test.stopTest();

		// Assert - Name should preserve the apostrophe without escaping
		Survey_Question__c inserted = [SELECT Id, Name, Question__c FROM Survey_Question__c WHERE Id = :question.Id];
		System.assertEquals('What\'s your role?', inserted.Name, 'Name should preserve apostrophe without backslash escape');
		System.assert(!inserted.Name.contains('\\'), 'Name should not contain escaped backslash');
	}

	/**
	 * @description Test name field is updated on question text change
	 */
	@IsTest
	static void testBeforeUpdateSetsName() {
		// Setup
		Survey__c survey = [SELECT Id FROM Survey__c LIMIT 1];
		Survey_Question__c question = new Survey_Question__c();
		question.Survey__c = survey.Id;
		question.Question__c = 'Original question text';
		question.Type__c = 'Free Text';
		insert question;

		// Test
		Test.startTest();
		question.Question__c = 'Updated question text';
		update question;
		Test.stopTest();

		// Assert
		Survey_Question__c updated = [SELECT Id, Name, Question__c FROM Survey_Question__c WHERE Id = :question.Id];
		System.assertEquals('Updated question text', updated.Name, 'Name should be updated from new question text');
	}

	/**
	 * @description Test bulk insert of questions
	 */
	@IsTest
	static void testBulkInsert() {
		// Setup
		Survey__c survey = [SELECT Id FROM Survey__c LIMIT 1];
		List<Survey_Question__c> questions = new List<Survey_Question__c>();

		for (Integer i = 0; i < 20; i++) {
			Survey_Question__c q = new Survey_Question__c();
			q.Survey__c = survey.Id;
			q.Question__c = 'Question ' + i + '?';
			q.Type__c = 'Free Text';
			q.OrderNumber__c = i;
			questions.add(q);
		}

		// Test
		Test.startTest();
		insert questions;
		Test.stopTest();

		// Assert
		List<Survey_Question__c> inserted = [SELECT Id, Name, Question__c FROM Survey_Question__c WHERE Survey__c = :survey.Id ORDER BY OrderNumber__c];
		System.assertEquals(20, inserted.size(), 'All questions should be inserted');

		for (Integer i = 0; i < 20; i++) {
			System.assertEquals('Question ' + i + '?', inserted[i].Name, 'Name should match question text for item ' + i);
		}
	}

	/**
	 * @description Test blank question text doesn't cause errors
	 */
	@IsTest
	static void testBlankQuestionText() {
		// Setup
		Survey__c survey = [SELECT Id FROM Survey__c LIMIT 1];

		// Test
		Test.startTest();
		Survey_Question__c question = new Survey_Question__c();
		question.Survey__c = survey.Id;
		question.Question__c = '';
		question.Type__c = 'Free Text';

		// Insert should succeed without errors
		insert question;
		Test.stopTest();

		// Assert - just verify no exception was thrown
		Survey_Question__c inserted = [SELECT Id, Name FROM Survey_Question__c WHERE Id = :question.Id];
		System.assertNotEquals(null, inserted, 'Question should be inserted');
	}

	/**
	 * @description Test recursion prevention
	 */
	@IsTest
	static void testRecursionPrevention() {
		// Setup
		Survey__c survey = [SELECT Id FROM Survey__c LIMIT 1];
		Survey_Question__c question = new Survey_Question__c();
		question.Survey__c = survey.Id;
		question.Question__c = 'Test question';
		question.Type__c = 'Free Text';
		insert question;

		// Test - multiple updates should not cause recursion issues
		Test.startTest();
		for (Integer i = 0; i < 5; i++) {
			question.Question__c = 'Updated ' + i;
			update question;
		}
		Test.stopTest();

		// Assert - should complete without hitting governor limits
		Survey_Question__c final_q = [SELECT Id, Name FROM Survey_Question__c WHERE Id = :question.Id];
		System.assertEquals('Updated 4', final_q.Name, 'Final name should reflect last update');
	}
}
