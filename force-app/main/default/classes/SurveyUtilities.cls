
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

	/** Training type constants */
	private static final String TRAINING_TYPE_EAP = 'EAP Training';
	private static final String SITE_URL_EAP_TRAINING = 'EAP Training';
	private static final String SITE_URL_RESELLER_TRAINING = 'Reseller Training';

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
	 * @param parentId The Training Request ID
	 * @param surveyType Type of survey (Participant, Customer, Trainer)
	 * @param lang Language of the survey (English, Spanish)
	 * @param surveyName Name for the new survey
	 * @return SurveyCreationResult with details of the operation
	 */
	public static SurveyCreationResult createSurveyWithResult(Id parentId, String surveyType, String lang, String surveyName) {
		SurveyCreationResult result = new SurveyCreationResult();

		try {
			// Validate inputs
			if (parentId == null) {
				result.message = 'Training Request ID is required';
				return result;
			}

			if (String.isBlank(surveyName)) {
				result.message = 'Survey name is required';
				return result;
			}

			// Get survey template name
			String surveyTemplateName = getSurveyTemplateName(surveyType, lang);
			if (String.isBlank(surveyTemplateName)) {
				result.message = 'Invalid survey type or language combination';
				return result;
			}

			// Query the survey template
			List<Survey__c> surveyTemplates = [
				SELECT Id, Name, Thank_You_Text__c, Thank_You_Link__c, Survey_Header__c
				FROM Survey__c
				WHERE Name = :surveyTemplateName
				WITH USER_MODE
				LIMIT 1
			];

			if (surveyTemplates.isEmpty()) {
				result.message = 'Survey template not found: ' + surveyTemplateName;
				return result;
			}

			// Query the training request
			List<Training_Request__c> trainingRequests = [
				SELECT Id, Training_Type__c
				FROM Training_Request__c
				WHERE Id = :parentId
				WITH USER_MODE
				LIMIT 1
			];

			if (trainingRequests.isEmpty()) {
				result.message = 'Training Request not found';
				return result;
			}

			Training_Request__c tReq = trainingRequests[0];
			Survey__c template = surveyTemplates[0];

			// Get questions for the template
			List<Survey_Question__c> templateQuestions = [
				SELECT
					Id,
					Name,
					Question__c,
					Type__c,
					Choices__c,
					OrderNumber__c,
					Required__c
				FROM Survey_Question__c
				WHERE Survey__c = :template.Id
				WITH USER_MODE
				ORDER BY OrderNumber__c ASC
			];

			// Get site URL
			String siteURL = getSiteURLForTrainingType(tReq.Training_Type__c);
			if (String.isBlank(siteURL)) {
				result.message = 'Site URL not configured for training type: ' + tReq.Training_Type__c;
				return result;
			}

			// Clone the survey
			Survey__c newSurvey = template.clone(false, true, false, false);
			newSurvey.Name = surveyName;

			Database.insert(newSurvey, AccessLevel.USER_MODE);

			// Clone all questions
			List<Survey_Question__c> newQuestions = new List<Survey_Question__c>();
			for (Survey_Question__c q : templateQuestions) {
				Survey_Question__c newQ = q.clone(false, true, false, false);
				newQ.Survey__c = newSurvey.Id;
				newQuestions.add(newQ);
			}

			if (!newQuestions.isEmpty()) {
				Database.insert(newQuestions, AccessLevel.USER_MODE);
			}

			// Build survey URL
			String surveyURL = siteURL + '/TakeSurvey?id=' + newSurvey.Id;

			result.success = true;
			result.message = 'Survey created successfully';
			result.surveyId = newSurvey.Id;
			result.surveyUrl = surveyURL;

			return result;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyUtilities.createSurveyWithResult: ' + e.getMessage() + ' - ' + e.getStackTraceString());
			result.message = 'Error creating survey: ' + e.getMessage();
			return result;
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
	 * @description Get the site URL for a given training type
	 * @param trainingType The training type
	 * @return String Site URL or null if not found
	 */
	private static String getSiteURLForTrainingType(String trainingType) {
		Map<String, SiteURL__c> csSite = SiteURL__c.getAll();

		if (csSite == null || csSite.isEmpty()) {
			return null;
		}

		String siteURL = null;
		if (trainingType == TRAINING_TYPE_EAP && csSite.containsKey(SITE_URL_EAP_TRAINING)) {
			siteURL = csSite.get(SITE_URL_EAP_TRAINING).URL__c;
		} else if (csSite.containsKey(SITE_URL_RESELLER_TRAINING)) {
			siteURL = csSite.get(SITE_URL_RESELLER_TRAINING).URL__c;
		}

		return siteURL;
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

			// Verify survey exists
			List<Survey__c> surveys = [
				SELECT Id, Name
				FROM Survey__c
				WHERE Id = :surveyId
				WITH USER_MODE
				LIMIT 1
			];

			if (surveys.isEmpty()) {
				for (Id participantId : participantIds) {
					ParticipantSurveyResult result = new ParticipantSurveyResult();
					result.participantId = participantId;
					result.success = false;
					result.message = 'Survey not found';
					results.put(participantId, result);
				}
				return results;
			}

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

			// Insert all invitations at once
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
	 * @description Generate a single survey invitation with token for Customer/Trainer surveys
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