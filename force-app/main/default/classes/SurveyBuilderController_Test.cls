/**
 * Test class for SurveyBuilderController
 * Tests question CRUD operations and reordering
 */
@isTest
private class SurveyBuilderController_Test {
	@TestSetup
	static void setupTestData() {
		// Create test survey
		Survey__c testSurvey = new Survey__c();
		testSurvey.Name = 'Test Survey for Builder';
		insert testSurvey;

		// Create test questions
		List<Survey_Question__c> questions = new List<Survey_Question__c>();
		for (Integer i = 1; i <= 3; i++) {
			Survey_Question__c q = new Survey_Question__c();
			q.Survey__c = testSurvey.Id;
			q.Question__c = 'Test Question ' + i;
			q.Type__c = 'Free Text';
			q.OrderNumber__c = i;
			q.Required__c = false;
			questions.add(q);
		}
		insert questions;
	}

	@isTest
	static void testCreateQuestion() {
		Survey__c survey = [SELECT Id FROM Survey__c WHERE Name = 'Test Survey for Builder' LIMIT 1];

		Map<String, Object> questionData = new Map<String, Object>{
			'Question__c' => 'New Test Question',
			'Type__c' => 'Single Select--Vertical',
			'Required__c' => true,
			'Choices__c' => 'Option 1\nOption 2\nOption 3',
			'OrderNumber__c' => 4,
			'Survey__c' => survey.Id
		};

		Test.startTest();
		Id questionId = SurveyBuilderController.createQuestion(questionData);
		Test.stopTest();

		System.assertNotEquals(null, questionId, 'Question ID should not be null');

		Survey_Question__c createdQuestion = [SELECT Question__c, Type__c, Required__c, Choices__c, OrderNumber__c FROM Survey_Question__c WHERE Id = :questionId];
		System.assertEquals('New Test Question', createdQuestion.Question__c, 'Question text should match');
		System.assertEquals('Single Select--Vertical', createdQuestion.Type__c, 'Question type should match');
		System.assertEquals(true, createdQuestion.Required__c, 'Required should be true');
		System.assertEquals('Option 1\nOption 2\nOption 3', createdQuestion.Choices__c, 'Choices should match');
		System.assertEquals(4, createdQuestion.OrderNumber__c, 'Order number should match');
	}

	@isTest
	static void testCreateQuestionWithDefaultValues() {
		Survey__c survey = [SELECT Id FROM Survey__c WHERE Name = 'Test Survey for Builder' LIMIT 1];

		Map<String, Object> questionData = new Map<String, Object>{ 'Question__c' => 'Minimal Question', 'Type__c' => 'Free Text', 'Survey__c' => survey.Id };

		Test.startTest();
		Id questionId = SurveyBuilderController.createQuestion(questionData);
		Test.stopTest();

		System.assertNotEquals(null, questionId, 'Question ID should not be null');

		Survey_Question__c createdQuestion = [SELECT Required__c, OrderNumber__c FROM Survey_Question__c WHERE Id = :questionId];
		System.assertEquals(false, createdQuestion.Required__c, 'Required should default to false');
		System.assertEquals(1, createdQuestion.OrderNumber__c, 'Order number should default to 1');
	}

	@isTest
	static void testUpdateQuestion() {
		Survey_Question__c question = [SELECT Id FROM Survey_Question__c WHERE Question__c = 'Test Question 1' LIMIT 1];

		Map<String, Object> questionData = new Map<String, Object>{
			'Id' => question.Id,
			'Question__c' => 'Updated Question Text',
			'Type__c' => 'Multi-Select--Vertical',
			'Required__c' => true,
			'Choices__c' => 'Choice A\nChoice B',
			'OrderNumber__c' => 10,
			'Hide_on_Survey__c' => true
		};

		Test.startTest();
		String result = SurveyBuilderController.updateQuestion(questionData);
		Test.stopTest();

		System.assertEquals('Question updated successfully', result, 'Update should succeed');

		Survey_Question__c updatedQuestion = [SELECT Question__c, Type__c, Required__c, Choices__c, OrderNumber__c, Hide_on_Survey__c FROM Survey_Question__c WHERE Id = :question.Id];
		System.assertEquals('Updated Question Text', updatedQuestion.Question__c, 'Question text should be updated');
		System.assertEquals('Multi-Select--Vertical', updatedQuestion.Type__c, 'Type should be updated');
		System.assertEquals(true, updatedQuestion.Required__c, 'Required should be updated');
		System.assertEquals('Choice A\nChoice B', updatedQuestion.Choices__c, 'Choices should be updated');
		System.assertEquals(10, updatedQuestion.OrderNumber__c, 'Order number should be updated');
		System.assertEquals(true, updatedQuestion.Hide_on_Survey__c, 'Hide on survey should be updated');
	}

	@isTest
	static void testReorderQuestions() {
		List<Survey_Question__c> questions = [SELECT Id, OrderNumber__c FROM Survey_Question__c ORDER BY OrderNumber__c ASC];

		// Reverse the order
		List<Id> questionIds = new List<Id>();
		for (Integer i = questions.size() - 1; i >= 0; i--) {
			questionIds.add(questions[i].Id);
		}

		Test.startTest();
		String result = SurveyBuilderController.reorderQuestions(questionIds);
		Test.stopTest();

		System.assertEquals('Questions reordered successfully', result, 'Reorder should succeed');

		List<Survey_Question__c> reorderedQuestions = [SELECT Id, OrderNumber__c FROM Survey_Question__c ORDER BY OrderNumber__c ASC];

		// Verify the order is reversed
		System.assertEquals(questions[2].Id, reorderedQuestions[0].Id, 'First question should now be third');
		System.assertEquals(questions[1].Id, reorderedQuestions[1].Id, 'Second question should remain second');
		System.assertEquals(questions[0].Id, reorderedQuestions[2].Id, 'Third question should now be first');
	}

