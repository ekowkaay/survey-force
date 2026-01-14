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
			SurveyCreationController.CreationResult result = SurveyCreationController.updateSurveyWithDetails(
				null,
				'Test Survey',
				'Header',
				'Subheader',
				'Thank you',
				'',
				false,
				false
			);
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
			SurveyCreationController.CreationResult result = SurveyCreationController.updateSurveyWithDetails(
				tu.surveyId,
				'',
				'Header',
				'Subheader',
				'Thank you',
				'',
				false,
				false
			);
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
}