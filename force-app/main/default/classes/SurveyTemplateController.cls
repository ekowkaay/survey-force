/**
 * LWC-compatible controller for managing survey templates
 * Provides methods for listing and deleting surveys
 */
public with sharing class SurveyTemplateController {
	/**
	 * Get all surveys for the template list
	 * @return List of all surveys
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
			];
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyTemplateController:getAllSurveys():' + e.getMessage());
			throw new AuraHandledException('Error loading surveys: ' + e.getMessage());
		}
	}

	/**
	 * Delete a survey and all related records
	 * @param surveyId The survey ID to delete
	 */
	@AuraEnabled
	public static void deleteSurvey(Id surveyId) {
		try {
			if (surveyId == null) {
				throw new AuraHandledException('Survey ID is required');
			}

			// Check delete permissions
			if (!Schema.Survey__c.getSObjectType().getDescribe().isDeletable()) {
				throw new AuraHandledException('You do not have permission to delete surveys');
			}

			// Delete the survey (cascading delete will handle related records)
			Survey__c surveyToDelete = new Survey__c(Id = surveyId);
			delete surveyToDelete;
		} catch (DmlException e) {
			SurveyForceUtil.log('SurveyTemplateController:deleteSurvey():' + e.getMessage());
			throw new AuraHandledException('Error deleting survey: ' + e.getMessage());
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyTemplateController:deleteSurvey():' + e.getMessage());
			throw new AuraHandledException('Error deleting survey: ' + e.getMessage());
		}
	}
}