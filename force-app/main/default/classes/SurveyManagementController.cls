/**
 * LWC-compatible controller for managing surveys
 * Modern replacement for SurveyManagerController with @AuraEnabled methods
 */
public with sharing class SurveyManagementController {
	/**
	 * Survey management data wrapper
	 */
	public class SurveyManagementData {
		@AuraEnabled
		public Survey__c survey { get; set; }
		@AuraEnabled
		public String shareUrl { get; set; }
		@AuraEnabled
		public String reportId { get; set; }
		@AuraEnabled
		public Boolean canUpdate { get; set; }
		@AuraEnabled
		public Integer questionCount { get; set; }
		@AuraEnabled
		public Integer responseCount { get; set; }
	}

	/**
	 * Get survey management data
	 * @param surveyId Survey record ID
	 * @return SurveyManagementData wrapper
	 */
	@AuraEnabled(cacheable=true)
	public static SurveyManagementData getSurveyManagementData(Id surveyId) {
		try {
			SurveyManagementData result = new SurveyManagementData();

			// Check if user can update surveys
			result.canUpdate = Schema.sObjectType.Survey__c.isUpdateable();

			// Get survey record
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

			result.survey = [
				SELECT Id, Name, Survey_Header__c, Hide_Survey_Name__c, Thank_You_Text__c, Thank_You_Link__c, All_Responses_Anonymous__c, Share_with_Guest_User__c, Survey_Container_CSS__c
				FROM Survey__c
				WHERE Id = :surveyId
				WITH USER_MODE
				LIMIT 1
			];

			// Generate share URL
			String baseUrl = URL.getSalesforceBaseUrl().toExternalForm();
			result.shareUrl = baseUrl + '/apex/TakeSurvey?id=' + surveyId;

			// Get question count
			result.questionCount = [SELECT COUNT() FROM Survey_Question__c WHERE Survey__c = :surveyId WITH USER_MODE];

			// Get response count
			result.responseCount = [SELECT COUNT() FROM SurveyTaker__c WHERE Survey__c = :surveyId WITH USER_MODE];

			// Get report ID for analytics
			try {
				String reportName = 'Survey with Questions and Responses';
				Report myReport = [SELECT Id FROM Report WHERE Name = :reportName WITH USER_MODE LIMIT 1];
				result.reportId = myReport.Id;
			} catch (Exception e) {
				// Report not found or not accessible
				result.reportId = null;
			}

			return result;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyManagementController:getSurveyManagementData():' + e.getMessage());
			throw new AuraHandledException('Error loading survey management data: ' + e.getMessage());
		}
	}

	/**
	 * Update survey settings
	 * @param surveyId Survey record ID
	 * @param surveyData Survey data to update
	 * @return Success message
	 */
	@AuraEnabled
	public static String updateSurveySettings(Id surveyId, Map<String, Object> surveyData) {
		try {
			List<Schema.SobjectField> fields = new List<Schema.SobjectField>{
				Schema.Survey__c.fields.Name,
				Schema.Survey__c.fields.Survey_Header__c,
				Schema.Survey__c.fields.Hide_Survey_Name__c,
				Schema.Survey__c.fields.Thank_You_Text__c,
				Schema.Survey__c.fields.Thank_You_Link__c,
				Schema.Survey__c.fields.All_Responses_Anonymous__c,
				Schema.Survey__c.fields.Share_with_Guest_User__c,
				Schema.Survey__c.fields.Survey_Container_CSS__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToUpdate(Schema.Survey__c.getSobjectType(), fields);

			Survey__c survey = new Survey__c(Id = surveyId);

			// Update fields if present in the data
			if (surveyData.containsKey('Name')) {
				survey.Name = (String) surveyData.get('Name');
			}
			if (surveyData.containsKey('Survey_Header__c')) {
				survey.Survey_Header__c = (String) surveyData.get('Survey_Header__c');
			}
			if (surveyData.containsKey('Hide_Survey_Name__c')) {
				survey.Hide_Survey_Name__c = (Boolean) surveyData.get('Hide_Survey_Name__c');
			}
			if (surveyData.containsKey('Thank_You_Text__c')) {
				survey.Thank_You_Text__c = (String) surveyData.get('Thank_You_Text__c');
			}
			if (surveyData.containsKey('Thank_You_Link__c')) {
				survey.Thank_You_Link__c = (String) surveyData.get('Thank_You_Link__c');
			}
			if (surveyData.containsKey('All_Responses_Anonymous__c')) {
				survey.All_Responses_Anonymous__c = (Boolean) surveyData.get('All_Responses_Anonymous__c');
			}
			if (surveyData.containsKey('Share_with_Guest_User__c')) {
				survey.Share_with_Guest_User__c = (Boolean) surveyData.get('Share_with_Guest_User__c');
			}
			if (surveyData.containsKey('Survey_Container_CSS__c')) {
				String css = (String) surveyData.get('Survey_Container_CSS__c');
				// Sanitize CSS - remove HTML tags
				survey.Survey_Container_CSS__c = String.isNotBlank(css) ? css.replaceAll('<[^>]+>', ' ') : '';
			}

			update survey;
			return 'Survey settings updated successfully';
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyManagementController:updateSurveySettings():' + e.getMessage());
			throw new AuraHandledException('Error updating survey settings: ' + e.getMessage());
		}
	}

	/**
	 * Get survey share information
	 * @param surveyId Survey record ID
	 * @return Map with share URLs and settings
	 */
	@AuraEnabled(cacheable=true)
	public static Map<String, String> getSurveyShareInfo(Id surveyId) {
		try {
			Map<String, String> shareInfo = new Map<String, String>();

			String baseUrl = URL.getSalesforceBaseUrl().toExternalForm();
			shareInfo.put('visualforceUrl', baseUrl + '/apex/TakeSurvey?id=' + surveyId);

			// Check if there are any Experience Sites available
			List<Site> sites = [SELECT Id, Name, Subdomain FROM Site WHERE Status = 'Active' LIMIT 10];
			if (!sites.isEmpty()) {
				for (Site s : sites) {
					String siteUrl = s.Subdomain + '.force.com/TakeSurvey?id=' + surveyId;
					shareInfo.put('site_' + s.Name, siteUrl);
				}
			}

			return shareInfo;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyManagementController:getSurveyShareInfo():' + e.getMessage());
			throw new AuraHandledException('Error getting survey share info: ' + e.getMessage());
		}
	}

	/**
	 * Get survey questions for editing
	 * @param surveyId Survey record ID
	 * @return List of survey questions
	 */
	@AuraEnabled(cacheable=true)
	public static List<Survey_Question__c> getSurveyQuestions(Id surveyId) {
		try {
			List<Schema.SobjectField> fields = new List<Schema.SobjectField>{
				Schema.Survey_Question__c.fields.Question__c,
				Schema.Survey_Question__c.fields.OrderNumber__c,
				Schema.Survey_Question__c.fields.Type__c,
				Schema.Survey_Question__c.fields.Required__c,
				Schema.Survey_Question__c.fields.Choices__c,
				Schema.Survey_Question__c.fields.Hide_on_Survey__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToView(Schema.Survey_Question__c.getSobjectType(), fields);

			return [
				SELECT Id, Question__c, OrderNumber__c, Type__c, Required__c, Choices__c, Hide_on_Survey__c, Name
				FROM Survey_Question__c
				WHERE Survey__c = :surveyId
				WITH USER_MODE
				ORDER BY OrderNumber__c ASC NULLS LAST
			];
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyManagementController:getSurveyQuestions():' + e.getMessage());
			throw new AuraHandledException('Error loading survey questions: ' + e.getMessage());
		}
	}

	/**
	 * Delete a survey question
	 * @param questionId Question ID to delete
	 * @return Success message
	 */
	@AuraEnabled
	public static String deleteSurveyQuestion(Id questionId) {
		try {
			List<Schema.SobjectField> fields = new List<Schema.SobjectField>{ Schema.Survey_Question__c.fields.Id };
			SurveyForceUtil.accessController.assertAuthorizedToDelete(Schema.Survey_Question__c.getSobjectType(), fields);

			delete [SELECT Id FROM Survey_Question__c WHERE Id = :questionId WITH USER_MODE];
			return 'Question deleted successfully';
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyManagementController:deleteSurveyQuestion():' + e.getMessage());
			throw new AuraHandledException('Error deleting question: ' + e.getMessage());
		}
	}
}