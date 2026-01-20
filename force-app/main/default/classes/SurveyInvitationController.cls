/**
 * @description Controller for managing survey invitations with unique tokens.
 * Handles generation of unique survey URLs, validation of invitation tokens,
 * and completion tracking to ensure each invitation can only be used once.
 * Supports dynamic expiration based on event dates (e.g., training event dates)
 * from related objects, calculating expiration as event date + configured days.
 */
public with sharing class SurveyInvitationController {
	/** Survey invitation status constants */
	private static final String STATUS_PENDING = SurveyForceConstants.STATUS_PENDING;
	private static final String STATUS_COMPLETED = SurveyForceConstants.STATUS_COMPLETED;
	private static final String STATUS_EXPIRED = SurveyForceConstants.STATUS_EXPIRED;

	/**
	 * @description Wrapper class for invitation generation results
	 */
	public class InvitationResult {
		@AuraEnabled
		public Boolean success { get; set; }
		@AuraEnabled
		public String message { get; set; }
		@AuraEnabled
		public Id invitationId { get; set; }
		@AuraEnabled
		public String token { get; set; }
		@AuraEnabled
		public String surveyUrl { get; set; }
	}

	/**
	 * @description Wrapper class for bulk invitation generation
	 */
	public class BulkInvitationResult {
		@AuraEnabled
		public Boolean success { get; set; }
		@AuraEnabled
		public String message { get; set; }
		@AuraEnabled
		public List<InvitationData> invitations { get; set; }
		@AuraEnabled
		public Integer totalGenerated { get; set; }
	}

	/**
	 * @description Individual invitation data for display
	 */
	public class InvitationData {
		@AuraEnabled
		public Id id { get; set; }
		@AuraEnabled
		public String name { get; set; }
		@AuraEnabled
		public String token { get; set; }
		@AuraEnabled
		public String email { get; set; }
		@AuraEnabled
		public String participantName { get; set; }
		@AuraEnabled
		public String status { get; set; }
		@AuraEnabled
		public String surveyUrl { get; set; }
		@AuraEnabled
		public Datetime createdDate { get; set; }
		@AuraEnabled
		public Datetime completedDate { get; set; }
		@AuraEnabled
		public Datetime expirationDate { get; set; }
		@AuraEnabled
		public Datetime eventDate { get; set; }
		@AuraEnabled
		public String relatedRecordId { get; set; }
		@AuraEnabled
		public String eventTopic { get; set; }
	}

	/**
	 * @description Wrapper for invitation validation result
	 */
	public class ValidationResult {
		@AuraEnabled
		public Boolean isValid { get; set; }
		@AuraEnabled
		public String message { get; set; }
		@AuraEnabled
		public Id surveyId { get; set; }
		@AuraEnabled
		public Id invitationId { get; set; }
		@AuraEnabled
		public String status { get; set; }
		@AuraEnabled
		public DateTime eventDate { get; set; }
		@AuraEnabled
		public String eventTopic { get; set; }
	}

	/**
	 * @description Generate a unique token for survey invitation
	 * @return String UUID-style token
	 */
	private static String generateToken() {
		return TokenGeneratorService.generateToken();
	}

	/**
	 * @description Get expiration date based on custom setting
	 * @param eventDate Optional event date from which to calculate expiration. If null, uses current date.
	 * @return DateTime Calculated expiration date, or null if expiration is disabled
	 */
	private static DateTime getExpirationDate(DateTime eventDate) {
		SurveySettings__c settings = SurveySettings__c.getInstance();
		Decimal expirationDays = settings != null && settings.InvitationExpirationDays__c != null ? settings.InvitationExpirationDays__c : SurveyForceConstants.DEFAULT_EXPIRATION_DAYS;

		// If expiration days is 0, return null (no expiration)
		if (expirationDays == 0) {
			return null;
		}

		// Use event date if provided, otherwise use current date
		DateTime baseDate = eventDate != null ? eventDate : DateTime.now();
		return baseDate.addDays(Integer.valueOf(expirationDays));
	}

	/**
	 * @description Create a single survey invitation
	 * @param surveyId The ID of the survey
	 * @param email Optional email of the participant
	 * @param participantName Optional name of the participant
	 * @param contactId Optional contact ID to associate
	 * @param eventDate Optional event date for expiration calculation
	 * @param relatedRecordId Optional related record ID (e.g., Training Event ID)
	 * @param eventTopic Optional event topic/name for dynamic survey header
	 * @return InvitationResult with the generated invitation details
	 */
	@AuraEnabled
	public static InvitationResult createInvitation(Id surveyId, String email, String participantName, Id contactId, DateTime eventDate, String relatedRecordId, String eventTopic) {
		InvitationResult result = new InvitationResult();
		result.success = false;

		try {
			if (surveyId == null) {
				result.message = 'Survey ID is required';
				return result;
			}

			// Verify survey exists
			List<Survey__c> surveys = [SELECT Id, Name FROM Survey__c WHERE Id = :surveyId WITH USER_MODE LIMIT 1];
			if (surveys.isEmpty()) {
				result.message = 'Survey not found';
				return result;
			}

			// Check create permissions
			List<Schema.SObjectField> fields = new List<Schema.SObjectField>{
				Schema.SurveyInvitation__c.fields.Survey__c,
				Schema.SurveyInvitation__c.fields.Token__c,
				Schema.SurveyInvitation__c.fields.Status__c,
				Schema.SurveyInvitation__c.fields.Email__c,
				Schema.SurveyInvitation__c.fields.ParticipantName__c,
				Schema.SurveyInvitation__c.fields.Contact__c,
				Schema.SurveyInvitation__c.fields.ExpirationDate__c,
				Schema.SurveyInvitation__c.fields.EventDate__c,
				Schema.SurveyInvitation__c.fields.RelatedRecordId__c,
				Schema.SurveyInvitation__c.fields.EventTopic__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToCreate(Schema.SurveyInvitation__c.getSObjectType(), fields);

			// Create invitation
			String token = generateToken();
			DateTime expirationDate = getExpirationDate(eventDate);

			SurveyInvitation__c invitation = new SurveyInvitation__c();
			invitation.Survey__c = surveyId;
			invitation.Token__c = token;
			invitation.Status__c = STATUS_PENDING;
			invitation.Email__c = email;
			invitation.ParticipantName__c = participantName;
			invitation.Contact__c = contactId;
			invitation.ExpirationDate__c = expirationDate;
			invitation.EventDate__c = eventDate;
			invitation.RelatedRecordId__c = relatedRecordId;
			invitation.EventTopic__c = eventTopic;

			insert invitation;

			result.success = true;
			result.message = 'Invitation created successfully';
			result.invitationId = invitation.Id;
			result.token = token;
			result.surveyUrl = buildSurveyUrl(token);

			return result;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyInvitationController:createInvitation():' + e.getMessage());
			result.message = 'Error creating invitation: ' + e.getMessage();
			return result;
		}
	}

	/**
	 * @description Create multiple survey invitations in bulk
	 * @param surveyId The ID of the survey
	 * @param count Number of invitations to generate
	 * @param eventDate Optional event date for expiration calculation
	 * @param relatedRecordId Optional related record ID (e.g., Training Event ID)
	 * @param eventTopic Optional event topic/name for dynamic survey header
	 * @return BulkInvitationResult with all generated invitations
	 */
	@AuraEnabled
	public static BulkInvitationResult createBulkInvitations(Id surveyId, Integer count, DateTime eventDate, String relatedRecordId, String eventTopic) {
		BulkInvitationResult result = new BulkInvitationResult();
		result.success = false;
		result.invitations = new List<InvitationData>();

		try {
			if (surveyId == null) {
				result.message = 'Survey ID is required';
				return result;
			}

			if (count == null || count < 1) {
				result.message = 'Count must be at least 1';
				return result;
			}

			if (count > SurveyForceConstants.MAX_BULK_INVITATIONS) {
				result.message = 'Cannot generate more than ' + SurveyForceConstants.MAX_BULK_INVITATIONS + ' invitations at once';
				return result;
			}

			// Verify survey exists
			List<Survey__c> surveys = [SELECT Id, Name FROM Survey__c WHERE Id = :surveyId WITH USER_MODE LIMIT 1];
			if (surveys.isEmpty()) {
				result.message = 'Survey not found';
				return result;
			}

			// Check create permissions
			List<Schema.SObjectField> fields = new List<Schema.SObjectField>{
				Schema.SurveyInvitation__c.fields.Survey__c,
				Schema.SurveyInvitation__c.fields.Token__c,
				Schema.SurveyInvitation__c.fields.Status__c,
				Schema.SurveyInvitation__c.fields.ExpirationDate__c,
				Schema.SurveyInvitation__c.fields.EventDate__c,
				Schema.SurveyInvitation__c.fields.RelatedRecordId__c,
				Schema.SurveyInvitation__c.fields.EventTopic__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToCreate(Schema.SurveyInvitation__c.getSObjectType(), fields);

			// Get expiration date once for all invitations
			DateTime expirationDate = getExpirationDate(eventDate);

			// Create invitations
			List<SurveyInvitation__c> invitations = new List<SurveyInvitation__c>();
			for (Integer i = 0; i < count; i++) {
				SurveyInvitation__c invitation = new SurveyInvitation__c();
				invitation.Survey__c = surveyId;
				invitation.Token__c = generateToken();
				invitation.Status__c = STATUS_PENDING;
				invitation.ExpirationDate__c = expirationDate;
				invitation.EventDate__c = eventDate;
				invitation.RelatedRecordId__c = relatedRecordId;
				invitation.EventTopic__c = eventTopic;
				invitations.add(invitation);
			}

			insert invitations;

			// Build result data
			for (SurveyInvitation__c inv : invitations) {
				InvitationData data = new InvitationData();
				data.id = inv.Id;
				data.token = inv.Token__c;
				data.status = inv.Status__c;
				data.surveyUrl = buildSurveyUrl(inv.Token__c);
				result.invitations.add(data);
			}

			result.success = true;
			result.message = 'Generated ' + count + ' invitations successfully';
			result.totalGenerated = count;

			return result;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyInvitationController:createBulkInvitations():' + e.getMessage());
			result.message = 'Error creating invitations: ' + e.getMessage();
			return result;
		}
	}

	/**
	 * @description Validate an invitation token and return survey info if valid
	 * @param token The invitation token to validate
	 * @return ValidationResult with validation status and survey ID
	 */
	@AuraEnabled
	public static ValidationResult validateInvitation(String token) {
		ValidationResult result = new ValidationResult();
		result.isValid = false;

		try {
			if (String.isBlank(token)) {
				result.message = 'Invalid invitation link';
				return result;
			}

			// Query invitation - without sharing to allow guest users
			SurveyInvitation__c invitation = getInvitationByToken(token);

			if (invitation == null) {
				result.message = 'Invalid invitation link';
				return result;
			}

			result.invitationId = invitation.Id;
			result.status = invitation.Status__c;
			result.eventDate = invitation.EventDate__c;
			result.eventTopic = invitation.EventTopic__c;

			// Get survey messages for customizable responses
			Survey__c survey = ViewSurveyControllerWithoutSharing.getSurveyMessagesForGuestUser(invitation.Survey__c);

			// Define default messages
			String defaultAlreadySubmittedMessage = 'This survey has already been completed';
			String defaultExpirationMessage = 'This survey has expired';

			// Use custom messages if survey is available, otherwise use defaults
			String alreadySubmittedMessage = defaultAlreadySubmittedMessage;
			String expirationMessage = defaultExpirationMessage;

			if (survey != null) {
				if (String.isNotBlank(survey.Already_Submitted_Message__c)) {
					alreadySubmittedMessage = survey.Already_Submitted_Message__c;
				}
				if (String.isNotBlank(survey.Survey_Expiration_Message__c)) {
					expirationMessage = survey.Survey_Expiration_Message__c;
				}
			}

			if (invitation.Status__c == STATUS_COMPLETED) {
				result.message = alreadySubmittedMessage;
				return result;
			}

			// Check if invitation has expired
			if (invitation.ExpirationDate__c != null && invitation.ExpirationDate__c < DateTime.now()) {
				// Auto-update status to Expired if it's still Pending
				if (invitation.Status__c == STATUS_PENDING) {
					updateInvitationStatus(invitation.Id, STATUS_EXPIRED, null);
					result.status = STATUS_EXPIRED;
				}
				result.message = expirationMessage;
				return result;
			}

			if (invitation.Status__c == STATUS_EXPIRED) {
				result.message = expirationMessage;
				return result;
			}

			result.isValid = true;
			result.surveyId = invitation.Survey__c;
			result.message = 'Valid invitation';

			return result;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyInvitationController:validateInvitation():' + e.getMessage());
			result.message = 'Error validating invitation';
			return result;
		}
	}

	/**
	 * @description Mark an invitation as completed after survey submission
	 * @param token The invitation token
	 * @param surveyTakerId The ID of the created SurveyTaker record
	 * @return Boolean indicating success
	 */
	@AuraEnabled
	public static Boolean completeInvitation(String token, Id surveyTakerId) {
		try {
			if (String.isBlank(token)) {
				return false;
			}

			SurveyInvitation__c invitation = getInvitationByToken(token);

			if (invitation == null || invitation.Status__c != STATUS_PENDING) {
				return false;
			}

			// Update invitation status
			updateInvitationStatus(invitation.Id, STATUS_COMPLETED, surveyTakerId);

			return true;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyInvitationController:completeInvitation():' + e.getMessage());
			return false;
		}
	}

	/**
	 * @description Get all invitations for a survey
	 * @param surveyId The survey ID
	 * @return List of InvitationData for the survey
	 */
	@AuraEnabled(cacheable=true)
	public static List<InvitationData> getInvitationsForSurvey(Id surveyId) {
		List<InvitationData> results = new List<InvitationData>();

		try {
			if (surveyId == null) {
				return results;
			}

			List<Schema.SObjectField> fields = new List<Schema.SObjectField>{
				Schema.SurveyInvitation__c.fields.Name,
				Schema.SurveyInvitation__c.fields.Token__c,
				Schema.SurveyInvitation__c.fields.Status__c,
				Schema.SurveyInvitation__c.fields.Email__c,
				Schema.SurveyInvitation__c.fields.ParticipantName__c,
				Schema.SurveyInvitation__c.fields.CompletedDate__c,
				Schema.SurveyInvitation__c.fields.ExpirationDate__c,
				Schema.SurveyInvitation__c.fields.EventDate__c,
				Schema.SurveyInvitation__c.fields.RelatedRecordId__c,
				Schema.SurveyInvitation__c.fields.EventTopic__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToView(Schema.SurveyInvitation__c.getSObjectType(), fields);

			List<SurveyInvitation__c> invitations = [
				SELECT Id, Name, Token__c, Status__c, Email__c, ParticipantName__c, CreatedDate, CompletedDate__c, ExpirationDate__c, EventDate__c, RelatedRecordId__c, EventTopic__c
				FROM SurveyInvitation__c
				WHERE Survey__c = :surveyId
				WITH USER_MODE
				ORDER BY CreatedDate DESC
				LIMIT 1000
			];

			for (SurveyInvitation__c inv : invitations) {
				InvitationData data = new InvitationData();
				data.id = inv.Id;
				data.name = inv.Name;
				data.token = inv.Token__c;
				data.email = inv.Email__c;
				data.participantName = inv.ParticipantName__c;
				data.status = inv.Status__c;
				data.surveyUrl = buildSurveyUrl(inv.Token__c);
				data.createdDate = inv.CreatedDate;
				data.completedDate = inv.CompletedDate__c;
				data.expirationDate = inv.ExpirationDate__c;
				data.eventDate = inv.EventDate__c;
				data.relatedRecordId = inv.RelatedRecordId__c;
				data.eventTopic = inv.EventTopic__c;
				results.add(data);
			}

			return results;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyInvitationController:getInvitationsForSurvey():' + e.getMessage());
			return results;
		}
	}

	/**
	 * @description Build the survey URL with the invitation token
	 * @param token The invitation token
	 * @return String The complete survey URL
	 */
	private static String buildSurveyUrl(String token) {
		// Get the base URL - use Site URL if available, otherwise use instance URL
		String baseUrl = '';
		if (Site.getBaseUrl() != null && String.isNotBlank(Site.getBaseUrl())) {
			baseUrl = Site.getBaseUrl();
		} else {
			baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
		}
		// Survey page path - can be customized via custom label or custom metadata in future
		String surveyPagePath = SurveyForceConstants.SURVEY_PAGE_PATH;
		return baseUrl + surveyPagePath + '?token=' + token;
	}

	/**
	 * @description Query invitation by token without sharing for guest user access
	 * @param token The invitation token
	 * @return SurveyInvitation__c The invitation record or null
	 */
	private static SurveyInvitation__c getInvitationByToken(String token) {
		return ViewSurveyControllerWithoutSharing.getInvitationByToken(token);
	}

	/**
	 * @description Update invitation status without sharing
	 * @param invitationId The invitation ID
	 * @param status The new status
	 * @param surveyTakerId The survey taker ID if completed
	 */
	private static void updateInvitationStatus(Id invitationId, String status, Id surveyTakerId) {
		ViewSurveyControllerWithoutSharing.updateInvitationStatus(invitationId, status, surveyTakerId);
	}
}