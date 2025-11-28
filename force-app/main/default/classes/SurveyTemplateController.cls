/**
 * LWC-compatible controller for survey template management
 * Provides list and delete operations for surveys
 */
public with sharing class SurveyTemplateController {
	/**
	 * Get all surveys with basic statistics
	 * @return List of surveys with questions and responses counts
	 */
	@AuraEnabled(cacheable=true)
	public static List<Survey__c> getAllSurveys() {
		try {
			List<Schema.SobjectField> fields = new List<Schema.SobjectField>{
				Schema.Survey__c.fields.Name,
				Schema.Survey__c.fields.CreatedDate,
				Schema.Survey__c.fields.Questions__c,
				Schema.Survey__c.fields.Completed_Surveys__c,
				Schema.Survey__c.fields.Share_with_Guest_User__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToView(Schema.Survey__c.getSobjectType(), fields);

			return [
				SELECT Id, Name, CreatedDate, Questions__c, Completed_Surveys__c, Share_with_Guest_User__c
				FROM Survey__c
				WITH USER_MODE
				ORDER BY CreatedDate DESC
				LIMIT 200
			];
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyTemplateController:getAllSurveys():' + e.getMessage());
			throw new AuraHandledException('Error loading surveys: ' + e.getMessage());
		}
	}

	/**
	 * Delete a survey and all related records
	 * @param surveyId The survey to delete
	 * @return Success message
	 */
	@AuraEnabled
	public static String deleteSurvey(Id surveyId) {
		try {
			List<Schema.SobjectField> fields = new List<Schema.SobjectField>{ Schema.Survey__c.fields.Id };
			SurveyForceUtil.accessController.assertAuthorizedToDelete(Schema.Survey__c.getSobjectType(), fields);

			// Delete will cascade to questions and responses due to master-detail relationships
			delete [SELECT Id FROM Survey__c WHERE Id = :surveyId WITH USER_MODE];

			return 'Survey deleted successfully';
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyTemplateController:deleteSurvey():' + e.getMessage());
			throw new AuraHandledException('Error deleting survey: ' + e.getMessage());
		}
	}

	/**
	 * Get survey statistics summary
	 * @return Map with total surveys, questions, and responses
	 */
	@AuraEnabled(cacheable=true)
	public static Map<String, Integer> getSurveyStatistics() {
		try {
			Map<String, Integer> stats = new Map<String, Integer>();

			Integer totalSurveys = [SELECT COUNT() FROM Survey__c WITH USER_MODE];
			Integer totalQuestions = [SELECT COUNT() FROM Survey_Question__c WITH USER_MODE];
			Integer totalResponses = [SELECT COUNT() FROM SurveyTaker__c WITH USER_MODE];

			stats.put('totalSurveys', totalSurveys);
			stats.put('totalQuestions', totalQuestions);
			stats.put('totalResponses', totalResponses);

			return stats;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyTemplateController:getSurveyStatistics():' + e.getMessage());
			throw new AuraHandledException('Error loading statistics: ' + e.getMessage());
		}
	}

	/**
	 * Search surveys by name
	 * @param searchTerm The search term
	 * @return List of matching surveys
	 */
	@AuraEnabled(cacheable=true)
	public static List<Survey__c> searchSurveys(String searchTerm) {
		try {
			List<Schema.SobjectField> fields = new List<Schema.SobjectField>{
				Schema.Survey__c.fields.Name,
				Schema.Survey__c.fields.CreatedDate,
				Schema.Survey__c.fields.Questions__c,
				Schema.Survey__c.fields.Completed_Surveys__c,
				Schema.Survey__c.fields.Share_with_Guest_User__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToView(Schema.Survey__c.getSobjectType(), fields);

			if (String.isBlank(searchTerm)) {
				return getAllSurveys();
			}

			String searchPattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';

			return [
				SELECT Id, Name, CreatedDate, Questions__c, Completed_Surveys__c, Share_with_Guest_User__c
				FROM Survey__c
				WHERE Name LIKE :searchPattern
				WITH USER_MODE
				ORDER BY CreatedDate DESC
				LIMIT 100
			];
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyTemplateController:searchSurveys():' + e.getMessage());
			throw new AuraHandledException('Error searching surveys: ' + e.getMessage());
		}
	}
}