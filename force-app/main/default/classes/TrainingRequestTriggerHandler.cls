/**
 * @description Handler for Training_Request__c trigger.
 * Implements trigger logic for training request operations, including
 * automatic survey creation for participant, customer, and trainer surveys.
 */
public with sharing class TrainingRequestTriggerHandler {
	/** Static flag to prevent recursive trigger execution */
	private static Boolean isExecuting = false;

	/** Survey type constants */
	private static final String SURVEY_TYPE_PARTICIPANT = 'Participant';
	private static final String SURVEY_TYPE_CUSTOMER = 'Customer';
	private static final String SURVEY_TYPE_TRAINER = 'Trainer';

	/** Default language for surveys */
	private static final String DEFAULT_LANGUAGE = 'English';

	/**
	 * @description Before insert handler
	 * @param newRecords List of new Training Request records
	 */
	public void beforeInsert(List<Training_Request__c> newRecords) {
		// Placeholder for before insert logic
	}

	/**
	 * @description Before update handler
	 * @param newRecords List of updated Training Request records
	 * @param oldMap Map of old Training Request records
	 */
	public void beforeUpdate(List<Training_Request__c> newRecords, Map<Id, Training_Request__c> oldMap) {
		// Placeholder for before update logic
	}

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
	 * @description After update handler
	 * @param newRecords List of updated Training Request records
	 * @param newMap Map of updated Training Request records
	 * @param oldMap Map of old Training Request records
	 */
	public void afterUpdate(
		List<Training_Request__c> newRecords,
		Map<Id, Training_Request__c> newMap,
		Map<Id, Training_Request__c> oldMap
	) {
		// Placeholder for after update logic
	}

	/**
	 * @description After delete handler
	 * @param oldRecords List of deleted Training Request records
	 * @param oldMap Map of deleted Training Request records
	 */
	public void afterDelete(List<Training_Request__c> oldRecords, Map<Id, Training_Request__c> oldMap) {
		// Placeholder for after delete logic
	}

	/**
	 * @description After undelete handler
	 * @param newRecords List of undeleted Training Request records
	 * @param newMap Map of undeleted Training Request records
	 */
	public void afterUndelete(List<Training_Request__c> newRecords, Map<Id, Training_Request__c> newMap) {
		// Placeholder for after undelete logic
	}

	/**
	 * @description Create surveys for training requests
	 * Creates participant, customer, and trainer surveys automatically with token-based invitations
	 * @param trainingRequests List of Training Request records
	 */
	private void createSurveysForTrainingRequests(List<Training_Request__c> trainingRequests) {
		try {
			List<Training_Request__c> requestsToUpdate = new List<Training_Request__c>();

			for (Training_Request__c tr : trainingRequests) {
				Training_Request__c trToUpdate = new Training_Request__c();
				trToUpdate.Id = tr.Id;
				Boolean hasUpdates = false;

				// Create Participant Survey
				if (String.isBlank(tr.Participant_Survey__c)) {
					String participantSurveyUrl = createSurveyWithTokenForRequest(
						tr.Id,
						SURVEY_TYPE_PARTICIPANT,
						DEFAULT_LANGUAGE,
						buildSurveyName(tr.Name, SURVEY_TYPE_PARTICIPANT)
					);
					if (participantSurveyUrl != null) {
						trToUpdate.Participant_Survey__c = participantSurveyUrl;
						hasUpdates = true;
					}
				}

				// Create Customer Survey with token-based invitation
				if (String.isBlank(tr.Customer_Survey__c)) {
					String customerSurveyUrl = createSurveyWithTokenForRequest(
						tr.Id,
						SURVEY_TYPE_CUSTOMER,
						DEFAULT_LANGUAGE,
						buildSurveyName(tr.Name, SURVEY_TYPE_CUSTOMER)
					);
					if (customerSurveyUrl != null) {
						trToUpdate.Customer_Survey__c = customerSurveyUrl;
						hasUpdates = true;
					}
				}

				// Create Trainer Survey with token-based invitation
				if (String.isBlank(tr.Trainer_Survey__c)) {
					String trainerSurveyUrl = createSurveyWithTokenForRequest(
						tr.Id,
						SURVEY_TYPE_TRAINER,
						DEFAULT_LANGUAGE,
						buildSurveyName(tr.Name, SURVEY_TYPE_TRAINER)
					);
					if (trainerSurveyUrl != null) {
						trToUpdate.Trainer_Survey__c = trainerSurveyUrl;
						hasUpdates = true;
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
		} catch (Exception e) {
			SurveyForceUtil.log(
				'TrainingRequestTriggerHandler.createSurveysForTrainingRequests: ' +
				e.getMessage() +
				' - ' +
				e.getStackTraceString()
			);
		}
	}

	/**
	 * @description Create a survey for a training request and generate a token-based invitation
	 * @param trainingRequestId The training request ID
	 * @param surveyType The type of survey (Participant, Customer, Trainer)
	 * @param language The language for the survey
	 * @param surveyName The name for the survey
	 * @return String The token-based survey URL or null if creation failed
	 */
	private String createSurveyWithTokenForRequest(Id trainingRequestId, String surveyType, String language, String surveyName) {
		try {
			// First create the survey
			SurveyUtilities.SurveyCreationResult result = SurveyUtilities.createSurveyWithResult(
				trainingRequestId,
				surveyType,
				language,
				surveyName
			);

			if (!result.success) {
				SurveyForceUtil.log(
					'TrainingRequestTriggerHandler.createSurveyWithTokenForRequest: Failed to create ' +
					surveyType +
					' survey - ' +
					result.message
				);
				return null;
			}

			// Now create a token-based invitation for this survey
			String tokenUrl = SurveyUtilities.generateSingleSurveyInvitation(
				result.surveyId,
				trainingRequestId,
				surveyType
			);

			return tokenUrl;
		} catch (Exception e) {
			SurveyForceUtil.log(
				'TrainingRequestTriggerHandler.createSurveyWithTokenForRequest: ' +
				e.getMessage() +
				' for ' +
				surveyType
			);
			return null;
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
