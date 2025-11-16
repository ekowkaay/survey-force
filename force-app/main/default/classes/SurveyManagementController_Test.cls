/**
 * Test class for SurveyManagementController
 */
@IsTest
private class SurveyManagementController_Test {
	@TestSetup
	static void makeData() {
		User u = SurveyTestingUtil.createNewAdminPermissionSetUser();
	}

	@IsTest
	private static void testGetSurveyManagementData() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Test.startTest();
			SurveyManagementController.SurveyManagementData data = SurveyManagementController.getSurveyManagementData(tu.surveyId);
			Test.stopTest();

			System.assertNotEquals(null, data, 'Data should not be null');
			System.assertNotEquals(null, data.survey, 'Survey should not be null');
			System.assertEquals(tu.surveyId, data.survey.Id, 'Survey ID should match');
			System.assertNotEquals(null, data.shareUrl, 'Share URL should not be null');
			System.assertEquals(SurveyTestingUtil.QUESTION_TYPES, data.questionCount, 'Question count should match');
		}
	}

	@IsTest
	private static void testUpdateSurveySettings() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Map<String, Object> surveyData = new Map<String, Object>();
			surveyData.put('Name', 'Updated Survey Name');
			surveyData.put('Survey_Header__c', 'Updated Header');
			surveyData.put('Hide_Survey_Name__c', true);
			surveyData.put('All_Responses_Anonymous__c', true);

			Test.startTest();
			String result = SurveyManagementController.updateSurveySettings(tu.surveyId, surveyData);
			Test.stopTest();

			System.assertNotEquals(null, result, 'Result should not be null');
			System.assert(result.contains('success'), 'Result should indicate success');

			// Verify updates
			Survey__c updated = [SELECT Name, Survey_Header__c, Hide_Survey_Name__c, All_Responses_Anonymous__c FROM Survey__c WHERE Id = :tu.surveyId];
			System.assertEquals('Updated Survey Name', updated.Name, 'Name should be updated');
			System.assertEquals('Updated Header', updated.Survey_Header__c, 'Header should be updated');
			System.assertEquals(true, updated.Hide_Survey_Name__c, 'Hide name should be updated');
			System.assertEquals(true, updated.All_Responses_Anonymous__c, 'Anonymous should be updated');
		}
	}

	@IsTest
	private static void testGetSurveyShareInfo() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Test.startTest();
			Map<String, String> shareInfo = SurveyManagementController.getSurveyShareInfo(tu.surveyId);
			Test.stopTest();

			System.assertNotEquals(null, shareInfo, 'Share info should not be null');
			System.assert(shareInfo.containsKey('visualforceUrl'), 'Should have Visualforce URL');
			System.assert(shareInfo.get('visualforceUrl').contains(tu.surveyId), 'URL should contain survey ID');
		}
	}

	@IsTest
	private static void testGetSurveyQuestions() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Test.startTest();
			List<Survey_Question__c> questions = SurveyManagementController.getSurveyQuestions(tu.surveyId);
			Test.stopTest();

			System.assertNotEquals(null, questions, 'Questions should not be null');
			System.assertEquals(SurveyTestingUtil.QUESTION_TYPES, questions.size(), 'Should have correct number of questions');
		}
	}

	@IsTest
	private static void testDeleteSurveyQuestion() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			List<Survey_Question__c> questions = [SELECT Id FROM Survey_Question__c WHERE Survey__c = :tu.surveyId LIMIT 1];
			System.assert(!questions.isEmpty(), 'Should have at least one question');

			Id questionId = questions[0].Id;

			Test.startTest();
			String result = SurveyManagementController.deleteSurveyQuestion(questionId);
			Test.stopTest();

			System.assertNotEquals(null, result, 'Result should not be null');
			System.assert(result.contains('success'), 'Result should indicate success');

			// Verify deletion
			List<Survey_Question__c> remaining = [SELECT Id FROM Survey_Question__c WHERE Id = :questionId];
			System.assertEquals(0, remaining.size(), 'Question should be deleted');
		}
	}

	@IsTest
	private static void testCSSSanitization() {
		User u = [SELECT Id FROM User WHERE Username LIKE '%@testorg.com' LIMIT 1];
		System.runAs(u) {
			SurveyTestingUtil tu = new SurveyTestingUtil();

			Map<String, Object> surveyData = new Map<String, Object>();
			surveyData.put('Survey_Container_CSS__c', '.container { color: red; } <script>alert("xss")</script>');

			Test.startTest();
			String result = SurveyManagementController.updateSurveySettings(tu.surveyId, surveyData);
			Test.stopTest();

			// Verify HTML tags are removed
			Survey__c updated = [SELECT Survey_Container_CSS__c FROM Survey__c WHERE Id = :tu.surveyId];
			System.assert(!updated.Survey_Container_CSS__c.contains('<script>'), 'Script tags should be removed');
			System.assert(updated.Survey_Container_CSS__c.contains('.container'), 'CSS should be preserved');
		}
	}
}