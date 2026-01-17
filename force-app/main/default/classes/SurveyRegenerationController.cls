/**
 * @description Controller for regenerating survey links and invitations.
 * Designed to be called from LWC to support bulk regeneration of surveys
 * when survey templates or questions are updated.
 * All operations are bulkified to handle large data volumes efficiently.
 */
public with sharing class SurveyRegenerationController {
	/**
	 * @description Request wrapper for survey regeneration
	 */
	public class RegenerationRequest {
		@AuraEnabled
		public List<Id> trainingRequestIds;

		@AuraEnabled
		public Boolean regenerateParticipant;

		@AuraEnabled
		public Boolean regenerateCustomer;

		@AuraEnabled
		public Boolean regenerateTrainer;

		@AuraEnabled
		public String relatedRecordObjectApiName;

		@AuraEnabled
		public String participantSurveyFieldApiName;

		@AuraEnabled
		public String participantSurveyLinkFieldApiName;

		@AuraEnabled
		public String participantObjectApiName;

		@AuraEnabled
		public String participantLookupFieldApiName;

		@AuraEnabled
		public String participantNameFieldApiName;

		@AuraEnabled
		public String participantEmailFieldApiName;

		@AuraEnabled
		public String customerSurveyFieldApiName;

		@AuraEnabled
		public String trainerSurveyFieldApiName;

		@AuraEnabled
		public String trainingTypeFieldApiName;
	}

	/**
	 * @description Result wrapper for survey regeneration
	 */
	public class RegenerationResult {
		@AuraEnabled
		public Boolean success;

		@AuraEnabled
		public String message;

		@AuraEnabled
		public Integer totalProcessed;

		@AuraEnabled
		public Integer totalSuccess;

		@AuraEnabled
		public Integer totalFailed;

		@AuraEnabled
		public Integer participantLinksGenerated;

		@AuraEnabled
		public Integer customerLinksGenerated;

		@AuraEnabled
		public Integer trainerLinksGenerated;

		@AuraEnabled
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
	 * @description Regenerate survey links for training requests
	 * Deletes existing survey invitations and creates new ones with fresh tokens.
	 * Supports bulk operations for multiple training requests.
	 * @param requests List of regeneration requests
	 * @return List<RegenerationResult> Results for each request
	 */
	@AuraEnabled
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
				Integer count = regenerateParticipantSurveys(
					participantSurveyMap,
					relatedRecordMap,
					config,
					errors
				);
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
	 * @description Regenerate participant survey links for multiple related records
	 * @param participantSurveyMap Map of Related Record ID to Survey ID
	 * @param relatedRecordMap Map of related records
	 * @param config Regeneration configuration
	 * @param errors List to collect errors
	 * @return Integer Number of participant links generated
	 */
	private static Integer regenerateParticipantSurveys(
		Map<Id, Id> participantSurveyMap,
		Map<Id, SObject> relatedRecordMap,
		RegenerationConfig config,
		List<String> errors
	) {
		Integer linksGenerated = 0;

		try {
			if (config == null) {
				errors.add('Participant configuration is missing.');
				return 0;
			}

			if (String.isBlank(config.participantObjectApiName) || String.isBlank(config.participantLookupField)) {
				errors.add('Participant object configuration is incomplete.');
				return 0;
			}

			// Get all participants for these related records
			Set<Id> relatedRecordIds = participantSurveyMap.keySet();
			List<String> participantFields = new List<String>{
				'Id',
				config.participantLookupField,
				config.participantNameField,
				config.participantEmailField
			};
			String participantSoql =
				'SELECT ' +
				String.join(participantFields, ', ') +
				' FROM ' +
				config.participantObjectApiName +
				' WHERE ' +
				config.participantLookupField +
				' IN :relatedRecordIds WITH USER_MODE';
			List<SObject> participants = Database.query(participantSoql);

			if (participants.isEmpty()) {
				return 0;
			}

			Map<Id, List<SObject>> recordToParticipantsMap = new Map<Id, List<SObject>>();
			for (SObject participant : participants) {
				Id relatedRecordId = (Id)participant.get(config.participantLookupField);
				if (relatedRecordId == null) {
					continue;
				}
				if (!recordToParticipantsMap.containsKey(relatedRecordId)) {
					recordToParticipantsMap.put(relatedRecordId, new List<SObject>());
				}
				recordToParticipantsMap.get(relatedRecordId).add(participant);
			}

			// Generate new invitations for all participants
			List<SObject> participantsToUpdate = new List<SObject>();
			List<SurveyInvitation__c> invitations = new List<SurveyInvitation__c>();
			Map<String, Id> tokenToParticipantMap = new Map<String, Id>();
			Map<Id, Id> participantToSurveyMap = new Map<Id, Id>();

			for (Id recordId : participantSurveyMap.keySet()) {
				Id surveyId = participantSurveyMap.get(recordId);
				List<SObject> relatedParticipants = recordToParticipantsMap.get(recordId);

				if (relatedParticipants != null && !relatedParticipants.isEmpty()) {
					for (SObject participant : relatedParticipants) {
						String token = SurveyUtilities.generateUniqueTokenForRegeneration();
						if (String.isBlank(token)) {
							errors.add('Failed to generate token for participant ' + participant.get('Id'));
							continue;
						}

						SurveyInvitation__c invitation = new SurveyInvitation__c();
						invitation.Survey__c = surveyId;
						invitation.Token__c = token;
						invitation.Status__c = SurveyForceConstants.STATUS_PENDING;
						invitation.Email__c = (String)participant.get(config.participantEmailField);
						invitation.ParticipantName__c = (String)participant.get(config.participantNameField);
						invitation.RelatedRecordId__c = recordId;

						invitations.add(invitation);
						tokenToParticipantMap.put(token, (Id)participant.get('Id'));
						participantToSurveyMap.put((Id)participant.get('Id'), surveyId);
					}
				}
			}

			if (!invitations.isEmpty()) {
				Database.insert(invitations, AccessLevel.USER_MODE);

				Schema.SObjectType participantType = Schema.getGlobalDescribe().get(config.participantObjectApiName);

				for (SurveyInvitation__c invitation : invitations) {
					Id participantId = tokenToParticipantMap.get(invitation.Token__c);
					Id surveyId = participantToSurveyMap.get(participantId);
					if (participantId == null || surveyId == null) {
						continue;
					}

					String trainingType = null;
					if (String.isNotBlank(config.trainingTypeField) && relatedRecordMap.containsKey(invitation.RelatedRecordId__c)) {
						trainingType = (String)relatedRecordMap.get(invitation.RelatedRecordId__c).get(config.trainingTypeField);
					}
					String surveyUrl = SurveyUtilities.buildSurveyUrlWithTokenForRegeneration(
						invitation.Token__c,
						trainingType
					);
					if (String.isBlank(surveyUrl)) {
						errors.add('Failed to build participant survey URL for ' + participantId);
						continue;
					}

					SObject participantUpdate = participantType.newSObject(participantId);
					participantUpdate.put(config.participantSurveyLinkField, surveyUrl);
					participantsToUpdate.add(participantUpdate);
					linksGenerated++;
				}
			}

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
						String surveyUrlWithId = appendSurveyIdToUrl(surveyUrl, surveyId);

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
		public String participantSurveyLinkField;
		public String participantObjectApiName;
		public String participantLookupField;
		public String participantNameField;
		public String participantEmailField;
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
		config.participantSurveyLinkField = String.isNotBlank(request.participantSurveyLinkFieldApiName)
			? request.participantSurveyLinkFieldApiName
			: (isTrainingRequest ? 'Participant_Survey__c' : null);
		config.participantObjectApiName = String.isNotBlank(request.participantObjectApiName)
			? request.participantObjectApiName
			: (isTrainingRequest ? 'Participants__c' : null);
		config.participantLookupField = String.isNotBlank(request.participantLookupFieldApiName)
			? request.participantLookupFieldApiName
			: (isTrainingRequest ? 'Training_Request__c' : null);
		config.participantNameField = String.isNotBlank(request.participantNameFieldApiName)
			? request.participantNameFieldApiName
			: (isTrainingRequest ? 'Participant_Name__c' : null);
		config.participantEmailField = String.isNotBlank(request.participantEmailFieldApiName)
			? request.participantEmailFieldApiName
			: (isTrainingRequest ? 'Email__c' : null);
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
			if (String.isBlank(config.participantSurveyField) || !fieldMap.containsKey(config.participantSurveyField)) {
				errors.add('Participant survey field not found on ' + config.recordLabel + ': ' + config.participantSurveyField);
				config.allowParticipant = false;
			} else if (String.isBlank(config.participantObjectApiName)) {
				errors.add('Participant object API name is required when regenerating participant surveys.');
				config.allowParticipant = false;
			} else {
				Schema.SObjectType participantType = Schema.getGlobalDescribe().get(config.participantObjectApiName);
				if (participantType == null) {
					errors.add('Participant object API name is invalid: ' + config.participantObjectApiName);
					config.allowParticipant = false;
				} else {
					Map<String, Schema.SObjectField> participantFieldMap = participantType.getDescribe().fields.getMap();
					if (String.isBlank(config.participantLookupField) || !participantFieldMap.containsKey(config.participantLookupField)) {
						errors.add(
							'Participant lookup field not found on ' +
							config.participantObjectApiName +
							': ' +
							config.participantLookupField
						);
						config.allowParticipant = false;
					}
					if (String.isBlank(config.participantNameField) || !participantFieldMap.containsKey(config.participantNameField)) {
						errors.add(
							'Participant name field not found on ' +
							config.participantObjectApiName +
							': ' +
							config.participantNameField
						);
						config.allowParticipant = false;
					}
					if (String.isBlank(config.participantEmailField) || !participantFieldMap.containsKey(config.participantEmailField)) {
						errors.add(
							'Participant email field not found on ' +
							config.participantObjectApiName +
							': ' +
							config.participantEmailField
						);
						config.allowParticipant = false;
					}
					if (
						String.isBlank(config.participantSurveyLinkField) ||
						!participantFieldMap.containsKey(config.participantSurveyLinkField)
					) {
						errors.add(
							'Participant survey field not found on ' +
							config.participantObjectApiName +
							': ' +
							config.participantSurveyLinkField
						);
						config.allowParticipant = false;
					}
				}
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
	 * @description Append the Survey Id to a token-based survey URL if missing
	 * @param surveyUrl The token-based survey URL
	 * @param surveyId The Survey Id
	 * @return String Survey URL with id parameter appended
	 */
	private static String appendSurveyIdToUrl(String surveyUrl, Id surveyId) {
		if (String.isBlank(surveyUrl) || surveyId == null) {
			return surveyUrl;
		}

		if (surveyUrl.contains('id=')) {
			return surveyUrl;
		}

		String separator = surveyUrl.contains('?') ? '&' : '?';
		return surveyUrl + separator + 'id=' + String.valueOf(surveyId);
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
