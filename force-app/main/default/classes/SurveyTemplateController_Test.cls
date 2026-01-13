@IsTest
private class SurveyTemplateController_Test {
	@TestSetup
	static void makeData() {
		// Create test surveys
		List<Survey__c> surveys = new List<Survey__c>();
		for (Integer i = 0; i < 3; i++) {
			surveys.add(new Survey__c(Name = 'Test Survey ' + i, Thank_You_Text__c = 'Thank you for completing this survey'));
		}
		// Add template surveys
		surveys.add(new Survey__c(Name = 'Customer Survey Template', Thank_You_Text__c = 'Thank you'));
		surveys.add(new Survey__c(Name = 'Employee Feedback Template', Thank_You_Text__c = 'Thank you'));
		insert surveys;
	}

	@isTest
	static void testGetAllSurveys() {
		Test.startTest();
		List<Survey__c> result = SurveyTemplateController.getAllSurveys();
		Test.stopTest();

		System.assertEquals(5, result.size(), 'Should return all 5 test surveys');
	}

	@isTest
	static void testGetTemplateSurveys() {
		Test.startTest();
		List<Survey__c> result = SurveyTemplateController.getTemplateSurveys();
		Test.stopTest();

		System.assertEquals(2, result.size(), 'Should return only 2 template surveys');
		for (Survey__c survey : result) {
			System.assert(survey.Name.containsIgnoreCase('template'), 'Survey name should contain "template"');
		}
	}

	@isTest
	static void testDeleteSurvey() {
		Survey__c survey = [SELECT Id FROM Survey__c WHERE Name = 'Test Survey 0' LIMIT 1];

		Test.startTest();
		SurveyTemplateController.deleteSurvey(survey.Id);
		Test.stopTest();

		List<Survey__c> remaining = [SELECT Id FROM Survey__c];
		System.assertEquals(4, remaining.size(), 'Should have 4 surveys remaining after delete');
	}

	@isTest
	static void testDeleteSurveyWithNullId() {
		Test.startTest();
		try {
			SurveyTemplateController.deleteSurvey(null);
			System.assert(false, 'Should have thrown an exception');
		} catch (AuraHandledException e) {
			System.assert(e.getMessage().contains('Survey ID is required'), 'Should have error about null ID');
		}
		Test.stopTest();
	}
}