	@isTest
	static void testReorderQuestionsEmptyList() {
		List<Id> emptyList = new List<Id>();

		Test.startTest();
		String result = SurveyBuilderController.reorderQuestions(emptyList);
		Test.stopTest();

		System.assertEquals('Questions reordered successfully', result, 'Empty list should succeed');
	}

	@isTest
	static void testGetQuestionTypes() {
		Test.startTest();
		List<Map<String, String>> types = SurveyBuilderController.getQuestionTypes();
		Test.stopTest();

		System.assertEquals(4, types.size(), 'Should return 4 question types');

		// Verify expected types exist
		Set<String> expectedValues = new Set<String>{ 'Free Text', 'Single Select--Vertical', 'Single Select--Horizontal', 'Multi-Select--Vertical' };

		for (Map<String, String> typeOption : types) {
			System.assert(typeOption.containsKey('label'), 'Each type should have a label');
			System.assert(typeOption.containsKey('value'), 'Each type should have a value');
			System.assert(expectedValues.contains(typeOption.get('value')), 'Value should be a valid question type');
		}
	}

	@isTest
	static void testDuplicateQuestion() {
		Survey_Question__c originalQuestion = [SELECT Id, Question__c, Survey__c FROM Survey_Question__c WHERE Question__c = 'Test Question 1' LIMIT 1];

		Test.startTest();
		Id duplicateId = SurveyBuilderController.duplicateQuestion(originalQuestion.Id);
		Test.stopTest();

		System.assertNotEquals(null, duplicateId, 'Duplicate ID should not be null');
		System.assertNotEquals(originalQuestion.Id, duplicateId, 'Duplicate ID should be different from original');

		Survey_Question__c duplicate = [SELECT Question__c, Survey__c, OrderNumber__c FROM Survey_Question__c WHERE Id = :duplicateId];
		System.assertEquals('Copy of Test Question 1', duplicate.Question__c, 'Duplicate should have "Copy of" prefix');
		System.assertEquals(originalQuestion.Survey__c, duplicate.Survey__c, 'Duplicate should be in same survey');
		System.assertEquals(4, duplicate.OrderNumber__c, 'Duplicate should have next order number');
	}

	@isTest
	static void testDuplicateQuestionWithChoices() {
		Survey__c survey = [SELECT Id FROM Survey__c WHERE Name = 'Test Survey for Builder' LIMIT 1];

		// Create a question with choices
		Survey_Question__c questionWithChoices = new Survey_Question__c();
		questionWithChoices.Survey__c = survey.Id;
		questionWithChoices.Question__c = 'Question With Choices';
		questionWithChoices.Type__c = 'Single Select--Vertical';
		questionWithChoices.Choices__c = 'Option A\nOption B\nOption C';
		questionWithChoices.Required__c = true;
		questionWithChoices.OrderNumber__c = 10;
		insert questionWithChoices;

		Test.startTest();
		Id duplicateId = SurveyBuilderController.duplicateQuestion(questionWithChoices.Id);
		Test.stopTest();

		Survey_Question__c duplicate = [SELECT Type__c, Choices__c, Required__c FROM Survey_Question__c WHERE Id = :duplicateId];
		System.assertEquals('Single Select--Vertical', duplicate.Type__c, 'Type should be copied');
		System.assertEquals('Option A\nOption B\nOption C', duplicate.Choices__c, 'Choices should be copied');
		System.assertEquals(true, duplicate.Required__c, 'Required should be copied');
	}

	@isTest
	static void testCreateQuestionError() {
		// Test with invalid data (null survey ID)
		Map<String, Object> questionData = new Map<String, Object>{ 'Question__c' => 'Test Question', 'Type__c' => 'Free Text', 'Survey__c' => null };

		Test.startTest();
		try {
			SurveyBuilderController.createQuestion(questionData);
			System.assert(false, 'Should have thrown an exception');
		} catch (AuraHandledException e) {
			System.assert(e.getMessage().contains('Error creating question'), 'Should contain error message');
		}
		Test.stopTest();
	}

	@isTest
	static void testUpdateQuestionPartialFields() {
		Survey_Question__c question = [SELECT Id, Question__c, Type__c FROM Survey_Question__c WHERE Question__c = 'Test Question 2' LIMIT 1];
		String originalType = question.Type__c;

		// Only update the question text
		Map<String, Object> questionData = new Map<String, Object>{ 'Id' => question.Id, 'Question__c' => 'Partially Updated Question' };

		Test.startTest();
		String result = SurveyBuilderController.updateQuestion(questionData);
		Test.stopTest();

		System.assertEquals('Question updated successfully', result, 'Partial update should succeed');

		Survey_Question__c updatedQuestion = [SELECT Question__c, Type__c FROM Survey_Question__c WHERE Id = :question.Id];
		System.assertEquals('Partially Updated Question', updatedQuestion.Question__c, 'Question text should be updated');
		System.assertEquals(originalType, updatedQuestion.Type__c, 'Type should remain unchanged');
	}
}