
/**
 * @description Utility class for creating and managing surveys from templates.
 * Provides methods to clone survey templates and generate unique survey links
 * for training requests and participants. All methods are bulkified to handle
 * large data volumes efficiently.
 */
public with sharing class SurveyUtilities {
	/** Survey type constants */
	public enum SurveyType {
		PARTICIPANT,
		CUSTOMER,
		TRAINER
	}

	/** Language constants */
	public enum Language {
		ENGLISH,
		SPANISH
	}

	/** Site URL constants for custom metadata DeveloperNames */
	private static final String SITE_URL_EAP_TRAINING = 'EAP_Training';
	private static final String SITE_URL_RESELLER_TRAINING = 'Reseller_Training';

	/**
	 * @description Wrapper class for survey creation results
	 */
	public class SurveyCreationResult {
		public Boolean success { get; set; }
		public String message { get; set; }
		public Id surveyId { get; set; }
		public String surveyUrl { get; set; }
		public Id sourceRecordId { get; set; }

		public SurveyCreationResult() {
			this.success = false;
		}
	}

	/**
	 * @description Wrapper class for participant survey link generation
	 */
	public class ParticipantSurveyResult {
		public Id participantId { get; set; }
		public String surveyUrl { get; set; }
		public Boolean success { get; set; }
		public String message { get; set; }
	}

	/**
	 * @description Create a new survey from a template for a training request
	 * @param parentId The Training Request ID
	 * @param surveyType Type of survey (Participant, Customer, Trainer)
	 * @param lang Language of the survey (English, Spanish)
	 * @param surveyName Name for the new survey
	 * @return String Survey URL if successful, null otherwise
	 */
	public static String createSurvey(Id parentId, String surveyType, String lang, String surveyName) {
		SurveyCreationResult result = createSurveyWithResult(parentId, surveyType, lang, surveyName);
		return result.success ? result.surveyUrl : null;
	}

	/**
	 * @description Create a new survey from a template with detailed result
	 * Delegates to bulkified method to avoid SOQL in loops
	 * @param parentId The Training Request ID
	 * @param surveyType Type of survey (Participant, Customer, Trainer)
	 * @param lang Language of the survey (English, Spanish)
	 * @param surveyName Name for the new survey
	 * @return SurveyCreationResult with details of the operation
	 */
	public static SurveyCreationResult createSurveyWithResult(Id parentId, String surveyType, String lang, String surveyName) {
		// Use bulkified method for consistency and to avoid LIMIT 1 queries
		SurveyCreationRequest request = new SurveyCreationRequest(parentId, surveyType, lang, surveyName);
		Map<String, SurveyCreationResult> results = createSurveysInBulk(new List<SurveyCreationRequest>{ request });
		
		String key = parentId + '_' + surveyType;
		if (results.containsKey(key)) {
			return results.get(key);
		}
		
		// Fallback if key not found
		SurveyCreationResult result = new SurveyCreationResult();
		result.message = 'Survey creation failed';
		return result;
	}

	/**
	 * @description Bulk create surveys for multiple training requests
	 * Optimized to avoid SOQL in loops and reduce governor limit usage
	 * @param requests List of survey creation requests with training request ID, survey type, language, and name
	 * @return Map<String, SurveyCreationResult> Map of unique key (trainingRequestId + surveyType) to result
	 */
	public static Map<String, SurveyCreationResult> createSurveysInBulk(List<SurveyCreationRequest> requests) {
		Map<String, SurveyCreationResult> results = new Map<String, SurveyCreationResult>();
		
		if (requests == null || requests.isEmpty()) {
			return results;
		}

		try {
			// Collect all template names and training request IDs
			Set<String> templateNames = new Set<String>();
			Set<Id> trainingRequestIds = new Set<Id>();
			
			for (SurveyCreationRequest req : requests) {
				String templateName = getSurveyTemplateName(req.surveyType, req.language);
				if (String.isNotBlank(templateName)) {
					templateNames.add(templateName);
				}
				if (req.trainingRequestId != null) {
					trainingRequestIds.add(req.trainingRequestId);
				}
			}

			// Single SOQL query for all templates
			Map<String, Survey__c> templateMap = new Map<String, Survey__c>();
			for (Survey__c template : [
				SELECT Id, Name, Thank_You_Text__c, Thank_You_Link__c, Survey_Header__c
				FROM Survey__c
				WHERE Name IN :templateNames
				WITH USER_MODE
			]) {
				templateMap.put(template.Name, template);
			}

			// Single SOQL query for all training requests (for validation)
			Map<Id, Training_Request__c> trainingRequestMap = new Map<Id, Training_Request__c>([
				SELECT Id
				FROM Training_Request__c
				WHERE Id IN :trainingRequestIds
				WITH USER_MODE
			]);

			// Collect all template IDs for questions query
			Set<Id> templateIds = new Set<Id>();
			for (Survey__c template : templateMap.values()) {
				templateIds.add(template.Id);
			}

			// Single SOQL query for all template questions
			Map<Id, List<Survey_Question__c>> templateQuestionsMap = new Map<Id, List<Survey_Question__c>>();
			for (Survey_Question__c question : [
				SELECT Id, Name, Question__c, Type__c, Choices__c, OrderNumber__c, Required__c, Survey__c
				FROM Survey_Question__c
				WHERE Survey__c IN :templateIds
				WITH USER_MODE
				ORDER BY Survey__c, OrderNumber__c ASC
			]) {
				if (!templateQuestionsMap.containsKey(question.Survey__c)) {
					templateQuestionsMap.put(question.Survey__c, new List<Survey_Question__c>());
				}
				templateQuestionsMap.get(question.Survey__c).add(question);
			}

			// Process each request
			List<Survey__c> surveysToInsert = new List<Survey__c>();
			Map<Integer, SurveyCreationRequest> indexToRequestMap = new Map<Integer, SurveyCreationRequest>();
			
			for (Integer i = 0; i < requests.size(); i++) {
				SurveyCreationRequest req = requests[i];
				String key = req.trainingRequestId + '_' + req.surveyType;
				SurveyCreationResult result = new SurveyCreationResult();
				result.sourceRecordId = req.trainingRequestId;

				// Validate request
				if (req.trainingRequestId == null) {
					result.message = 'Training Request ID is required';
					results.put(key, result);
					continue;
				}

				if (String.isBlank(req.surveyName)) {
					result.message = 'Survey name is required';
					results.put(key, result);
					continue;
				}

				String templateName = getSurveyTemplateName(req.surveyType, req.language);
				if (String.isBlank(templateName)) {
					result.message = 'Invalid survey type or language combination';
					results.put(key, result);
					continue;
				}

				if (!templateMap.containsKey(templateName)) {
					result.message = 'Survey template not found: ' + templateName;
					results.put(key, result);
					continue;
				}

				if (!trainingRequestMap.containsKey(req.trainingRequestId)) {
					result.message = 'Training Request not found';
					results.put(key, result);
					continue;
				}

				// Clone survey
				Survey__c template = templateMap.get(templateName);
				Survey__c newSurvey = template.clone(false, true, false, false);
				newSurvey.Name = req.surveyName;
				
				surveysToInsert.add(newSurvey);
				indexToRequestMap.put(i, req);
				results.put(key, result);
			}

			// Bulk insert surveys
			if (!surveysToInsert.isEmpty()) {
				Database.insert(surveysToInsert, AccessLevel.USER_MODE);

				// Clone questions for each survey
				List<Survey_Question__c> allQuestionsToInsert = new List<Survey_Question__c>();
				
				for (Integer i = 0; i < surveysToInsert.size(); i++) {
					Survey__c newSurvey = surveysToInsert[i];
					SurveyCreationRequest req = indexToRequestMap.get(i);
					String key = req.trainingRequestId + '_' + req.surveyType;
					String templateName = getSurveyTemplateName(req.surveyType, req.language);
					Survey__c template = templateMap.get(templateName);

					// Clone questions for this survey
					List<Survey_Question__c> templateQuestions = templateQuestionsMap.get(template.Id);
					if (templateQuestions != null) {
						for (Survey_Question__c q : templateQuestions) {
							Survey_Question__c newQ = q.clone(false, true, false, false);
							newQ.Survey__c = newSurvey.Id;
							allQuestionsToInsert.add(newQ);
						}
					}

					// Build result
					String siteURL = getDefaultSiteURL();
					SurveyCreationResult result = results.get(key);
					
					if (String.isBlank(siteURL)) {
						result.message = 'Site URL not configured';
					} else {
						result.success = true;
						result.message = 'Survey created successfully';
						result.surveyId = newSurvey.Id;
						result.surveyUrl = siteURL + '/TakeSurvey?id=' + newSurvey.Id;
					}
				}

				// Bulk insert all questions
				if (!allQuestionsToInsert.isEmpty()) {
					Database.insert(allQuestionsToInsert, AccessLevel.USER_MODE);
				}
			}

			return results;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyUtilities.createSurveysInBulk: ' + e.getMessage() + ' - ' + e.getStackTraceString());
			// Return error results for all requests
			for (SurveyCreationRequest req : requests) {
				String key = req.trainingRequestId + '_' + req.surveyType;
				if (!results.containsKey(key)) {
					SurveyCreationResult result = new SurveyCreationResult();
					result.sourceRecordId = req.trainingRequestId;
					result.message = 'Error: ' + e.getMessage();
					results.put(key, result);
				}
			}
			return results;
		}
	}

	/**
	 * @description Wrapper class for bulk survey creation requests
	 */
	public class SurveyCreationRequest {
		public Id trainingRequestId { get; set; }
		public String surveyType { get; set; }
		public String language { get; set; }
		public String surveyName { get; set; }

		public SurveyCreationRequest(Id trainingRequestId, String surveyType, String language, String surveyName) {
			this.trainingRequestId = trainingRequestId;
			this.surveyType = surveyType;
			this.language = language;
			this.surveyName = surveyName;
		}
	}

	/**
	 * @description Get the survey template name based on survey type and language
	 * @param surveyType Type of survey (Participant, Customer, Trainer)
	 * @param lang Language (English, Spanish)
	 * @return String Template name or null if invalid combination
	 */
	public static String getSurveyTemplateName(String surveyType, String lang) {
		if (String.isBlank(surveyType) || String.isBlank(lang)) {
			return null;
		}

		String normalizedType = surveyType.trim();
		String normalizedLang = lang.trim();

		if (normalizedType.equalsIgnoreCase('Participant')) {
			if (normalizedLang.equalsIgnoreCase('English')) {
				return 'PartcipantSurveyTemplate';
			} else if (normalizedLang.equalsIgnoreCase('Spanish')) {
				return 'PartcipantSurveyTemplate Spanish';
			}
		} else if (normalizedType.equalsIgnoreCase('Customer')) {
			return 'CustomerSurveyTemplate';
		} else if (normalizedType.equalsIgnoreCase('Trainer')) {
			return 'TrainerSurveyTemplate';
		}

		return null;
	}

	/**
	 * @description Get the default site URL from custom metadata
	 * @return String Site URL or null if not found
	 */
	private static String getDefaultSiteURL() {
		// Query custom metadata for site URLs, ordered by DeveloperName for deterministic behavior
		List<SiteURL__mdt> siteURLs = [
			SELECT URL__c 
			FROM SiteURL__mdt 
			WHERE DeveloperName = :SITE_URL_EAP_TRAINING
			OR DeveloperName = :SITE_URL_RESELLER_TRAINING
			ORDER BY DeveloperName ASC
			LIMIT 1
		];

		if (!siteURLs.isEmpty() && String.isNotBlank(siteURLs[0].URL__c)) {
			return siteURLs[0].URL__c;
		}

		return null;
	}

	/**
	 * @description Generate unique survey invitations for multiple participants (bulkified)
	 * @param participantIds Set of Participant record IDs
	 * @param surveyId The Survey ID to generate invitations for
	 * @return Map<Id, ParticipantSurveyResult> Map of Participant ID to survey result
	 */
	public static Map<Id, ParticipantSurveyResult> generateParticipantSurveyLinks(Set<Id> participantIds, Id surveyId) {
		Map<Id, ParticipantSurveyResult> results = new Map<Id, ParticipantSurveyResult>();

		try {
			if (participantIds == null || participantIds.isEmpty() || surveyId == null) {
				return results;
			}

			// Query all participants at once
			Map<Id, Participants__c> participantsMap = new Map<Id, Participants__c>([
				SELECT Id, Participant_Name__c, Email__c, Training_Request__c
				FROM Participants__c
				WHERE Id IN :participantIds
				WITH USER_MODE
			]);

			// Bulk create invitations
			List<SurveyInvitation__c> invitations = new List<SurveyInvitation__c>();
			Map<String, Id> tokenToParticipantMap = new Map<String, Id>();

			for (Participants__c participant : participantsMap.values()) {
				String token = generateUniqueToken();
				
				SurveyInvitation__c invitation = new SurveyInvitation__c();
				invitation.Survey__c = surveyId;
				invitation.Token__c = token;
				invitation.Status__c = 'Pending';
				invitation.Email__c = participant.Email__c;
				invitation.ParticipantName__c = participant.Participant_Name__c;
				invitation.RelatedRecordId__c = participant.Training_Request__c;
				
				invitations.add(invitation);
				tokenToParticipantMap.put(token, participant.Id);
			}

			// Insert all invitations at once (will fail if survey doesn't exist due to lookup validation)
			if (!invitations.isEmpty()) {
				Database.insert(invitations, AccessLevel.USER_MODE);

				// Build results with URLs
				for (SurveyInvitation__c inv : invitations) {
					Id participantId = tokenToParticipantMap.get(inv.Token__c);
					ParticipantSurveyResult result = new ParticipantSurveyResult();
					result.participantId = participantId;
					result.success = true;
					result.surveyUrl = buildSurveyUrlWithToken(inv.Token__c);
					result.message = 'Survey link generated successfully';
					results.put(participantId, result);
				}
			}

			return results;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyUtilities.generateParticipantSurveyLinks: ' + e.getMessage());
			// Return error results for all participants
			for (Id participantId : participantIds) {
				if (!results.containsKey(participantId)) {
					ParticipantSurveyResult result = new ParticipantSurveyResult();
					result.participantId = participantId;
					result.success = false;
					result.message = 'Error: ' + e.getMessage();
					results.put(participantId, result);
				}
			}
			return results;
		}
	}

	/**
	 * @description Generate a unique survey invitation for a single participant
	 * @param participantId The Participant record ID
	 * @param surveyId The Survey ID to generate invitation for
	 * @return String Unique survey URL with token, or null if failed
	 */
	public static String generateParticipantSurveyLink(Id participantId, Id surveyId) {
		Set<Id> participantIds = new Set<Id>{ participantId };
		Map<Id, ParticipantSurveyResult> results = generateParticipantSurveyLinks(participantIds, surveyId);
		
		if (results.containsKey(participantId) && results.get(participantId).success) {
			return results.get(participantId).surveyUrl;
		}
		
		return null;
	}

	/**
	 * @description Create participant surveys from main training request survey (bulkified)
	 * @param trainingRequestId The Training Request ID
	 * @param mainSurveyId The main survey to use for participant invitations
	 * @return Map<Id, String> Map of Participant ID to Survey URL
	 */
	public static Map<Id, String> createParticipantSurveys(Id trainingRequestId, Id mainSurveyId) {
		Map<Id, String> participantSurveyLinks = new Map<Id, String>();

		try {
			if (trainingRequestId == null || mainSurveyId == null) {
				return participantSurveyLinks;
			}

			// Query all participants for this training request
			List<Participants__c> participants = [
				SELECT Id, Participant_Name__c, Email__c, Training_Request__c
				FROM Participants__c
				WHERE Training_Request__c = :trainingRequestId
				WITH USER_MODE
			];

			if (participants.isEmpty()) {
				return participantSurveyLinks;
			}

			// Get all participant IDs
			Set<Id> participantIds = new Set<Id>();
			for (Participants__c p : participants) {
				participantIds.add(p.Id);
			}

			// Generate links in bulk
			Map<Id, ParticipantSurveyResult> results = generateParticipantSurveyLinks(participantIds, mainSurveyId);

			// Extract URLs from results
			for (Id participantId : results.keySet()) {
				ParticipantSurveyResult result = results.get(participantId);
				if (result.success && result.surveyUrl != null) {
					participantSurveyLinks.put(participantId, result.surveyUrl);
				}
			}

			return participantSurveyLinks;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyUtilities.createParticipantSurveys: ' + e.getMessage());
			return participantSurveyLinks;
		}
	}

	/**
	 * @description Generate a unique token for survey invitation
	 * @return String UUID-style token
	 */
	private static String generateUniqueToken() {
		Blob b = Crypto.generateAesKey(128);
		String h = EncodingUtil.convertToHex(b);
		return h.substring(0, 8) + '-' + h.substring(8, 12) + '-' + h.substring(12, 16) + '-' + h.substring(16, 20) + '-' + h.substring(20);
	}

	/**
	 * @description Build survey URL with token
	 * @param token The invitation token
	 * @return String Complete survey URL
	 */
	private static String buildSurveyUrlWithToken(String token) {
		String baseUrl = '';
		if (Site.getBaseUrl() != null && String.isNotBlank(Site.getBaseUrl())) {
			baseUrl = Site.getBaseUrl();
		} else {
			baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
		}
		return baseUrl + '/survey?token=' + token;
	}

	/**
	 * @description Generate survey invitations in bulk with tokens
	 * Optimized for bulk operations to avoid DML in loops
	 * @param invitationRequests List of invitation requests with survey ID, related record ID, and survey type
	 * @return Map<String, String> Map of key (surveyId + '_' + surveyType) to token-based URL
	 */
	public static Map<String, String> generateSurveyInvitationsInBulk(List<InvitationRequest> invitationRequests) {
		Map<String, String> results = new Map<String, String>();
		
		try {
			if (invitationRequests == null || invitationRequests.isEmpty()) {
				return results;
			}

			List<SurveyInvitation__c> invitationsToInsert = new List<SurveyInvitation__c>();
			Map<Integer, InvitationRequest> indexToRequestMap = new Map<Integer, InvitationRequest>();
			
			for (Integer i = 0; i < invitationRequests.size(); i++) {
				InvitationRequest req = invitationRequests[i];
				
				if (req.surveyId == null) {
					continue;
				}

				String token = generateUniqueToken();
				
				SurveyInvitation__c invitation = new SurveyInvitation__c();
				invitation.Survey__c = req.surveyId;
				invitation.Token__c = token;
				invitation.Status__c = 'Pending';
				invitation.ParticipantName__c = req.surveyType + ' Survey';
				invitation.RelatedRecordId__c = req.relatedRecordId;
				
				invitationsToInsert.add(invitation);
				indexToRequestMap.put(i, req);
			}

			// Bulk insert all invitations
			if (!invitationsToInsert.isEmpty()) {
				Database.insert(invitationsToInsert, AccessLevel.USER_MODE);

				// Build results map
				for (Integer i = 0; i < invitationsToInsert.size(); i++) {
					SurveyInvitation__c invitation = invitationsToInsert[i];
					InvitationRequest req = indexToRequestMap.get(i);
					String key = req.relatedRecordId + '_' + req.surveyType;
					results.put(key, buildSurveyUrlWithToken(invitation.Token__c));
				}
			}

			return results;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyUtilities.generateSurveyInvitationsInBulk: ' + e.getMessage() + ' - ' + e.getStackTraceString());
			return results;
		}
	}

	/**
	 * @description Wrapper class for bulk invitation requests
	 */
	public class InvitationRequest {
		public Id surveyId { get; set; }
		public Id relatedRecordId { get; set; }
		public String surveyType { get; set; }

		public InvitationRequest(Id surveyId, Id relatedRecordId, String surveyType) {
			this.surveyId = surveyId;
			this.relatedRecordId = relatedRecordId;
			this.surveyType = surveyType;
		}
	}

	/**
	 * @description Generate a single survey invitation with token for Customer/Trainer surveys
	 * Note: For bulk operations, use generateSurveyInvitationsInBulk instead
	 * @param surveyId The Survey ID
	 * @param trainingRequestId The Training Request ID (for related record tracking)
	 * @param surveyType The type of survey (Customer, Trainer, etc.)
	 * @return String Token-based survey URL or null if failed
	 */
	public static String generateSingleSurveyInvitation(Id surveyId, Id trainingRequestId, String surveyType) {
		try {
			if (surveyId == null) {
				return null;
			}

			String token = generateUniqueToken();

			SurveyInvitation__c invitation = new SurveyInvitation__c();
			invitation.Survey__c = surveyId;
			invitation.Token__c = token;
			invitation.Status__c = 'Pending';
			invitation.ParticipantName__c = surveyType + ' Survey';
			invitation.RelatedRecordId__c = trainingRequestId;

			Database.insert(invitation, AccessLevel.USER_MODE);

			return buildSurveyUrlWithToken(token);
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyUtilities.generateSingleSurveyInvitation: ' + e.getMessage());
			return null;
		}
	}
}