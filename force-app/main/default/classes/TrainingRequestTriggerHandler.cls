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
	 * Creates participant, customer, and trainer surveys automatically
	 * Survey URLs with IDs are stored in Training Request fields
	 * Token-based invitations are NOT created here - they are generated when needed:
	 * - Participant tokens: Generated when participants are created
	 * - Customer/Trainer tokens: Generated on-demand via UI or API
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
					surveyRequests.add(new SurveyUtilities.SurveyCreationRequest(
						tr.Id,
						SURVEY_TYPE_PARTICIPANT,
						DEFAULT_LANGUAGE,
						buildSurveyName(tr.Name, SURVEY_TYPE_PARTICIPANT)
					));
					surveyTypes.add(SURVEY_TYPE_PARTICIPANT);
				}

				// Create Customer Survey
				if (String.isBlank(tr.Customer_Survey__c)) {
					surveyRequests.add(new SurveyUtilities.SurveyCreationRequest(
						tr.Id,
						SURVEY_TYPE_CUSTOMER,
						DEFAULT_LANGUAGE,
						buildSurveyName(tr.Name, SURVEY_TYPE_CUSTOMER)
					));
					surveyTypes.add(SURVEY_TYPE_CUSTOMER);
				}

				// Create Trainer Survey
				if (String.isBlank(tr.Trainer_Survey__c)) {
					surveyRequests.add(new SurveyUtilities.SurveyCreationRequest(
						tr.Id,
						SURVEY_TYPE_TRAINER,
						DEFAULT_LANGUAGE,
						buildSurveyName(tr.Name, SURVEY_TYPE_TRAINER)
					));
					surveyTypes.add(SURVEY_TYPE_TRAINER);
				}

				if (!surveyTypes.isEmpty()) {
					trainingRequestToSurveyTypes.put(tr.Id, surveyTypes);
				}
			}

			// Bulk create all surveys
			if (!surveyRequests.isEmpty()) {
				Map<String, SurveyUtilities.SurveyCreationResult> surveyResults = SurveyUtilities.createSurveysInBulk(surveyRequests);

				// Update training requests with survey URLs (non-token URLs with survey IDs)
				List<Training_Request__c> requestsToUpdate = new List<Training_Request__c>();
				for (Id trId : trainingRequestToSurveyTypes.keySet()) {
					Training_Request__c trToUpdate = new Training_Request__c();
					trToUpdate.Id = trId;
					Boolean hasUpdates = false;

					for (String surveyType : trainingRequestToSurveyTypes.get(trId)) {
						String key = trId + '_' + surveyType;
						SurveyUtilities.SurveyCreationResult result = surveyResults.get(key);

						if (result != null && result.success && result.surveyUrl != null) {
							if (surveyType == SURVEY_TYPE_PARTICIPANT) {
								trToUpdate.Participant_Survey__c = result.surveyUrl;
								hasUpdates = true;
							} else if (surveyType == SURVEY_TYPE_CUSTOMER) {
								trToUpdate.Customer_Survey__c = result.surveyUrl;
								hasUpdates = true;
							} else if (surveyType == SURVEY_TYPE_TRAINER) {
								trToUpdate.Trainer_Survey__c = result.surveyUrl;
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
			SurveyForceUtil.log(
				'TrainingRequestTriggerHandler.createSurveysForTrainingRequests: ' +
				e.getMessage() +
				' - ' +
				e.getStackTraceString()
			);
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
