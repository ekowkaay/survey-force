/**
 * LWC-compatible controller for creating surveys
 * Modern replacement for GSurveysController with @AuraEnabled methods
 */
public with sharing class SurveyCreationController {
	/**
	 * Survey creation result wrapper
	 */
	public class CreationResult {
		@AuraEnabled
		public Boolean success { get; set; }
		@AuraEnabled
		public String message { get; set; }
		@AuraEnabled
		public Id surveyId { get; set; }
		@AuraEnabled
		public String redirectUrl { get; set; }
	}

	/**
	 * Site availability info
	 */
	public class SiteInfo {
		@AuraEnabled
		public Boolean hasExistingSite { get; set; }
		@AuraEnabled
		public List<String> siteNames { get; set; }
	}

	/**
	 * Check if Experience Sites exist
	 * @return SiteInfo with site availability
	 */
	@AuraEnabled(cacheable=true)
	public static SiteInfo checkSiteAvailability() {
		try {
			SiteInfo info = new SiteInfo();
			info.siteNames = new List<String>();

			List<Site> sites = [SELECT Id, Name, Status FROM Site WHERE Status = 'Active' LIMIT 10];
			info.hasExistingSite = !sites.isEmpty();

			for (Site s : sites) {
				info.siteNames.add(s.Name);
			}

			return info;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyCreationController:checkSiteAvailability():' + e.getMessage());
			// Return default info if there's an error
			SiteInfo info = new SiteInfo();
			info.hasExistingSite = true; // Assume true to not block survey creation
			info.siteNames = new List<String>();
			return info;
		}
	}

	/**
	 * Create a new survey
	 * @param surveyName Name of the new survey
	 * @return CreationResult with success status and survey ID
	 */
	@AuraEnabled
	public static CreationResult createSurvey(String surveyName) {
		CreationResult result = new CreationResult();
		result.success = false;

		try {
			if (String.isBlank(surveyName)) {
				result.message = 'Survey name is required';
				return result;
			}

			List<Schema.SobjectField> fields = new List<Schema.SobjectField>{ Schema.Survey__c.fields.Name };
			SurveyForceUtil.accessController.assertAuthorizedToCreate(Schema.Survey__c.getSobjectType(), fields);

			Survey__c newSurvey = new Survey__c();
			newSurvey.Name = surveyName;

			insert newSurvey;

			result.success = true;
			result.message = 'Survey created successfully';
			result.surveyId = newSurvey.Id;
			result.redirectUrl = '/' + newSurvey.Id;

			return result;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyCreationController:createSurvey():' + e.getMessage());
			result.message = 'Error creating survey: ' + e.getMessage();
			return result;
		}
	}

	/**
	 * Get recent surveys for display
	 * @return List of recent surveys
	 */
	@AuraEnabled(cacheable=true)
	public static List<Survey__c> getRecentSurveys() {
		try {
			List<Schema.SobjectField> fields = new List<Schema.SobjectField>{ Schema.Survey__c.fields.Name, Schema.Survey__c.fields.CreatedDate };
			SurveyForceUtil.accessController.assertAuthorizedToView(Schema.Survey__c.getSobjectType(), fields);

			return [
				SELECT Id, Name, CreatedDate, Questions__c, Completed_Surveys__c
				FROM Survey__c
				WITH USER_MODE
				ORDER BY CreatedDate DESC
				LIMIT 10
			];
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyCreationController:getRecentSurveys():' + e.getMessage());
			throw new AuraHandledException('Error loading recent surveys: ' + e.getMessage());
		}
	}

	/**
	 * Clone an existing survey
	 * @param sourceSurveyId Survey ID to clone
	 * @param newSurveyName Name for the new survey
	 * @return CreationResult with success status and new survey ID
	 */
	@AuraEnabled
	public static CreationResult cloneSurvey(Id sourceSurveyId, String newSurveyName) {
		CreationResult result = new CreationResult();
		result.success = false;

		try {
			if (String.isBlank(newSurveyName)) {
				result.message = 'Survey name is required';
				return result;
			}

			// Get source survey
			List<Schema.SobjectField> surveyFields = new List<Schema.SobjectField>{
				Schema.Survey__c.fields.Name,
				Schema.Survey__c.fields.Survey_Header__c,
				Schema.Survey__c.fields.Hide_Survey_Name__c,
				Schema.Survey__c.fields.Thank_You_Text__c,
				Schema.Survey__c.fields.Thank_You_Link__c,
				Schema.Survey__c.fields.All_Responses_Anonymous__c,
				Schema.Survey__c.fields.Share_with_Guest_User__c,
				Schema.Survey__c.fields.Survey_Container_CSS__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToView(Schema.Survey__c.getSobjectType(), surveyFields);
			SurveyForceUtil.accessController.assertAuthorizedToCreate(Schema.Survey__c.getSobjectType(), surveyFields);

			Survey__c sourceSurvey = [
				SELECT Survey_Header__c, Hide_Survey_Name__c, Thank_You_Text__c, Thank_You_Link__c, All_Responses_Anonymous__c, Share_with_Guest_User__c, Survey_Container_CSS__c
				FROM Survey__c
				WHERE Id = :sourceSurveyId
				WITH USER_MODE
				LIMIT 1
			];

			// Create new survey with same settings
			Survey__c newSurvey = sourceSurvey.clone(false, true, false, false);
			newSurvey.Name = newSurveyName;
			insert newSurvey;

			// Clone questions
			List<Schema.SobjectField> questionFields = new List<Schema.SobjectField>{
				Schema.Survey_Question__c.fields.Question__c,
				Schema.Survey_Question__c.fields.OrderNumber__c,
				Schema.Survey_Question__c.fields.Type__c,
				Schema.Survey_Question__c.fields.Required__c,
				Schema.Survey_Question__c.fields.Choices__c,
				Schema.Survey_Question__c.fields.Hide_on_Survey__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToView(Schema.Survey_Question__c.getSobjectType(), questionFields);
			SurveyForceUtil.accessController.assertAuthorizedToCreate(Schema.Survey_Question__c.getSobjectType(), questionFields);

			List<Survey_Question__c> sourceQuestions = [
				SELECT Question__c, OrderNumber__c, Type__c, Required__c, Choices__c, Hide_on_Survey__c
				FROM Survey_Question__c
				WHERE Survey__c = :sourceSurveyId
				WITH USER_MODE
				ORDER BY OrderNumber__c
			];

			if (!sourceQuestions.isEmpty()) {
				List<Survey_Question__c> newQuestions = new List<Survey_Question__c>();
				for (Survey_Question__c sq : sourceQuestions) {
					Survey_Question__c newQuestion = sq.clone(false, true, false, false);
					newQuestion.Survey__c = newSurvey.Id;
					newQuestions.add(newQuestion);
				}
				insert newQuestions;
			}

			result.success = true;
			result.message = 'Survey cloned successfully';
			result.surveyId = newSurvey.Id;
			result.redirectUrl = '/' + newSurvey.Id;

			return result;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyCreationController:cloneSurvey():' + e.getMessage());
			result.message = 'Error cloning survey: ' + e.getMessage();
			return result;
		}
	}
}