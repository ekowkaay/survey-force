//Adding 2 DML statements here so Guest user can submit these 2 DMLs
//Without this, Guest user will not be able to submit these records becasue of new Guest user security
//
public without sharing class ViewSurveyControllerWithoutSharing {
	//this method is ONLY to do DML in without sharing mode
	//Make sure to try/catch any errors in the calling method
	public static void createSurveyTaken(SurveyTaker__c st) {
		insert st;
	}
	//this method is ONLY to do DML in without sharing mode
	//Make sure to try/catch any errors in the calling method
	public static void createSurveyQuestionResponse(List<SurveyQuestionResponse__c> sqrList) {
		insert sqrList;
	}

	/**
	 * Query Survey Invitation by token without sharing rules enforcement
	 * This allows guest users to access invitations via unique token URL
	 * @param token The unique invitation token
	 * @return The SurveyInvitation record if it exists, null otherwise
	 */
	public static SurveyInvitation__c getInvitationByToken(String token) {
		try {
			List<SurveyInvitation__c> invitations = [
				SELECT Id, Survey__c, Token__c, Status__c, Email__c, ParticipantName__c, Contact__c, ExpirationDate__c, EventDate__c, EventTopic__c
				FROM SurveyInvitation__c
				WHERE Token__c = :token
				LIMIT 1
			];
			return invitations.isEmpty() ? null : invitations[0];
		} catch (Exception e) {
			System.debug('Error querying invitation: ' + e.getMessage());
			return null;
		}
	}

	/**
	 * Update invitation status without sharing rules enforcement
	 * @param invitationId The invitation ID to update
	 * @param status The new status value
	 * @param surveyTakerId The survey taker ID (if completed)
	 */
	public static void updateInvitationStatus(Id invitationId, String status, Id surveyTakerId) {
		SurveyInvitation__c invitation = new SurveyInvitation__c(Id = invitationId);
		invitation.Status__c = status;
		if (status == SurveyForceConstants.STATUS_COMPLETED) {
			invitation.CompletedDate__c = Datetime.now();
			invitation.SurveyTaker__c = surveyTakerId;
		}
		update invitation;
	}

	/**
	 * Query Survey without sharing rules enforcement for guest user access
	 * All guest access is now token-based - guests must have a valid invitation token
	 * @param surveyId The ID of the survey to query
	 * @return The Survey record if it exists, null otherwise
	 */
	public static Survey__c getSurveyForGuestUser(Id surveyId) {
		try {
			List<Survey__c> surveys = [
				SELECT
					Id,
					Name,
					Thank_You_Link__c,
					Thank_You_Text__c,
					All_Responses_Anonymous__c,
					Survey_Header__c,
					Hide_Survey_Name__c,
					Survey_Container_CSS__c,
					Survey_Expiration_Message__c,
					Already_Submitted_Message__c
				FROM Survey__c
				WHERE Id = :surveyId
				LIMIT 1
			];
			return surveys.isEmpty() ? null : surveys[0];
		} catch (Exception e) {
			System.debug('Error querying survey: ' + e.getMessage());
			return null;
		}
	}

	/**
	 * Query Survey messages without sharing rules enforcement for guest user access
	 * @param surveyId The ID of the survey to query
	 * @return The Survey record with message fields if it exists, null otherwise
	 */
	public static Survey__c getSurveyMessagesForGuestUser(Id surveyId) {
		try {
			List<Survey__c> surveys = [
				SELECT Id, Survey_Expiration_Message__c, Already_Submitted_Message__c
				FROM Survey__c
				WHERE Id = :surveyId
				LIMIT 1
			];
			return surveys.isEmpty() ? null : surveys[0];
		} catch (Exception e) {
			System.debug('Error querying survey messages: ' + e.getMessage());
			return null;
		}
	}

	/**
	 * Query Survey Questions without sharing rules enforcement for surveys marked as publicly available
	 * This allows guest users to view survey questions via direct link without requiring sharing rules
	 * @param surveyId The ID of the survey whose questions to query
	 * @return List of Survey Question records for the specified survey
	 */
	public static List<Survey_Question__c> getSurveyQuestionsForGuestUser(Id surveyId) {
		try {
			return [
				SELECT Type__c, Id, Survey__c, Required__c, Question__c, OrderNumber__c, Name, Choices__c, Hide_on_Survey__c, Scale_Start_Label__c, Scale_End_Label__c
				FROM Survey_Question__c
				WHERE Survey__c = :surveyId
				ORDER BY OrderNumber__c ASC NULLS LAST
			];
		} catch (Exception e) {
			System.debug('Error querying survey questions: ' + e.getMessage());
			return new List<Survey_Question__c>();
		}
	}
}