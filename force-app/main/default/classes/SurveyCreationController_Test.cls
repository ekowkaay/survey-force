/**
 * Test class for SurveyCreationController
 */
@IsTest
private class SurveyCreationController_Test {
	@TestSetup
	static void makeData() {
		User u = SurveyTestingUtil.createNewAdminPermissionSetUser();
	}

	@IsTest
	private static void testCheckSiteAvailability() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			Test.startTest();
			SurveyCreationController.SiteInfo siteInfo = SurveyCreationController.checkSiteAvailability();
			Test.stopTest();

			System.assertNotEquals(null, siteInfo, 'Site info should not be null');
			System.assertNotEquals(null, siteInfo.siteNames, 'Site names should not be null');
		}
	}

	@IsTest
	private static void testCreateSurvey() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			String surveyName = 'Test Survey ' + System.now();

			Test.startTest();
			SurveyCreationController.CreationResult result = SurveyCreationController.createSurvey(surveyName);
			Test.stopTest();

			System.assertEquals(true, result.success, 'Creation should succeed');
			System.assertNotEquals(null, result.surveyId, 'Survey ID should not be null');
			System.assert(result.message.contains('success'), 'Message should indicate success');

			// Verify survey was created
			List<Survey__c> surveys = [SELECT Id, Name FROM Survey__c WHERE Id = :result.surveyId];
			System.assertEquals(1, surveys.size(), 'Survey should exist');
			System.assertEquals(surveyName, surveys[0].Name, 'Survey name should match');
		}
	}

	@IsTest
	private static void testCreateSurveyWithoutName() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			Test.startTest();
			SurveyCreationController.CreationResult result = SurveyCreationController.createSurvey('');
			Test.stopTest();

			System.assertEquals(false, result.success, 'Creation should fail');
			System.assert(result.message.contains('required'), 'Message should indicate name is required');
		}
	}

	@IsTest
	private static void testGetRecentSurveys() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Test.startTest();
			List<Survey__c> surveys = SurveyCreationController.getRecentSurveys();
			Test.stopTest();

			System.assertNotEquals(null, surveys, 'Surveys should not be null');
			System.assert(!surveys.isEmpty(), 'Should have at least one survey');
		}
	}

	@IsTest
	private static void testCloneSurvey() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();
			String newSurveyName = 'Cloned Survey ' + System.now();

			Test.startTest();
			SurveyCreationController.CreationResult result = SurveyCreationController.cloneSurvey(tu.surveyId, newSurveyName);
			Test.stopTest();

			System.assertEquals(true, result.success, 'Cloning should succeed');
			System.assertNotEquals(null, result.surveyId, 'New survey ID should not be null');
			System.assertNotEquals(tu.surveyId, result.surveyId, 'New survey should have different ID');

			// Verify survey was cloned
			Survey__c clonedSurvey = [SELECT Id, Name FROM Survey__c WHERE Id = :result.surveyId];
			System.assertEquals(newSurveyName, clonedSurvey.Name, 'Cloned survey name should match');

			// Verify questions were cloned
			Integer originalQuestionCount = [SELECT COUNT() FROM Survey_Question__c WHERE Survey__c = :tu.surveyId];
			Integer clonedQuestionCount = [SELECT COUNT() FROM Survey_Question__c WHERE Survey__c = :result.surveyId];
			System.assertEquals(originalQuestionCount, clonedQuestionCount, 'Question count should match');
		}
	}

	@IsTest
	private static void testCloneSurveyWithoutName() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Test.startTest();
			SurveyCreationController.CreationResult result = SurveyCreationController.cloneSurvey(tu.surveyId, '');
			Test.stopTest();

			System.assertEquals(false, result.success, 'Cloning should fail');
			System.assert(result.message.contains('required'), 'Message should indicate name is required');
		}
	}

	@IsTest
	private static void testGetSurveyDetails() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Test.startTest();
			SurveyCreationController.SurveyDetails details = SurveyCreationController.getSurveyDetails(tu.surveyId);
			Test.stopTest();

			System.assertNotEquals(null, details, 'Survey details should not be null');
			System.assertNotEquals(null, details.survey, 'Survey should not be null');
			System.assertEquals(tu.surveyId, details.survey.Id, 'Survey ID should match');
			System.assertNotEquals(null, details.questions, 'Questions should not be null');
			System.assert(details.questions.size() > 0, 'Should have at least one question');
			System.assertNotEquals(null, details.createdByName, 'Created by name should not be null');
		}
	}

	@IsTest
	private static void testGetSurveyDetailsWithNullId() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			Test.startTest();
			Boolean exceptionThrown = false;
			try {
				SurveyCreationController.SurveyDetails details = SurveyCreationController.getSurveyDetails(null);
			} catch (AuraHandledException e) {
				exceptionThrown = true;
				System.assert(e.getMessage().contains('required'), 'Error should indicate ID is required');
			}
			Test.stopTest();

			System.assert(exceptionThrown, 'Exception should be thrown for null ID');
		}
	}

	@IsTest
	private static void testUpdateSurveyWithDetails() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();
			String updatedName = 'Updated Survey ' + System.now();
			String updatedHeader = 'Updated Header';
			String updatedSubheader = 'Updated Subheader';

			Test.startTest();
			SurveyCreationController.CreationResult result = SurveyCreationController.updateSurveyWithDetails(
				tu.surveyId,
				updatedName,
				updatedHeader,
				updatedSubheader,
				'Thank you for your feedback',
				'https://example.com',
				true,
				true
			);
			Test.stopTest();

			System.assertEquals(true, result.success, 'Update should succeed');
			System.assertEquals(tu.surveyId, result.surveyId, 'Survey ID should match');

			// Verify survey was updated
			Survey__c updatedSurvey = [
				SELECT Id, Name, Survey_Header__c, Survey_Subheader__c, Hide_Survey_Name__c, All_Responses_Anonymous__c
				FROM Survey__c
				WHERE Id = :tu.surveyId
			];
			System.assertEquals(updatedName, updatedSurvey.Name, 'Survey name should be updated');
			System.assertEquals(updatedHeader, updatedSurvey.Survey_Header__c, 'Survey header should be updated');
			System.assertEquals(updatedSubheader, updatedSurvey.Survey_Subheader__c, 'Survey subheader should be updated');
			System.assertEquals(true, updatedSurvey.Hide_Survey_Name__c, 'Hide survey name should be updated');
			System.assertEquals(true, updatedSurvey.All_Responses_Anonymous__c, 'Anonymous option should be updated');
		}
	}

	@IsTest
	private static void testUpdateSurveyWithDetailsNoId() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			Test.startTest();
			SurveyCreationController.CreationResult result = SurveyCreationController.updateSurveyWithDetails(null, 'Test Survey', 'Header', 'Subheader', 'Thank you', '', false, false);
			Test.stopTest();

			System.assertEquals(false, result.success, 'Update should fail without survey ID');
			System.assert(result.message.contains('required'), 'Message should indicate ID is required');
		}
	}

	@IsTest
	private static void testUpdateSurveyWithDetailsNoName() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Test.startTest();
			SurveyCreationController.CreationResult result = SurveyCreationController.updateSurveyWithDetails(tu.surveyId, '', 'Header', 'Subheader', 'Thank you', '', false, false);
			Test.stopTest();

			System.assertEquals(false, result.success, 'Update should fail without survey name');
			System.assert(result.message.contains('required'), 'Message should indicate name is required');
		}
	}

	@IsTest
	private static void testUpdateSurveyQuestions() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Get original question count
			Integer originalCount = [SELECT COUNT() FROM Survey_Question__c WHERE Survey__c = :tu.surveyId];
			System.assert(originalCount > 0, 'Should have original questions');

			// Create new questions
			List<Map<String, Object>> newQuestions = new List<Map<String, Object>>();
			Map<String, Object> q1 = new Map<String, Object>();
			q1.put('question', 'Updated Question 1');
			q1.put('questionType', 'Free Text');
			q1.put('required', true);
			q1.put('choices', new List<String>());
			q1.put('orderNumber', 1);
			newQuestions.add(q1);

			Map<String, Object> q2 = new Map<String, Object>();
			q2.put('question', 'Updated Question 2');
			q2.put('questionType', 'Single Select--Vertical');
			q2.put('required', false);
			q2.put('choices', new List<String>{ 'Option A', 'Option B' });
			q2.put('orderNumber', 2);
			newQuestions.add(q2);

			Test.startTest();
			SurveyCreationController.updateSurveyQuestions(tu.surveyId, newQuestions);
			Test.stopTest();

			// Verify old questions were deleted and new ones created
			List<Survey_Question__c> updatedQuestions = [
				SELECT Id, Question__c, Type__c, Required__c, Choices__c, OrderNumber__c
				FROM Survey_Question__c
				WHERE Survey__c = :tu.surveyId
				ORDER BY OrderNumber__c
			];

			System.assertEquals(2, updatedQuestions.size(), 'Should have 2 new questions');
			System.assertEquals('Updated Question 1', updatedQuestions[0].Question__c, 'First question should match');
			System.assertEquals('Updated Question 2', updatedQuestions[1].Question__c, 'Second question should match');
			System.assertEquals(true, updatedQuestions[0].Required__c, 'First question should be required');
			System.assertEquals(false, updatedQuestions[1].Required__c, 'Second question should not be required');
		}
	}

	@IsTest
	private static void testUpdateSurveyQuestionsWithNullId() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			List<Map<String, Object>> questions = new List<Map<String, Object>>();
			Map<String, Object> q1 = new Map<String, Object>();
			q1.put('question', 'Test Question');
			q1.put('questionType', 'Free Text');
			questions.add(q1);

			Test.startTest();
			Boolean exceptionThrown = false;
			try {
				SurveyCreationController.updateSurveyQuestions(null, questions);
			} catch (AuraHandledException e) {
				exceptionThrown = true;
				System.assert(e.getMessage().contains('required'), 'Error should indicate ID is required');
			}
			Test.stopTest();

			System.assert(exceptionThrown, 'Exception should be thrown for null survey ID');
		}
	}

	@IsTest
	private static void testUpdateIndividualQuestions() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Get existing questions
			List<Survey_Question__c> existingQuestions = [
				SELECT Id, Question__c, Type__c, Required__c, OrderNumber__c
				FROM Survey_Question__c
				WHERE Survey__c = :tu.surveyId
				ORDER BY OrderNumber__c
				LIMIT 1
			];
			System.assert(!existingQuestions.isEmpty(), 'Should have at least one existing question');

			Id firstQuestionId = existingQuestions[0].Id;
			String originalQuestion = existingQuestions[0].Question__c;

			// Update the first question and add a new one
			List<Map<String, Object>> updates = new List<Map<String, Object>>();

			// Update existing question
			Map<String, Object> updateQ = new Map<String, Object>();
			updateQ.put('id', firstQuestionId);
			updateQ.put('question', 'Updated Question Text');
			updateQ.put('questionType', 'Free Text');
			updateQ.put('required', true);
			updateQ.put('choices', new List<String>());
			updateQ.put('orderNumber', 1);
			updates.add(updateQ);

			// Add new question (no id)
			Map<String, Object> newQ = new Map<String, Object>();
			newQ.put('question', 'Brand New Question');
			newQ.put('questionType', 'Single Select--Vertical');
			newQ.put('required', false);
			newQ.put('choices', new List<String>{ 'Yes', 'No' });
			newQ.put('orderNumber', 10);
			updates.add(newQ);

			Test.startTest();
			SurveyCreationController.updateIndividualQuestions(tu.surveyId, updates);
			Test.stopTest();

			// Verify the first question was updated
			Survey_Question__c updatedQuestion = [
				SELECT Id, Question__c, Type__c, Required__c
				FROM Survey_Question__c
				WHERE Id = :firstQuestionId
			];
			System.assertEquals('Updated Question Text', updatedQuestion.Question__c, 'Question should be updated');
			System.assertEquals(true, updatedQuestion.Required__c, 'Question should now be required');
			System.assertNotEquals(originalQuestion, updatedQuestion.Question__c, 'Question text should have changed');

			// Verify the new question was created
			List<Survey_Question__c> allQuestions = [
				SELECT Id, Question__c, Type__c, OrderNumber__c
				FROM Survey_Question__c
				WHERE Survey__c = :tu.surveyId
				ORDER BY OrderNumber__c
			];

			Boolean foundNewQuestion = false;
			for (Survey_Question__c q : allQuestions) {
				if (q.Question__c == 'Brand New Question') {
					foundNewQuestion = true;
					System.assertEquals('Single Select--Vertical', q.Type__c, 'New question type should match');
					System.assertEquals(10, q.OrderNumber__c, 'New question order should be 10');
				}
			}
			System.assert(foundNewQuestion, 'New question should be created');
		}
	}

	@IsTest
	private static void testUpdateIndividualQuestionsCreateOnly() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Integer originalCount = [SELECT COUNT() FROM Survey_Question__c WHERE Survey__c = :tu.surveyId];

			// Create only new questions (no updates)
			List<Map<String, Object>> newQuestions = new List<Map<String, Object>>();
			Map<String, Object> q1 = new Map<String, Object>();
			q1.put('question', 'Additional Question 1');
			q1.put('questionType', 'Free Text');
			q1.put('required', false);
			q1.put('orderNumber', 20);
			newQuestions.add(q1);

			Test.startTest();
			SurveyCreationController.updateIndividualQuestions(tu.surveyId, newQuestions);
			Test.stopTest();

			Integer newCount = [SELECT COUNT() FROM Survey_Question__c WHERE Survey__c = :tu.surveyId];
			System.assertEquals(originalCount + 1, newCount, 'Should have one additional question');
		}
	}

	@IsTest
	private static void testUpdateIndividualQuestionsWithNullId() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			List<Map<String, Object>> questions = new List<Map<String, Object>>();
			Map<String, Object> q1 = new Map<String, Object>();
			q1.put('question', 'Test Question');
			q1.put('questionType', 'Free Text');
			questions.add(q1);

			Test.startTest();
			Boolean exceptionThrown = false;
			try {
				SurveyCreationController.updateIndividualQuestions(null, questions);
			} catch (AuraHandledException e) {
				exceptionThrown = true;
				System.assert(e.getMessage().contains('required'), 'Error should indicate ID is required');
			}
			Test.stopTest();

			System.assert(exceptionThrown, 'Exception should be thrown for null survey ID');
		}
	}

	@IsTest
	private static void testUpdateIndividualQuestionsSecurityViolation() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			// Create two separate surveys
			SurveyTestingUtil tu1 = new SurveyTestingUtil();
			SurveyTestingUtil tu2 = new SurveyTestingUtil();

			// Get a question from Survey 1
			List<Survey_Question__c> survey1Questions = [
				SELECT Id, Survey__c, Question__c
				FROM Survey_Question__c
				WHERE Survey__c = :tu1.surveyId
				LIMIT 1
			];
			System.assert(!survey1Questions.isEmpty(), 'Survey 1 should have questions');
			Id survey1QuestionId = survey1Questions[0].Id;

			// Attempt to update Survey 1's question while editing Survey 2 (malicious attempt)
			List<Map<String, Object>> maliciousUpdate = new List<Map<String, Object>>();
			Map<String, Object> q1 = new Map<String, Object>();
			q1.put('id', survey1QuestionId); // Question from Survey 1
			q1.put('question', 'Hacked Question Text');
			q1.put('questionType', 'Free Text');
			q1.put('required', false);
			q1.put('orderNumber', 1);
			maliciousUpdate.add(q1);

			Test.startTest();
			Boolean securityExceptionThrown = false;
			try {
				// Try to update Survey 2 with Survey 1's question - should fail
				SurveyCreationController.updateIndividualQuestions(tu2.surveyId, maliciousUpdate);
			} catch (AuraHandledException e) {
				securityExceptionThrown = true;
				System.assert(e.getMessage().contains('Security violation'), 'Should indicate security violation');
				System.assert(e.getMessage().contains('does not belong to Survey'), 'Should explain the violation');
			}
			Test.stopTest();

			System.assert(securityExceptionThrown, 'Security exception should be thrown');

			// Verify Survey 1's question was NOT modified
			Survey_Question__c unchangedQuestion = [
				SELECT Id, Survey__c, Question__c
				FROM Survey_Question__c
				WHERE Id = :survey1QuestionId
			];
			System.assertNotEquals('Hacked Question Text', unchangedQuestion.Question__c, 'Question should not be modified');
			System.assertEquals(tu1.surveyId, unchangedQuestion.Survey__c, 'Question should still belong to Survey 1');
		}
	}

	@IsTest
	private static void testUpdateIndividualQuestionsNoReparenting() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Get an existing question
			List<Survey_Question__c> existingQuestions = [
				SELECT Id, Survey__c, Question__c
				FROM Survey_Question__c
				WHERE Survey__c = :tu.surveyId
				LIMIT 1
			];
			System.assert(!existingQuestions.isEmpty(), 'Should have at least one question');
			Id questionId = existingQuestions[0].Id;
			Id originalSurveyId = existingQuestions[0].Survey__c;

			// Update the question
			List<Map<String, Object>> updates = new List<Map<String, Object>>();
			Map<String, Object> q1 = new Map<String, Object>();
			q1.put('id', questionId);
			q1.put('question', 'Updated Question');
			q1.put('questionType', 'Free Text');
			q1.put('required', true);
			q1.put('orderNumber', 1);
			updates.add(q1);

			Test.startTest();
			SurveyCreationController.updateIndividualQuestions(tu.surveyId, updates);
			Test.stopTest();

			// Verify the question was updated but still belongs to the same survey
			Survey_Question__c updatedQuestion = [
				SELECT Id, Survey__c, Question__c, Required__c
				FROM Survey_Question__c
				WHERE Id = :questionId
			];
			System.assertEquals('Updated Question', updatedQuestion.Question__c, 'Question text should be updated');
			System.assertEquals(true, updatedQuestion.Required__c, 'Required flag should be updated');
			System.assertEquals(originalSurveyId, updatedQuestion.Survey__c, 'Survey__c should remain unchanged');
		}
	}

	@IsTest
	private static void testCreateSurveyQuestionsWithScaleLabels() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Create a horizontal scale question with labels
			List<Map<String, Object>> questions = new List<Map<String, Object>>();
			Map<String, Object> scaleQuestion = new Map<String, Object>();
			scaleQuestion.put('question', 'How satisfied are you?');
			scaleQuestion.put('questionType', 'Single Select--Horizontal');
			scaleQuestion.put('required', true);
			scaleQuestion.put('choices', new List<String>{ '1', '2', '3', '4', '5' });
			scaleQuestion.put('orderNumber', 1);
			scaleQuestion.put('scaleStartLabel', 'Very Dissatisfied');
			scaleQuestion.put('scaleEndLabel', 'Very Satisfied');
			questions.add(scaleQuestion);

			Test.startTest();
			SurveyCreationController.createSurveyQuestions(tu.surveyId, questions);
			Test.stopTest();

			// Verify scale labels were saved
			List<Survey_Question__c> createdQuestions = [
				SELECT Id, Question__c, Type__c, Scale_Start_Label__c, Scale_End_Label__c
				FROM Survey_Question__c
				WHERE Survey__c = :tu.surveyId AND Question__c = 'How satisfied are you?'
			];

			System.assertEquals(1, createdQuestions.size(), 'Should have created one scale question');
			System.assertEquals('Single Select--Horizontal', createdQuestions[0].Type__c, 'Question type should be horizontal');
			System.assertEquals('Very Dissatisfied', createdQuestions[0].Scale_Start_Label__c, 'Start label should be saved');
			System.assertEquals('Very Satisfied', createdQuestions[0].Scale_End_Label__c, 'End label should be saved');
		}
	}

	@IsTest
	private static void testUpdateSurveyQuestionsWithScaleLabels() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Update questions with scale labels
			List<Map<String, Object>> questions = new List<Map<String, Object>>();
			Map<String, Object> scaleQuestion = new Map<String, Object>();
			scaleQuestion.put('question', 'Rate the difficulty');
			scaleQuestion.put('questionType', 'Single Select--Horizontal');
			scaleQuestion.put('required', false);
			scaleQuestion.put('choices', new List<String>{ '1', '2', '3', '4', '5' });
			scaleQuestion.put('orderNumber', 1);
			scaleQuestion.put('scaleStartLabel', 'Very Difficult');
			scaleQuestion.put('scaleEndLabel', 'Very Easy');
			questions.add(scaleQuestion);

			Test.startTest();
			SurveyCreationController.updateSurveyQuestions(tu.surveyId, questions);
			Test.stopTest();

			// Verify scale labels were saved
			List<Survey_Question__c> updatedQuestions = [
				SELECT Id, Question__c, Type__c, Scale_Start_Label__c, Scale_End_Label__c
				FROM Survey_Question__c
				WHERE Survey__c = :tu.surveyId
			];

			System.assertEquals(1, updatedQuestions.size(), 'Should have one question');
			System.assertEquals('Rate the difficulty', updatedQuestions[0].Question__c, 'Question text should match');
			System.assertEquals('Very Difficult', updatedQuestions[0].Scale_Start_Label__c, 'Start label should be saved');
			System.assertEquals('Very Easy', updatedQuestions[0].Scale_End_Label__c, 'End label should be saved');
		}
	}
}