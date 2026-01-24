/**
 * @description Controller for bulk survey invitation regeneration.
 * Handles parsing of Training Request IDs from uploaded files,
 * retrieval of associated surveys, and regeneration of invitations
 * for selected survey types (Customer, Trainer, or Participant).
 * When participants exist, deletes old invitations and creates new ones.
 */
public with sharing class SurveyRegenerationController {
	/** Survey type constants */
	private static final String SURVEY_TYPE_PARTICIPANT = SurveyForceConstants.SURVEY_TYPE_PARTICIPANT;
	private static final String SURVEY_TYPE_CUSTOMER = SurveyForceConstants.SURVEY_TYPE_CUSTOMER;
	private static final String SURVEY_TYPE_TRAINER = SurveyForceConstants.SURVEY_TYPE_TRAINER;

	/** Survey invitation status constants */
	private static final String STATUS_PENDING = SurveyForceConstants.STATUS_PENDING;

	/** Maximum number of surveys allowed for synchronous regeneration to avoid governor limits */
	private static final Integer MAX_SYNC_REGENERATION_LIMIT = 50;

	/**
	 * @description Wrapper class for survey regeneration results
	 */
	public class RegenerationResult {
		@AuraEnabled
		public Boolean success { get; set; }
		@AuraEnabled
		public String message { get; set; }
		@AuraEnabled
		public Integer totalProcessed { get; set; }
		@AuraEnabled
		public Integer successCount { get; set; }
		@AuraEnabled
		public Integer failureCount { get; set; }
		@AuraEnabled
		public List<String> errors { get; set; }
		@AuraEnabled
		public List<SurveyData> surveys { get; set; }

		public RegenerationResult() {
			this.success = false;
			this.totalProcessed = 0;
			this.successCount = 0;
			this.failureCount = 0;
			this.errors = new List<String>();
			this.surveys = new List<SurveyData>();
		}
	}

	/**
	 * @description Wrapper for survey data
	 */
	public class SurveyData {
		@AuraEnabled
		public Id trainingRequestId { get; set; }
		@AuraEnabled
		public String trainingRequestName { get; set; }
		@AuraEnabled
		public Id surveyId { get; set; }
		@AuraEnabled
		public String surveyName { get; set; }
		@AuraEnabled
		public String surveyType { get; set; }
		@AuraEnabled
		public Integer invitationCount { get; set; }
	}

	/**
	 * @description Parse Training Request IDs from file content
	 * Supports comma-separated, newline-separated, or space-separated IDs
	 * @param fileContent The content of the uploaded file
	 * @return List<String> List of parsed Training Request IDs
	 */
	@AuraEnabled
	public static List<String> parseTrainingRequestIds(String fileContent) {
		List<String> parsedIds = new List<String>();

		try {
			if (String.isBlank(fileContent)) {
				return parsedIds;
			}

			// Replace various delimiters with a single delimiter
			String normalizedContent = fileContent.replaceAll('[,\\s\\n\\r\\t]+', ',');

			// Split by comma and clean up each ID
			List<String> rawIds = normalizedContent.split(',');

			for (String rawId : rawIds) {
				String cleanId = rawId.trim();
				// Validate it looks like a Salesforce ID (15 or 18 characters)
				if (String.isNotBlank(cleanId) && (cleanId.length() == 15 || cleanId.length() == 18)) {
					parsedIds.add(cleanId);
				}
			}

			return parsedIds;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyRegenerationController:parseTrainingRequestIds():' + e.getMessage());
			throw new AuraHandledException('Error parsing Training Request IDs: ' + e.getMessage());
		}
	}

	/**
	 * @description Get surveys for Training Requests by IDs and survey types
	 * @param trainingRequestIds List of Training Request IDs
	 * @param surveyTypes List of survey types to retrieve (Customer, Trainer, Participant)
	 * @return RegenerationResult with survey data
	 */
	@AuraEnabled
	public static RegenerationResult getSurveysForRegeneration(List<String> trainingRequestIds, List<String> surveyTypes) {
		RegenerationResult result = new RegenerationResult();

		try {
			if (trainingRequestIds == null || trainingRequestIds.isEmpty()) {
				result.message = 'No Training Request IDs provided';
				return result;
			}

			if (surveyTypes == null || surveyTypes.isEmpty()) {
				result.message = 'No survey types selected';
				return result;
			}

			// Convert string IDs to Id type
			Set<Id> trIds = new Set<Id>();
			for (String idStr : trainingRequestIds) {
				try {
					trIds.add((Id) idStr);
				} catch (Exception e) {
					result.errors.add('Invalid ID: ' + idStr);
				}
			}

			if (trIds.isEmpty()) {
				result.message = 'No valid Training Request IDs provided';
				return result;
			}

			// Check read permissions
			List<Schema.SObjectField> trFields = new List<Schema.SObjectField>{
				Schema.Training_Request__c.fields.Name,
				Schema.Training_Request__c.fields.Participant_Survey__c,
				Schema.Training_Request__c.fields.Customer_Survey__c,
				Schema.Training_Request__c.fields.Trainer_Survey__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToView(Schema.Training_Request__c.getSObjectType(), trFields);

			// Query Training Requests
			List<Training_Request__c> trainingRequests = [
				SELECT Id, Name, Participant_Survey__c, Customer_Survey__c, Trainer_Survey__c
				FROM Training_Request__c
				WHERE Id IN :trIds
				WITH USER_MODE
			];

			if (trainingRequests.isEmpty()) {
				result.message = 'No Training Requests found';
				return result;
			}

			// Extract survey IDs and build survey data
			Set<Id> surveyIds = new Set<Id>();
			Map<Id, String> surveyIdToType = new Map<Id, String>();
			Map<Id, Id> surveyIdToTrainingRequest = new Map<Id, Id>();

			for (Training_Request__c tr : trainingRequests) {
				for (String surveyType : surveyTypes) {
					String surveyUrl = getSurveyUrlFromTrainingRequest(tr, surveyType);
					if (String.isNotBlank(surveyUrl)) {
						Id surveyId = extractSurveyIdFromUrl(surveyUrl);
						if (surveyId != null) {
							surveyIds.add(surveyId);
							surveyIdToType.put(surveyId, surveyType);
							surveyIdToTrainingRequest.put(surveyId, tr.Id);
						}
					}
				}
			}

			if (surveyIds.isEmpty()) {
				result.message = 'No surveys found for the selected types';
				return result;
			}

			// Check if the number of surveys exceeds the synchronous regeneration limit
			if (surveyIds.size() > MAX_SYNC_REGENERATION_LIMIT) {
				result.message = 'Found ' + surveyIds.size() + ' surveys, which exceeds the limit of ' + MAX_SYNC_REGENERATION_LIMIT + ' surveys for synchronous regeneration. Please reduce the number of Training Requests or deselect some survey types.';
				return result;
			}

			// Query surveys
			List<Schema.SObjectField> surveyFields = new List<Schema.SObjectField>{ Schema.Survey__c.fields.Name };
			SurveyForceUtil.accessController.assertAuthorizedToView(Schema.Survey__c.getSObjectType(), surveyFields);

			Map<Id, Survey__c> surveysMap = new Map<Id, Survey__c>([SELECT Id, Name FROM Survey__c WHERE Id IN :surveyIds WITH USER_MODE]);

			// Build result data
			Map<Id, Training_Request__c> trMap = new Map<Id, Training_Request__c>(trainingRequests);

			for (Id surveyId : surveyIds) {
				Survey__c survey = surveysMap.get(surveyId);
				Id trId = surveyIdToTrainingRequest.get(surveyId);
				Training_Request__c tr = trMap.get(trId);

				if (survey != null && tr != null) {
					SurveyData data = new SurveyData();
					data.trainingRequestId = tr.Id;
					data.trainingRequestName = tr.Name;
					data.surveyId = survey.Id;
					data.surveyName = survey.Name;
					data.surveyType = surveyIdToType.get(surveyId);
					data.invitationCount = 0;
					result.surveys.add(data);
				}
			}

			result.success = true;
			result.message = 'Found ' + result.surveys.size() + ' surveys for regeneration';
			result.totalProcessed = result.surveys.size();

			return result;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyRegenerationController:getSurveysForRegeneration():' + e.getMessage());
			result.message = 'Error retrieving surveys: ' + e.getMessage();
			return result;
		}
	}

	/**
	 * @description Regenerate survey invitations for selected surveys
	 * Automatically uses synchronous or asynchronous processing based on the number of surveys.
	 * If surveys exceed MAX_SYNC_REGENERATION_LIMIT, initiates batch processing.
	 * @param surveyIds List of Survey IDs to regenerate invitations for
	 * @param surveyTypes Corresponding survey types for each survey ID
	 * @return RegenerationResult with regeneration status or batch job info
	 */
	@AuraEnabled
	public static RegenerationResult regenerateSurveyInvitations(List<String> surveyIds, List<String> surveyTypes) {
		RegenerationResult result = new RegenerationResult();

		try {
			if (surveyIds == null || surveyIds.isEmpty()) {
				result.message = 'No surveys selected for regeneration';
				return result;
			}

			if (surveyTypes == null || surveyTypes.isEmpty() || surveyTypes.size() != surveyIds.size()) {
				result.message = 'Survey types must match survey IDs';
				return result;
			}

			// If within synchronous limit, process immediately
			if (surveyIds.size() <= MAX_SYNC_REGENERATION_LIMIT) {
				return regenerateSurveyInvitationsSynchronous(surveyIds, surveyTypes);
			}

			// Exceed limit - use batch processing for scalability
			// Build survey data for batch processing
			List<SurveyData> surveysForBatch = new List<SurveyData>();
			for (Integer i = 0; i < surveyIds.size(); i++) {
				try {
					Id surveyId = (Id) surveyIds[i];
					SurveyData data = new SurveyData();
					data.surveyId = surveyId;
					data.surveyType = surveyTypes[i];
					surveysForBatch.add(data);
				} catch (Exception e) {
					result.errors.add('Invalid Survey ID: ' + surveyIds[i]);
				}
			}

			if (surveysForBatch.isEmpty()) {
				result.message = 'No valid Survey IDs provided for batch processing';
				return result;
			}

			// Launch batch job - process 10 surveys per batch to stay well within governor limits
			SurveyRegenerationBatch batchJob = new SurveyRegenerationBatch(surveysForBatch);
			Id batchJobId = Database.executeBatch(batchJob, 10);

			result.success = true;
			result.message = 'Batch regeneration initiated for ' + surveysForBatch.size() + ' surveys. Job ID: ' + batchJobId + '. You will receive completion notification when processing is complete.';
			result.totalProcessed = surveysForBatch.size();

			return result;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyRegenerationController:regenerateSurveyInvitations():' + e.getMessage());
			result.message = 'Error initiating regeneration: ' + e.getMessage();
			return result;
		}
	}

	/**
	 * @description Synchronous regeneration of survey invitations
	 * Deletes existing pending invitations and creates new ones
	 * For participant surveys, creates invitations for all existing participants
	 * @param surveyIds List of Survey IDs to regenerate invitations for
	 * @param surveyTypes Corresponding survey types for each survey ID
	 * @return RegenerationResult with regeneration status
	 */
	public static RegenerationResult regenerateSurveyInvitationsSynchronous(List<String> surveyIds, List<String> surveyTypes) {
		RegenerationResult result = new RegenerationResult();

		try {
			if (surveyIds == null || surveyIds.isEmpty()) {
				result.message = 'No surveys selected for regeneration';
				return result;
			}

			if (surveyTypes == null || surveyTypes.isEmpty() || surveyTypes.size() != surveyIds.size()) {
				result.message = 'Survey types must match survey IDs';
				return result;
			}

			// Convert to Id type
			Set<Id> surveyIdSet = new Set<Id>();
			Map<Id, String> surveyIdToType = new Map<Id, String>();

			for (Integer i = 0; i < surveyIds.size(); i++) {
				try {
					Id surveyId = (Id) surveyIds[i];
					surveyIdSet.add(surveyId);
					surveyIdToType.put(surveyId, surveyTypes[i]);
				} catch (Exception e) {
					result.errors.add('Invalid Survey ID: ' + surveyIds[i]);
				}
			}

			if (surveyIdSet.isEmpty()) {
				result.message = 'No valid Survey IDs provided';
				return result;
			}

			// Check permissions
			List<Schema.SObjectField> invitationFields = new List<Schema.SObjectField>{ Schema.SurveyInvitation__c.fields.Survey__c, Schema.SurveyInvitation__c.fields.Status__c };
			SurveyForceUtil.accessController.assertAuthorizedToView(Schema.SurveyInvitation__c.getSObjectType(), invitationFields);
			SurveyForceUtil.accessController.assertAuthorizedToDelete(Schema.SurveyInvitation__c.getSObjectType());
			SurveyForceUtil.accessController.assertAuthorizedToCreate(Schema.SurveyInvitation__c.getSObjectType(), invitationFields);

			// Delete existing pending invitations for these surveys
			List<SurveyInvitation__c> existingInvitations = [
				SELECT Id
				FROM SurveyInvitation__c
				WHERE Survey__c IN :surveyIdSet AND Status__c = :STATUS_PENDING
				WITH USER_MODE
			];

			if (!existingInvitations.isEmpty()) {
				Database.delete(existingInvitations, AccessLevel.USER_MODE);
			}

			// Process each survey based on type
			Integer successCount = 0;
			Integer failureCount = 0;

			for (Id surveyId : surveyIdSet) {
				String surveyType = surveyIdToType.get(surveyId);

				try {
					if (surveyType.equals(SURVEY_TYPE_PARTICIPANT)) {
						// For participant surveys, create invitations for all participants
						Integer count = regenerateParticipantInvitations(surveyId);
						if (count > 0) {
							successCount++;
						} else {
							failureCount++;
							result.errors.add('No participants found for survey: ' + surveyId);
						}
					} else {
						// For customer/trainer surveys, create one invitation
						Boolean success = regenerateSingleInvitation(surveyId);
						if (success) {
							successCount++;
						} else {
							failureCount++;
							result.errors.add('Failed to create invitation for survey: ' + surveyId);
						}
					}
				} catch (Exception e) {
					failureCount++;
					result.errors.add('Error regenerating survey ' + surveyId + ': ' + e.getMessage());
					SurveyForceUtil.log('SurveyRegenerationController:regenerateSurveyInvitations() - Survey ' + surveyId + ': ' + e.getMessage());
				}
			}

			result.success = failureCount == 0;
			result.successCount = successCount;
			result.failureCount = failureCount;
			result.totalProcessed = successCount + failureCount;
			result.message = 'Regeneration complete: ' + successCount + ' succeeded, ' + failureCount + ' failed';

			return result;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyRegenerationController:regenerateSurveyInvitations():' + e.getMessage());
			result.message = 'Error regenerating invitations: ' + e.getMessage();
			return result;
		}
	}

	/**
	 * @description Regenerate invitations for a participant survey
	 * Creates invitations for all participants associated with the survey's training request
	 * @param surveyId The survey ID
	 * @return Integer Number of invitations created
	 */
	private static Integer regenerateParticipantInvitations(Id surveyId) {
		// Find the training request associated with this survey
		// Query all training requests with participant surveys to avoid non-indexed LIKE query
		// Note: This queries all Training_Request__c records with Participant_Survey__c populated.
		// For better performance in large orgs, consider adding a custom indexed field to store the Survey ID.
		List<Training_Request__c> trainingRequests = [
			SELECT Id, Participant_Survey__c, (SELECT Id FROM Participants__r)
			FROM Training_Request__c
			WHERE Participant_Survey__c != NULL
			WITH USER_MODE
		];

		// Filter in Apex to find the matching training request
		Training_Request__c matchedTrainingRequest = null;
		String surveyIdToken = 'id=' + String.valueOf(surveyId);
		for (Training_Request__c tr : trainingRequests) {
			if (tr.Participant_Survey__c != null && tr.Participant_Survey__c.contains(surveyIdToken)) {
				matchedTrainingRequest = tr;
				break;
			}
		}

		if (matchedTrainingRequest == null || matchedTrainingRequest.Participants__r.isEmpty()) {
			return 0;
		}

		// Get participant IDs
		Set<Id> participantIds = new Set<Id>();
		for (Participants__c p : matchedTrainingRequest.Participants__r) {
			participantIds.add(p.Id);
		}

		// Use existing utility method to generate participant survey links
		Map<Id, SurveyUtilities.ParticipantSurveyResult> results = SurveyUtilities.generateParticipantSurveyLinks(participantIds, surveyId);

		// Update participants with new survey URLs
		List<Participants__c> participantsToUpdate = new List<Participants__c>();
		for (Id participantId : results.keySet()) {
			SurveyUtilities.ParticipantSurveyResult pResult = results.get(participantId);
			if (pResult.success && pResult.surveyUrl != null) {
				Participants__c p = new Participants__c();
				p.Id = participantId;
				p.Participant_Survey__c = pResult.surveyUrl;
				participantsToUpdate.add(p);
			}
		}

		if (!participantsToUpdate.isEmpty()) {
			// Check FLS before updating Participants__c records
			SurveyForceUtil.accessController.assertAuthorizedToUpdate(
				Participants__c.SObjectType,
				new List<Schema.SObjectField>{ Participants__c.Participant_Survey__c }
			);
			Database.update(participantsToUpdate, AccessLevel.USER_MODE);
		}

		return participantsToUpdate.size();
	}

	/**
	 * @description Regenerate a single invitation for customer/trainer surveys
	 * @param surveyId The survey ID
	 * @return Boolean True if successful
	 */
	private static Boolean regenerateSingleInvitation(Id surveyId) {
		// Create a single invitation using SurveyInvitationController
		SurveyInvitationController.InvitationResult invResult = SurveyInvitationController.createInvitation(
			surveyId,
			null, // email
			null, // participant name
			null, // contact id
			null, // event date
			null, // related record id
			null // event topic
		);

		return invResult.success;
	}

	/**
	 * @description Get survey URL from training request based on survey type
	 * @param tr Training Request record
	 * @param surveyType Survey type
	 * @return String Survey URL or null
	 */
	private static String getSurveyUrlFromTrainingRequest(Training_Request__c tr, String surveyType) {
		if (surveyType.equals(SURVEY_TYPE_PARTICIPANT)) {
			return tr.Participant_Survey__c;
		} else if (surveyType.equals(SURVEY_TYPE_CUSTOMER)) {
			return tr.Customer_Survey__c;
		} else if (surveyType.equals(SURVEY_TYPE_TRAINER)) {
			return tr.Trainer_Survey__c;
		}
		return null;
	}

	/**
	 * @description Extract Survey ID from a survey URL
	 * @param surveyUrl The survey URL containing the ID parameter
	 * @return Id The extracted Survey ID or null if not found
	 */
	private static Id extractSurveyIdFromUrl(String surveyUrl) {
		if (String.isBlank(surveyUrl)) {
			return null;
		}

		try {
			// Extract survey ID directly (format: /TakeSurvey?id=SURVEY_ID)
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
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyRegenerationController.extractSurveyIdFromUrl: ' + e.getMessage());
		}

		return null;
	}
}