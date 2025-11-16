/**
 * Test class for SurveyTakerController
 */
@IsTest
private class SurveyTakerController_Test {
	@TestSetup
	static void makeData() {
		User u = SurveyTestingUtil.createNewAdminPermissionSetUser();
	}

	@IsTest
	private static void testGetSurveyData() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Test.startTest();
			SurveyTakerController.SurveyData surveyData = SurveyTakerController.getSurveyData(tu.surveyId, null, null);
			Test.stopTest();

			System.assertNotEquals(null, surveyData, 'Survey data should not be null');
			System.assertNotEquals(null, surveyData.survey, 'Survey should not be null');
			System.assertEquals(SurveyTestingUtil.QUESTION_TYPES, surveyData.questions.size(), 'Should have correct number of questions');
			System.assertEquals(true, surveyData.isInternal, 'Should be internal user');
		}
	}

	@IsTest
	private static void testSubmitSurveyResponses() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Get survey data
			SurveyTakerController.SurveyData surveyData = SurveyTakerController.getSurveyData(tu.surveyId, null, null);

			// Prepare responses
			List<SurveyTakerController.ResponseData> responses = new List<SurveyTakerController.ResponseData>();

			for (SurveyTakerController.QuestionData q : surveyData.questions) {
				SurveyTakerController.ResponseData response = new SurveyTakerController.ResponseData();
				response.questionId = q.id;

				if (q.questionType == 'Free Text') {
					response.response = 'Test response';
				} else if (q.questionType == 'Single Select--Vertical' || q.questionType == 'Single Select--Horizontal') {
					if (!q.choices.isEmpty()) {
						response.response = q.choices[0].value;
					}
				} else if (q.questionType == 'Multi-Select--Vertical') {
					response.responses = new List<String>();
					if (!q.choices.isEmpty()) {
						response.responses.add(q.choices[0].value);
					}
				}

				responses.add(response);
			}

			Test.startTest();
			SurveyTakerController.SubmitResult result = SurveyTakerController.submitSurveyResponses(tu.surveyId, responses, null, null, false);
			Test.stopTest();

			System.assertEquals(true, result.success, 'Submission should be successful');
			System.assertNotEquals(null, result.thankYouText, 'Thank you text should not be null');

			// Verify survey taker was created
			List<SurveyTaker__c> surveyTakers = [SELECT Id FROM SurveyTaker__c WHERE Survey__c = :tu.surveyId];
			System.assertEquals(1, surveyTakers.size(), 'Should have one survey taker');

			// Verify responses were created
			List<SurveyQuestionResponse__c> savedResponses = [SELECT Id FROM SurveyQuestionResponse__c WHERE SurveyTaker__c = :surveyTakers[0].Id];
			System.assert(savedResponses.size() > 0, 'Should have saved responses');
		}
	}

	@IsTest
	private static void testSubmitWithContact() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Contact c = new Contact();
			c.FirstName = 'Test';
			c.LastName = 'Contact';
			insert c;

			// Get survey data
			SurveyTakerController.SurveyData surveyData = SurveyTakerController.getSurveyData(tu.surveyId, null, c.Id);

			// Prepare minimal responses
			List<SurveyTakerController.ResponseData> responses = new List<SurveyTakerController.ResponseData>();

			for (SurveyTakerController.QuestionData q : surveyData.questions) {
				if (!q.required) {
					continue;
				}

				SurveyTakerController.ResponseData response = new SurveyTakerController.ResponseData();
				response.questionId = q.id;

				if (q.questionType == 'Free Text') {
					response.response = 'Test';
				} else if (!q.choices.isEmpty()) {
					response.response = q.choices[0].value;
				}

				responses.add(response);
			}

			Test.startTest();
			SurveyTakerController.SubmitResult result = SurveyTakerController.submitSurveyResponses(tu.surveyId, responses, null, c.Id, false);
			Test.stopTest();

			System.assertEquals(true, result.success, 'Submission should be successful');

			// Verify contact is linked
			List<SurveyTaker__c> surveyTakers = [SELECT Id, Contact__c FROM SurveyTaker__c WHERE Survey__c = :tu.surveyId];
			System.assertEquals(1, surveyTakers.size(), 'Should have one survey taker');
			System.assertEquals(c.Id, surveyTakers[0].Contact__c, 'Contact should be linked');
		}
	}

	@IsTest
	private static void testDuplicateSurveyPrevention() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Contact c = new Contact();
			c.FirstName = 'Test';
			c.LastName = 'Contact';
			insert c;

			// Get survey data
			SurveyTakerController.SurveyData surveyData = SurveyTakerController.getSurveyData(tu.surveyId, null, c.Id);

			// Prepare responses
			List<SurveyTakerController.ResponseData> responses = new List<SurveyTakerController.ResponseData>();
			for (SurveyTakerController.QuestionData q : surveyData.questions) {
				if (!q.required) {
					continue;
				}
				SurveyTakerController.ResponseData response = new SurveyTakerController.ResponseData();
				response.questionId = q.id;
				response.response = 'Test';
				responses.add(response);
			}

			// First submission
			SurveyTakerController.SubmitResult result1 = SurveyTakerController.submitSurveyResponses(tu.surveyId, responses, null, c.Id, false);
			System.assertEquals(true, result1.success, 'First submission should succeed');

			Test.startTest();
			// Second submission should fail
			try {
				SurveyTakerController.SubmitResult result2 = SurveyTakerController.submitSurveyResponses(tu.surveyId, responses, null, c.Id, false);
				System.assertEquals(false, result2.success, 'Second submission should fail');
			} catch (Exception e) {
				// Expected exception for duplicate
				System.assert(e.getMessage().contains('already taken'), 'Should indicate survey already taken');
			}
			Test.stopTest();
		}
	}

	@IsTest
	private static void testRequiredFieldValidation() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Empty responses
			List<SurveyTakerController.ResponseData> responses = new List<SurveyTakerController.ResponseData>();

			Test.startTest();
			SurveyTakerController.SubmitResult result = SurveyTakerController.submitSurveyResponses(tu.surveyId, responses, null, null, false);
			Test.stopTest();

			System.assertEquals(false, result.success, 'Should fail validation');
			System.assert(result.message.contains('required'), 'Should mention required fields');
		}
	}

	@IsTest
	private static void testAnonymousResponse() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			// Get survey data
			SurveyTakerController.SurveyData surveyData = SurveyTakerController.getSurveyData(tu.surveyId, null, null);

			// Prepare responses
			List<SurveyTakerController.ResponseData> responses = new List<SurveyTakerController.ResponseData>();
			for (SurveyTakerController.QuestionData q : surveyData.questions) {
				if (!q.required) {
					continue;
				}
				SurveyTakerController.ResponseData response = new SurveyTakerController.ResponseData();
				response.questionId = q.id;
				response.response = 'Test';
				responses.add(response);
			}

			Test.startTest();
			SurveyTakerController.SubmitResult result = SurveyTakerController.submitSurveyResponses(tu.surveyId, responses, null, null, true);
			Test.stopTest();

			System.assertEquals(true, result.success, 'Submission should succeed');

			// Verify user is not tracked for anonymous response
			List<SurveyTaker__c> surveyTakers = [SELECT Id, User__c FROM SurveyTaker__c WHERE Survey__c = :tu.surveyId];
			System.assertEquals(1, surveyTakers.size(), 'Should have one survey taker');
			System.assertEquals(null, surveyTakers[0].User__c, 'User should be null for anonymous response');
		}
	}
}