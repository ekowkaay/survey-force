/**

		@AuraEnabled
		public String relatedRecordObjectApiName;

		@AuraEnabled
		public String participantSurveyFieldApiName;

		@AuraEnabled
		public String customerSurveyFieldApiName;

		@AuraEnabled
		public String trainerSurveyFieldApiName;

		@AuraEnabled
		public String trainingTypeFieldApiName;
 * @description Invocable controller for regenerating survey links and invitations.
 * Designed to be called from flows to support bulk regeneration of surveys
 * when survey templates or questions are updated.
 * All operations are bulkified to handle large data volumes efficiently.
 */
public with sharing class SurveyRegenerationController {
	/**
	 * @description Request wrapper for survey regeneration
	 */
	public class RegenerationRequest {
		@InvocableVariable(label='Training Request IDs' description='List of Training Request record IDs to regenerate surveys for' required=true)
		public List<Id> trainingRequestIds;

		@InvocableVariable(label='Regenerate Participant Surveys' description='Regenerate participant survey links' required=false)
		public Boolean regenerateParticipant;

		@InvocableVariable(label='Regenerate Customer Surveys' description='Regenerate customer survey links' required=false)
		public Boolean regenerateCustomer;

		@InvocableVariable(label='Regenerate Trainer Surveys' description='Regenerate trainer survey links' required=false)
		public Boolean regenerateTrainer;
	}

	/**
	 * @description Result wrapper for survey regeneration
	 */
	public class RegenerationResult {
		@InvocableVariable(label='Success' description='Overall operation success status')
		public Boolean success;

		@InvocableVariable(label='Message' description='Summary message of the operation')
		public String message;

		@InvocableVariable(label='Total Processed' description='Total number of Training Requests processed')
		public Integer totalProcessed;

		@InvocableVariable(label='Total Success' description='Number of successful regenerations')
		public Integer totalSuccess;

		@InvocableVariable(label='Total Failed' description='Number of failed regenerations')
		public Integer totalFailed;

		@InvocableVariable(label='Participant Links Generated' description='Number of participant survey links generated')
		public Integer participantLinksGenerated;

		@InvocableVariable(label='Customer Links Generated' description='Number of customer survey links generated')
		public Integer customerLinksGenerated;

		@InvocableVariable(label='Trainer Links Generated' description='Number of trainer survey links generated')
		public Integer trainerLinksGenerated;

		@InvocableVariable(label='Error Details' description='Detailed error information if any')
		public String errorDetails;

		public RegenerationResult() {
			this.success = false;
			this.totalProcessed = 0;
			this.totalSuccess = 0;
			this.totalFailed = 0;
			this.participantLinksGenerated = 0;
			this.customerLinksGenerated = 0;
			this.trainerLinksGenerated = 0;
			this.errorDetails = '';
		}
	}

	/**
	 * @description Regenerate survey links for training requests (Invocable from Flow)
	 * Deletes existing survey invitations and creates new ones with fresh tokens.
	 * Supports bulk operations for multiple training requests.
	 * @param requests List of regeneration requests
	 * @return List<RegenerationResult> Results for each request
	 */
	@InvocableMethod(label='Regenerate Survey Links' description='Regenerate survey links and invitations for training requests' category='Survey Management')
	public static List<RegenerationResult> regenerateSurveyLinks(List<RegenerationRequest> requests) {
		List<RegenerationResult> results = new List<RegenerationResult>();

		if (requests == null || requests.isEmpty()) {
			RegenerationResult result = new RegenerationResult();
			result.message = 'No requests provided';
			results.add(result);
			return results;
		}

		// Process the first request (Flow typically sends one request)
		RegenerationRequest request = requests[0];
		RegenerationResult result = processRegenerationRequest(request);
		results.add(result);

		return results;
	}

	/**
	 * @description Process a single regeneration request
	 * @param request The regeneration request
	 * @return RegenerationResult The result of the operation
	 */
	private static RegenerationResult processRegenerationRequest(RegenerationRequest request) {
		RegenerationResult result = new RegenerationResult();
		List<String> errors = new List<String>();

		try {
			// Validate request
			if (request.trainingRequestIds == null || request.trainingRequestIds.isEmpty()) {
				result.message = 'No Training Request IDs provided';
				return result;
			}

			// Default to regenerate all survey types if none specified
			Boolean regenParticipant = request.regenerateParticipant != null ? request.regenerateParticipant : true;
			Boolean regenCustomer = request.regenerateCustomer != null ? request.regenerateCustomer : true;
			Boolean regenTrainer = request.regenerateTrainer != null ? request.regenerateTrainer : true;

			result.totalProcessed = request.trainingRequestIds.size();

			RegenerationConfig config = resolveRegenerationConfig(request, regenParticipant, regenCustomer, regenTrainer, errors);
			if (config == null) {
				result.message = 'Unable to validate regeneration configuration.';
				result.errorDetails = String.join(errors, '\n');
				return result;
			}

			regenParticipant = config.allowParticipant;
			regenCustomer = config.allowCustomer;
			regenTrainer = config.allowTrainer;

			if (!regenParticipant && !regenCustomer && !regenTrainer) {
				result.message = 'No valid survey types selected after validation.';
				result.errorDetails = String.join(errors, '\n');
				return result;
			}

			List<String> fieldsToQuery = new List<String>{ 'Id' };
			if (regenParticipant && String.isNotBlank(config.participantSurveyField)) {
				fieldsToQuery.add(config.participantSurveyField);
			}
			if (regenCustomer && String.isNotBlank(config.customerSurveyField)) {
				fieldsToQuery.add(config.customerSurveyField);
			}
			if (regenTrainer && String.isNotBlank(config.trainerSurveyField)) {
				fieldsToQuery.add(config.trainerSurveyField);
			}
			if (String.isNotBlank(config.trainingTypeField) && (regenCustomer || regenTrainer)) {
				fieldsToQuery.add(config.trainingTypeField);
			}

			String soql = 'SELECT ' + String.join(fieldsToQuery, ', ') + ' FROM ' + config.objectApiName + ' WHERE Id IN :request.trainingRequestIds WITH USER_MODE';
			List<SObject> relatedRecords = Database.query(soql);
			Map<Id, SObject> relatedRecordMap = new Map<Id, SObject>(relatedRecords);

			if (relatedRecordMap.isEmpty()) {
				result.message = config.isTrainingRequest ? 'No Training Requests found' : 'No records found for ' + config.recordLabelPlural;
				result.errorDetails = String.join(errors, '\n');
				return result;
			}

			Map<Id, Training_Request__c> trainingRequestMap = new Map<Id, Training_Request__c>();
			if (config.isTrainingRequest) {
				for (SObject record : relatedRecords) {
					Training_Request__c tr = (Training_Request__c)record;
					trainingRequestMap.put(tr.Id, tr);
				}
			}

			// Extract survey IDs from URLs
			Map<Id, Id> participantSurveyMap = new Map<Id, Id>();
			Map<Id, Id> customerSurveyMap = new Map<Id, Id>();
			Map<Id, Id> trainerSurveyMap = new Map<Id, Id>();

			for (SObject record : relatedRecordMap.values()) {
				if (regenParticipant && String.isNotBlank(config.participantSurveyField)) {
					Id surveyId = extractSurveyIdFromField(record, config.participantSurveyField);
					if (surveyId != null) {
						participantSurveyMap.put((Id)record.get('Id'), surveyId);
					}
				}

				if (regenCustomer && String.isNotBlank(config.customerSurveyField)) {
					Id surveyId = extractSurveyIdFromField(record, config.customerSurveyField);
					if (surveyId != null) {
						customerSurveyMap.put((Id)record.get('Id'), surveyId);
					}
				}

				if (regenTrainer && String.isNotBlank(config.trainerSurveyField)) {
					Id surveyId = extractSurveyIdFromField(record, config.trainerSurveyField);
					if (surveyId != null) {
						trainerSurveyMap.put((Id)record.get('Id'), surveyId);
					}
				}
			}

			// Collect all survey IDs to query existing invitations
			Set<Id> allSurveyIds = new Set<Id>();
			allSurveyIds.addAll(participantSurveyMap.values());
			allSurveyIds.addAll(customerSurveyMap.values());
			allSurveyIds.addAll(trainerSurveyMap.values());

			// Delete existing survey invitations for these surveys and training requests
			if (!allSurveyIds.isEmpty()) {
				List<SurveyInvitation__c> existingInvitations = [
					SELECT Id
					FROM SurveyInvitation__c
					WHERE Survey__c IN :allSurveyIds AND RelatedRecordId__c IN :request.trainingRequestIds
					WITH USER_MODE
				];

				if (!existingInvitations.isEmpty()) {
					Database.delete(existingInvitations, AccessLevel.USER_MODE);
				}
			}

			// Regenerate participant survey links
			if (regenParticipant && !participantSurveyMap.isEmpty()) {
				Integer count = regenerateParticipantSurveys(participantSurveyMap, trainingRequestMap, errors);
				result.participantLinksGenerated = count;
			} else if (regenParticipant && participantSurveyMap.isEmpty()) {
				errors.add('No participant survey IDs found for regeneration.');
			}

			// Regenerate customer survey links
			if (regenCustomer && !customerSurveyMap.isEmpty()) {
				Integer count = regenerateCustomerTrainerSurveys(
					customerSurveyMap,
					relatedRecordMap,
					config.objectApiName,
					config.trainingTypeField,
					config.customerSurveyField,
					config.recordLabel,
					SurveyForceConstants.SURVEY_TYPE_CUSTOMER,
					errors
				);
				result.customerLinksGenerated = count;
			} else if (regenCustomer && customerSurveyMap.isEmpty()) {
				errors.add('No customer survey IDs found for regeneration.');
			}

			// Regenerate trainer survey links
			if (regenTrainer && !trainerSurveyMap.isEmpty()) {
				Integer count = regenerateCustomerTrainerSurveys(
					trainerSurveyMap,
					relatedRecordMap,
					config.objectApiName,
					config.trainingTypeField,
					config.trainerSurveyField,
					config.recordLabel,
					SurveyForceConstants.SURVEY_TYPE_TRAINER,
					errors
				);
				result.trainerLinksGenerated = count;
			} else if (regenTrainer && trainerSurveyMap.isEmpty()) {
				errors.add('No trainer survey IDs found for regeneration.');
			}

			// Calculate success/failure
			result.totalSuccess = trainingRequestMap.size() - errors.size();
			result.totalFailed = errors.size();
			result.success = errors.isEmpty();

			// Build message
			if (result.success) {
				if (config.isTrainingRequest) {
					result.message = String.format(
						'Successfully regenerated surveys for {0} Training Request(s). Participant: {1}, Customer: {2}, Trainer: {3} links generated.',
						new List<String>{
							String.valueOf(result.totalSuccess),
							String.valueOf(result.participantLinksGenerated),
							String.valueOf(result.customerLinksGenerated),
							String.valueOf(result.trainerLinksGenerated)
						}
					);
				} else {
					result.message = String.format(
						'Successfully regenerated surveys for {0} {1}. Participant: {2}, Customer: {3}, Trainer: {4} links generated.',
						new List<String>{
							String.valueOf(result.totalSuccess),
							config.recordLabelPlural,
							String.valueOf(result.participantLinksGenerated),
							String.valueOf(result.customerLinksGenerated),
							String.valueOf(result.trainerLinksGenerated)
						}
					);
				}
			} else {
				if (config.isTrainingRequest) {
					result.message = String.format(
						'Regenerated surveys for {0} Training Request(s) with {1} error(s). Participant: {2}, Customer: {3}, Trainer: {4} links generated.',
						new List<String>{
							String.valueOf(result.totalSuccess),
							String.valueOf(result.totalFailed),
							String.valueOf(result.participantLinksGenerated),
							String.valueOf(result.customerLinksGenerated),
							String.valueOf(result.trainerLinksGenerated)
						}
					);
				} else {
					result.message = String.format(
						'Regenerated surveys for {0} {1} with {2} error(s). Participant: {3}, Customer: {4}, Trainer: {5} links generated.',
						new List<String>{
							String.valueOf(result.totalSuccess),
							config.recordLabelPlural,
							String.valueOf(result.totalFailed),
							String.valueOf(result.participantLinksGenerated),
							String.valueOf(result.customerLinksGenerated),
							String.valueOf(result.trainerLinksGenerated)
						}
					);
				}
				result.errorDetails = String.join(errors, '\n');
			}

			return result;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyRegenerationController.processRegenerationRequest: ' + e.getMessage() + ' - ' + e.getStackTraceString());
			result.message = 'Error regenerating surveys: ' + e.getMessage();
			result.errorDetails = e.getMessage() + '\n' + e.getStackTraceString();
			return result;
		}
	}

	/**
	 * @description Regenerate participant survey links for multiple training requests
	 * @param participantSurveyMap Map of Training Request ID to Survey ID
	 * @param trainingRequestMap Map of Training Request records
	 * @param errors List to collect errors
	 * @return Integer Number of participant links generated
	 */
	private static Integer regenerateParticipantSurveys(
		Map<Id, Id> participantSurveyMap,
		Map<Id, Training_Request__c> trainingRequestMap,
		List<String> errors
	) {
		Integer linksGenerated = 0;

		try {
			// Get all participants for these training requests
			Set<Id> trainingRequestIds = participantSurveyMap.keySet();
			List<Participants__c> participants = [
				SELECT Id, Training_Request__c, Participant_Name__c, Email__c
				FROM Participants__c
				WHERE Training_Request__c IN :trainingRequestIds
				WITH USER_MODE
			];

			if (participants.isEmpty()) {
				return 0;
			}

			// Regenerate customer or trainer survey links for multiple training requests
			Map<Id, List<Participants__c>> trToParticipantsMap = new Map<Id, List<Participants__c>>();
			for (Participants__c p : participants) {
				if (!trToParticipantsMap.containsKey(p.Training_Request__c)) {
					trToParticipantsMap.put(p.Training_Request__c, new List<Participants__c>());
				}
				trToParticipantsMap.get(p.Training_Request__c).add(p);
			}

			// Generate new invitations for all participants
			List<Participants__c> participantsToUpdate = new List<Participants__c>();

			for (Id trId : participantSurveyMap.keySet()) {
				Id surveyId = participantSurveyMap.get(trId);
				List<Participants__c> trParticipants = trToParticipantsMap.get(trId);

				if (trParticipants != null && !trParticipants.isEmpty()) {
					// Get participant IDs
					Set<Id> participantIds = new Set<Id>();
					for (Participants__c p : trParticipants) {
						participantIds.add(p.Id);
					}

					// Generate survey links in bulk
					Map<Id, SurveyUtilities.ParticipantSurveyResult> results = SurveyUtilities.generateParticipantSurveyLinks(participantIds, surveyId);

					// Update participants with new survey URLs
					for (Id participantId : results.keySet()) {
						SurveyUtilities.ParticipantSurveyResult surveyResult = results.get(participantId);
						if (surveyResult.success && surveyResult.surveyUrl != null) {
							Participants__c p = new Participants__c();
							p.Id = participantId;
							p.Participant_Survey__c = surveyResult.surveyUrl;
							participantsToUpdate.add(p);
							linksGenerated++;
						} else {
							errors.add('Failed to generate participant survey for ' + participantId + ': ' + surveyResult.message);
						}
					}
				}
			}

			// Update participants with new survey URLs
			if (!participantsToUpdate.isEmpty()) {
				Database.update(participantsToUpdate, AccessLevel.USER_MODE);
			}

			return linksGenerated;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyRegenerationController.regenerateParticipantSurveys: ' + e.getMessage());
			errors.add('Error regenerating participant surveys: ' + e.getMessage());
			return linksGenerated;
		}
	}

	/**
	 * @description Regenerate customer or trainer survey links for multiple training requests
	 * @param surveyMap Map of Training Request ID to Survey ID
	 * @param trainingRequestMap Map of Training Request records
	 * @param surveyType Survey type (Customer or Trainer)
	 * @param errors List to collect errors
	 * @return Integer Number of links generated
	 */
	private static Integer regenerateCustomerTrainerSurveys(
		Map<Id, Id> surveyMap,
		Map<Id, SObject> relatedRecordMap,
		String relatedRecordObjectApiName,
		String trainingTypeFieldApiName,
		String surveyFieldApiName,
		String recordLabel,
		String surveyType,
		List<String> errors
	) {
		Integer linksGenerated = 0;

		try {
			if (String.isBlank(surveyFieldApiName)) {
				errors.add('Missing survey field configuration for ' + surveyType + ' on ' + recordLabel + '.');
				return linksGenerated;
			}

			// Build invitation requests for bulk generation
			List<SurveyUtilities.InvitationRequest> invitationRequests = new List<SurveyUtilities.InvitationRequest>();

			for (Id trId : surveyMap.keySet()) {
				Id surveyId = surveyMap.get(trId);
				SObject record = relatedRecordMap.get(trId);
				String trainingType = null;
				if (record != null && String.isNotBlank(trainingTypeFieldApiName)) {
					trainingType = (String)record.get(trainingTypeFieldApiName);
				}

				SurveyUtilities.InvitationRequest invReq = new SurveyUtilities.InvitationRequest();
				invReq.surveyId = surveyId;
				invReq.relatedRecordId = trId;
				invReq.surveyType = surveyType;
				invReq.trainingType = trainingType;

				invitationRequests.add(invReq);
			}

			// Generate invitations in bulk
			if (!invitationRequests.isEmpty()) {
				Map<String, String> surveyTokenUrls = SurveyUtilities.generateSurveyInvitationsInBulk(invitationRequests);

				// Update related records with new survey URLs
				List<SObject> requestsToUpdate = new List<SObject>();
				Schema.SObjectType objectType = Schema.getGlobalDescribe().get(relatedRecordObjectApiName);

				for (Id trId : surveyMap.keySet()) {
					String key = trId + '_' + surveyType;
					String surveyUrl = surveyTokenUrls.get(key);
					Id surveyId = surveyMap.get(trId);

					if (String.isNotBlank(surveyUrl)) {
						SObject recordToUpdate = objectType.newSObject(trId);

						recordToUpdate.put(surveyFieldApiName, surveyUrlWithId);
						requestsToUpdate.add(recordToUpdate);
						linksGenerated++;
					} else {
						errors.add('Failed to generate ' + surveyType + ' survey for ' + recordLabel + ' ' + trId);
					}
				}

				// Update related records
				if (!requestsToUpdate.isEmpty()) {
					Database.update(requestsToUpdate, AccessLevel.USER_MODE);
				}
			}

			return linksGenerated;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyRegenerationController.regenerateCustomerTrainerSurveys: ' + e.getMessage());
			errors.add('Error regenerating ' + surveyType + ' surveys: ' + e.getMessage());
			return linksGenerated;
		}
	}

	/**
	 * @description Configuration details for regeneration
	 */
	private class RegenerationConfig {
		public String objectApiName;
		public String recordLabel;
		public String recordLabelPlural;
		public String participantSurveyField;
		public String customerSurveyField;
		public String trainerSurveyField;
		public String trainingTypeField;
		public Boolean isTrainingRequest;
		public Boolean allowParticipant;
		public Boolean allowCustomer;
		public Boolean allowTrainer;
		public Schema.SObjectType objectType;
	}

	/**
	 * @description Resolve regeneration configuration and validate field access
	 */
	private static RegenerationConfig resolveRegenerationConfig(
		RegenerationRequest request,
		Boolean regenParticipant,
		Boolean regenCustomer,
		Boolean regenTrainer,
		List<String> errors
	) {
		String objectApiName = String.isNotBlank(request.relatedRecordObjectApiName)
			? request.relatedRecordObjectApiName
			: 'Training_Request__c';

		Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
		if (objectType == null) {
			errors.add('Unknown object API name: ' + objectApiName);
			return null;
		}

		Boolean isTrainingRequest = objectApiName == 'Training_Request__c';
		Schema.DescribeSObjectResult describe = objectType.getDescribe();
		RegenerationConfig config = new RegenerationConfig();
		config.objectApiName = objectApiName;
		config.recordLabel = describe.getLabel();
		config.recordLabelPlural = describe.getLabelPlural();
		config.objectType = objectType;
		config.isTrainingRequest = isTrainingRequest;
		config.participantSurveyField = String.isNotBlank(request.participantSurveyFieldApiName)
			? request.participantSurveyFieldApiName
			: (isTrainingRequest ? 'Participant_Survey__c' : null);
		config.customerSurveyField = String.isNotBlank(request.customerSurveyFieldApiName)
			? request.customerSurveyFieldApiName
			: (isTrainingRequest ? 'Customer_Survey__c' : null);
		config.trainerSurveyField = String.isNotBlank(request.trainerSurveyFieldApiName)
			? request.trainerSurveyFieldApiName
			: (isTrainingRequest ? 'Trainer_Survey__c' : null);
		config.trainingTypeField = String.isNotBlank(request.trainingTypeFieldApiName)
			? request.trainingTypeFieldApiName
			: (isTrainingRequest ? 'Training_Type__c' : null);

		Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
		config.allowParticipant = regenParticipant;
		config.allowCustomer = regenCustomer;
		config.allowTrainer = regenTrainer;

		if (regenParticipant) {
			if (!isTrainingRequest) {
				errors.add('Participant regeneration is only supported for Training_Request__c records.');
				config.allowParticipant = false;
			} else if (String.isBlank(config.participantSurveyField) || !fieldMap.containsKey(config.participantSurveyField)) {
				errors.add('Participant survey field not found on ' + config.recordLabel + ': ' + config.participantSurveyField);
				config.allowParticipant = false;
			}
		}

		if (regenCustomer) {
			if (String.isBlank(config.customerSurveyField) || !fieldMap.containsKey(config.customerSurveyField)) {
				errors.add('Customer survey field not found on ' + config.recordLabel + ': ' + config.customerSurveyField);
				config.allowCustomer = false;
			}
		}

		if (regenTrainer) {
			if (String.isBlank(config.trainerSurveyField) || !fieldMap.containsKey(config.trainerSurveyField)) {
				errors.add('Trainer survey field not found on ' + config.recordLabel + ': ' + config.trainerSurveyField);
				config.allowTrainer = false;
			}
		}

		if (String.isNotBlank(config.trainingTypeField) && !fieldMap.containsKey(config.trainingTypeField)) {
			errors.add('Training type field not found on ' + config.recordLabel + ': ' + config.trainingTypeField);
			config.trainingTypeField = null;
		}

		return config;
	}

	/**
	 * @description Extract survey ID from a field on a related record
	 */
	private static Id extractSurveyIdFromField(SObject record, String fieldApiName) {
		if (record == null || String.isBlank(fieldApiName)) {
			return null;
		}

		return extractSurveyIdFromUrl((String)record.get(fieldApiName));
	}

	/**
	 * @description Extract Survey ID from a survey URL
	 * @param surveyUrl The survey URL
	 * @return Id The Survey ID or null if not found
	 */
	private static Id extractSurveyIdFromUrl(String surveyUrl) {
		if (String.isBlank(surveyUrl)) {
			return null;
		}

		try {
			// Extract survey ID from URL (format: /TakeSurvey?id=SURVEY_ID or /survey?token=...)
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
