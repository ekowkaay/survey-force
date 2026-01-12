/**
 * @description Handler for Participants__c trigger.
 * Implements trigger logic for participant record operations, including
 * automatic survey invitation generation when participants are created.
 * Follows Single Responsibility Principle by focusing only on participant-related operations.
 */
public with sharing class ParticipantsTriggerHandler {
	/** Static flag to prevent recursive trigger execution */
	private static Boolean isExecuting = false;

	/**
	 * @description After insert handler - generates survey invitations for new participants
	 * @param newRecords List of new Participant records
	 * @param newMap Map of new Participant records
	 */
	public void afterInsert(List<Participants__c> newRecords, Map<Id, Participants__c> newMap) {
		if (isExecuting) {
			return;
		}

		isExecuting = true;
		try {
			generateParticipantSurveys(newRecords);
		} finally {
			isExecuting = false;
		}
	}

	/**
	 * @description Generate survey invitations for participants based on their training request's survey
	 * @param participants List of Participant records
	 */
	private void generateParticipantSurveys(List<Participants__c> participants) {
		try {
			// Group participants by Training Request
			Set<Id> trainingRequestIds = new Set<Id>();
			for (Participants__c participant : participants) {
				if (participant.Training_Request__c != null) {
					trainingRequestIds.add(participant.Training_Request__c);
				}
			}

			if (trainingRequestIds.isEmpty()) {
				return;
			}

			// Query Training Requests to get their participant surveys
			Map<Id, Training_Request__c> trainingRequestMap = new Map<Id, Training_Request__c>(
				[
					SELECT Id, Participant_Survey__c
					FROM Training_Request__c
					WHERE Id IN :trainingRequestIds
					WITH USER_MODE
				]
			);

			// Collect all unique tokens from URLs to bulk query
			Set<String> tokens = new Set<String>();
			for (Training_Request__c tr : trainingRequestMap.values()) {
				if (String.isNotBlank(tr.Participant_Survey__c)) {
					String token = extractTokenFromUrl(tr.Participant_Survey__c);
					if (token != null) {
						tokens.add(token);
					}
				}
			}

			// Bulk query SurveyInvitation records for all tokens at once
			Map<String, Id> tokenToSurveyMap = new Map<String, Id>();
			if (!tokens.isEmpty()) {
				for (SurveyInvitation__c inv : [
					SELECT Token__c, Survey__c
					FROM SurveyInvitation__c
					WHERE Token__c IN :tokens
					WITH USER_MODE
				]) {
					if (inv.Survey__c != null) {
						tokenToSurveyMap.put(inv.Token__c, inv.Survey__c);
					}
				}
			}

			// Get survey IDs from URLs (using bulk-queried token map)
			Map<Id, Id> trainingRequestToSurveyMap = new Map<Id, Id>();
			for (Id trId : trainingRequestMap.keySet()) {
				Training_Request__c tr = trainingRequestMap.get(trId);
				if (String.isNotBlank(tr.Participant_Survey__c)) {
					// Extract survey ID from URL (handles both token and Survey ID formats)
					Id surveyId = extractSurveyIdFromUrl(tr.Participant_Survey__c, tokenToSurveyMap);
					if (surveyId != null) {
						trainingRequestToSurveyMap.put(trId, surveyId);
					}
				}
			}

			if (trainingRequestToSurveyMap.isEmpty()) {
				return;
			}

			// Group participants by their survey
			Map<Id, Set<Id>> surveyToParticipantsMap = new Map<Id, Set<Id>>();
			for (Participants__c participant : participants) {
				if (participant.Training_Request__c != null) {
					Id surveyId = trainingRequestToSurveyMap.get(participant.Training_Request__c);
					if (surveyId != null) {
						if (!surveyToParticipantsMap.containsKey(surveyId)) {
							surveyToParticipantsMap.put(surveyId, new Set<Id>());
						}
						surveyToParticipantsMap.get(surveyId).add(participant.Id);
					}
				}
			}

			// Generate survey links in bulk for each survey
			List<Participants__c> participantsToUpdate = new List<Participants__c>();
			for (Id surveyId : surveyToParticipantsMap.keySet()) {
				Set<Id> participantIds = surveyToParticipantsMap.get(surveyId);
				Map<Id, SurveyUtilities.ParticipantSurveyResult> results = SurveyUtilities.generateParticipantSurveyLinks(participantIds, surveyId);

				// Update participants with their survey URLs
				for (Id participantId : results.keySet()) {
					SurveyUtilities.ParticipantSurveyResult result = results.get(participantId);
					if (result.success && result.surveyUrl != null) {
						Participants__c p = new Participants__c();
						p.Id = participantId;
						p.Participant_Survey__c = result.surveyUrl;
						participantsToUpdate.add(p);
					}
				}
			}

			// Update participants with survey URLs
			if (!participantsToUpdate.isEmpty()) {
				Database.update(participantsToUpdate, AccessLevel.USER_MODE);
			}
		} catch (Exception e) {
			SurveyForceUtil.log('ParticipantsTriggerHandler.generateParticipantSurveys: ' + e.getMessage() + ' - ' + e.getStackTraceString());
		}
	}

	/**
	 * @description Extract token from a token-based survey URL
	 * @param surveyUrl The survey URL potentially containing a token parameter
	 * @return String The extracted token or null if not found
	 */
	private String extractTokenFromUrl(String surveyUrl) {
		if (String.isBlank(surveyUrl)) {
			return null;
		}

		try {
			Integer tokenParamIndex = surveyUrl.indexOf('token=');
			if (tokenParamIndex != -1) {
				String tokenPortion = surveyUrl.substring(tokenParamIndex + 6);
				// Get everything up to the next & or end of string
				Integer endIndex = tokenPortion.indexOf('&');
				return endIndex != -1 ? tokenPortion.substring(0, endIndex) : tokenPortion;
			}
		} catch (Exception e) {
			SurveyForceUtil.log('ParticipantsTriggerHandler.extractTokenFromUrl: ' + e.getMessage());
		}

		return null;
	}

	/**
	 * @description Extract Survey ID from a survey URL
	 * Handles both Survey ID-based URLs and token-based URLs
	 * @param surveyUrl The survey URL containing either an ID parameter or a token parameter
	 * @param tokenToSurveyMap Pre-populated map of tokens to Survey IDs (for bulk processing)
	 * @return Id The extracted Survey ID or null if not found
	 */
	private Id extractSurveyIdFromUrl(String surveyUrl, Map<String, Id> tokenToSurveyMap) {
		if (String.isBlank(surveyUrl)) {
			return null;
		}

		try {
			// First, try to extract survey ID directly (format: /TakeSurvey?id=SURVEY_ID)
			Integer idParamIndex = surveyUrl.indexOf('id=');
			if (idParamIndex != -1) {
				String idPortion = surveyUrl.substring(idParamIndex + 3);
				// Get everything up to the next & or end of string
				Integer endIndex = idPortion.indexOf('&');
				String idValue = endIndex != -1 ? idPortion.substring(0, endIndex) : idPortion;

				// Validate it's a valid Survey ID
				if (idValue.length() >= 15) {
					return (Id) idValue;
				}
			}

			// If no direct ID found, try to extract from token-based URL using the bulk-queried map
			String token = extractTokenFromUrl(surveyUrl);
			if (token != null && tokenToSurveyMap != null && tokenToSurveyMap.containsKey(token)) {
				return tokenToSurveyMap.get(token);
			}
		} catch (Exception e) {
			SurveyForceUtil.log('ParticipantsTriggerHandler.extractSurveyIdFromUrl: ' + e.getMessage());
		}

		return null;
	}
}