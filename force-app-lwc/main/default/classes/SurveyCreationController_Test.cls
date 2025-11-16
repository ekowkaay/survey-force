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
}