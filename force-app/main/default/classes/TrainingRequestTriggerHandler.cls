/**
 * @description Handler for Training_Request__c trigger.
 * Implements trigger logic for training request operations, including
 * automatic survey creation for participant, customer, and trainer surveys.
 * Follows Single Responsibility Principle by focusing only on training request operations.
 */
public with sharing class TrainingRequestTriggerHandler {
	/** Static flag to prevent recursive trigger execution */
	private static Boolean isExecuting = false;

	/**
	 * @description After insert handler - creates surveys for new training requests
	 * @param newRecords List of new Training Request records
	 * @param newMap Map of new Training Request records
	 */
	public void afterInsert(List<Training_Request__c> newRecords, Map<Id, Training_Request__c> newMap) {
		if (isExecuting) {
			return;
		}

		isExecuting = true;
		try {
			createSurveysForTrainingRequests(newRecords);
		} finally {
			isExecuting = false;
		}
	}

	/**
	 * @description Create surveys for training requests
	 * Creates participant, customer, and trainer surveys automatically
	 * - All Survey Types: Stores token-based URL for immediate use
	 * - Participant Survey: Additional unique tokens generated when participant records are created
	 * - Customer/Trainer Surveys: Token URL can be used directly or additional tokens can be generated
	 * Uses bulkified survey creation to avoid SOQL in loops
	 * @param trainingRequests List of Training Request records
	 */
	private void createSurveysForTrainingRequests(List<Training_Request__c> trainingRequests) {
		try {
			// Build bulk survey creation requests
			List<SurveyUtilities.SurveyCreationRequest> surveyRequests = new List<SurveyUtilities.SurveyCreationRequest>();
			Map<Id, List<String>> trainingRequestToSurveyTypes = new Map<Id, List<String>>();

			for (Training_Request__c tr : trainingRequests) {
				List<String> surveyTypes = new List<String>();

				// Create Participant Survey
				if (String.isBlank(tr.Participant_Survey__c)) {
					surveyRequests.add(
						new SurveyUtilities.SurveyCreationRequest(
							tr.Id,
							SurveyForceConstants.SURVEY_TYPE_PARTICIPANT,
							SurveyForceConstants.LANGUAGE_ENGLISH,
							buildSurveyName(tr.Name, SurveyForceConstants.SURVEY_TYPE_PARTICIPANT)
						)
					);
					surveyTypes.add(SurveyForceConstants.SURVEY_TYPE_PARTICIPANT);
				}

				// Create Customer Survey
				if (String.isBlank(tr.Customer_Survey__c)) {
					surveyRequests.add(
						new SurveyUtilities.SurveyCreationRequest(
							tr.Id,
							SurveyForceConstants.SURVEY_TYPE_CUSTOMER,
							SurveyForceConstants.LANGUAGE_ENGLISH,
							buildSurveyName(tr.Name, SurveyForceConstants.SURVEY_TYPE_CUSTOMER)
						)
					);
					surveyTypes.add(SurveyForceConstants.SURVEY_TYPE_CUSTOMER);
				}

				// Create Trainer Survey
				if (String.isBlank(tr.Trainer_Survey__c)) {
					surveyRequests.add(
						new SurveyUtilities.SurveyCreationRequest(
							tr.Id,
							SurveyForceConstants.SURVEY_TYPE_TRAINER,
							SurveyForceConstants.LANGUAGE_ENGLISH,
							buildSurveyName(tr.Name, SurveyForceConstants.SURVEY_TYPE_TRAINER)
						)
					);
					surveyTypes.add(SurveyForceConstants.SURVEY_TYPE_TRAINER);
				}

				if (!surveyTypes.isEmpty()) {
					trainingRequestToSurveyTypes.put(tr.Id, surveyTypes);
				}
			}

			// Bulk create all surveys
			if (!surveyRequests.isEmpty()) {
				Map<String, SurveyUtilities.SurveyCreationResult> surveyResults = SurveyUtilities.createSurveysInBulk(surveyRequests);

				// Collect surveys for token generation (all three survey types)
				List<SurveyUtilities.InvitationRequest> invitationRequests = new List<SurveyUtilities.InvitationRequest>();
				for (String key : surveyResults.keySet()) {
					SurveyUtilities.SurveyCreationResult result = surveyResults.get(key);
					String surveyType = key.substringAfter('_');

					// Generate tokens for all survey types (Participant, Customer, and Trainer)
					// Note: Participants also get additional unique tokens when participant records are created
					if (result.success && result.surveyId != null) {
						invitationRequests.add(new SurveyUtilities.InvitationRequest(result.surveyId, result.sourceRecordId, surveyType, result.trainingType));
					}
				}

				// Generate token-based invitations in bulk (for all survey types)
				Map<String, String> surveyTokenUrls = new Map<String, String>();
				if (!invitationRequests.isEmpty()) {
					surveyTokenUrls = SurveyUtilities.generateSurveyInvitationsInBulk(invitationRequests);
				}

				// Update training requests with token-based URLs for all survey types
				List<Training_Request__c> requestsToUpdate = new List<Training_Request__c>();
				for (Id trId : trainingRequestToSurveyTypes.keySet()) {
					Training_Request__c trToUpdate = new Training_Request__c();
					trToUpdate.Id = trId;
					Boolean hasUpdates = false;

					for (String surveyType : trainingRequestToSurveyTypes.get(trId)) {
						String key = trId + '_' + surveyType;
						
						// Use token-based URL if available, otherwise fall back to Survey ID URL
						String surveyUrl = surveyTokenUrls.containsKey(key) ? surveyTokenUrls.get(key) : null;
						if (surveyUrl == null) {
							SurveyUtilities.SurveyCreationResult result = surveyResults.get(key);
							if (result != null && result.success) {
								surveyUrl = result.surveyUrl;
							}
						}

						if (surveyUrl != null) {
							// All survey types: Store token-based URL (or Survey ID URL as fallback)
							if (surveyType == SurveyForceConstants.SURVEY_TYPE_PARTICIPANT) {
								trToUpdate.Participant_Survey__c = surveyUrl;
								hasUpdates = true;
							} else if (surveyType == SurveyForceConstants.SURVEY_TYPE_CUSTOMER) {
								trToUpdate.Customer_Survey__c = surveyUrl;
								hasUpdates = true;
							} else if (surveyType == SurveyForceConstants.SURVEY_TYPE_TRAINER) {
								trToUpdate.Trainer_Survey__c = surveyUrl;
								hasUpdates = true;
							}
						}
					}

					if (hasUpdates) {
						requestsToUpdate.add(trToUpdate);
					}
				}

				// Update training requests with survey URLs
				if (!requestsToUpdate.isEmpty()) {
					Database.update(requestsToUpdate, AccessLevel.USER_MODE);
				}
			}
		} catch (Exception e) {
			SurveyForceUtil.log('TrainingRequestTriggerHandler.createSurveysForTrainingRequests: ' + e.getMessage() + ' - ' + e.getStackTraceString());
		}
	}

	/**
	 * @description Build a survey name from training request name and survey type
	 * @param trainingRequestName The training request name
	 * @param surveyType The survey type
	 * @return String The formatted survey name
	 */
	private String buildSurveyName(String trainingRequestName, String surveyType) {
		if (String.isBlank(trainingRequestName)) {
			return surveyType + ' Survey';
		}
		return trainingRequestName + ' - ' + surveyType + ' Survey';
	}
}