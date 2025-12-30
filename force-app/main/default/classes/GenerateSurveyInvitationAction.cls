/**
 * @description Invocable action to generate unique survey invitation URLs with tokens.
 * Can be called from Flows to generate on-demand invitation links for Customer and Trainer surveys.
 */
public with sharing class GenerateSurveyInvitationAction {
	
	/**
	 * @description Request wrapper for generating survey invitations
	 */
	public class InvitationRequest {
		@InvocableVariable(label='Survey ID' description='The ID of the Survey record' required=true)
		public Id surveyId;
		
		@InvocableVariable(label='Training Request ID' description='The ID of the related Training Request' required=false)
		public Id trainingRequestId;
		
		@InvocableVariable(label='Survey Type' description='Type of survey (Customer, Trainer, etc.)' required=false)
		public String surveyType;
		
		@InvocableVariable(label='Recipient Email' description='Email address of the recipient' required=false)
		public String recipientEmail;
		
		@InvocableVariable(label='Recipient Name' description='Name of the recipient' required=false)
		public String recipientName;
	}
	
	/**
	 * @description Result wrapper for generated survey invitations
	 */
	public class InvitationResult {
		@InvocableVariable(label='Success' description='Whether the invitation was generated successfully')
		public Boolean success;
		
		@InvocableVariable(label='Survey URL' description='The unique survey URL with token')
		public String surveyUrl;
		
		@InvocableVariable(label='Token' description='The unique token generated')
		public String token;
		
		@InvocableVariable(label='Error Message' description='Error message if generation failed')
		public String errorMessage;
		
		@InvocableVariable(label='Invitation ID' description='The ID of the created SurveyInvitation record')
		public Id invitationId;
	}
	
	/**
	 * @description Generate unique survey invitation URLs with tokens
	 * Can be called from Flows to create on-demand invitations for surveys
	 * @param requests List of invitation generation requests
	 * @return List<InvitationResult> Results with generated URLs and tokens
	 */
	@InvocableMethod(
		label='Generate Survey Invitation' 
		description='Generates a unique survey invitation URL with a token for secure one-time access'
		category='Survey Force'
	)
	public static List<InvitationResult> generateInvitations(List<InvitationRequest> requests) {
		List<InvitationResult> results = new List<InvitationResult>();
		
		if (requests == null || requests.isEmpty()) {
			return results;
		}
		
		// Collect all survey IDs and training request IDs for bulk queries
		Set<Id> surveyIds = new Set<Id>();
		Set<Id> trainingRequestIds = new Set<Id>();
		
		for (InvitationRequest req : requests) {
			if (req.surveyId != null) {
				surveyIds.add(req.surveyId);
			}
			if (req.trainingRequestId != null) {
				trainingRequestIds.add(req.trainingRequestId);
			}
		}
		
		// Verify surveys exist
		Map<Id, Survey__c> surveyMap = new Map<Id, Survey__c>([
			SELECT Id, Name
			FROM Survey__c
			WHERE Id IN :surveyIds
			WITH USER_MODE
		]);
		
		// Get training request info for training type
		Map<Id, Training_Request__c> trainingRequestMap = new Map<Id, Training_Request__c>();
		if (!trainingRequestIds.isEmpty()) {
			trainingRequestMap = new Map<Id, Training_Request__c>([
				SELECT Id, Training_Type__c
				FROM Training_Request__c
				WHERE Id IN :trainingRequestIds
				WITH USER_MODE
			]);
		}
		
		// Process each request
		List<SurveyUtilities.InvitationRequest> bulkRequests = new List<SurveyUtilities.InvitationRequest>();
		Map<Integer, InvitationRequest> indexToRequestMap = new Map<Integer, InvitationRequest>();
		
		for (Integer i = 0; i < requests.size(); i++) {
			InvitationRequest req = requests[i];
			InvitationResult result = new InvitationResult();
			result.success = false;
			
			// Validate request
			if (req.surveyId == null) {
				result.errorMessage = 'Survey ID is required';
				results.add(result);
				continue;
			}
			
			if (!surveyMap.containsKey(req.surveyId)) {
				result.errorMessage = 'Survey not found';
				results.add(result);
				continue;
			}
			
			// Get training type if available
			String trainingType = null;
			if (req.trainingRequestId != null && trainingRequestMap.containsKey(req.trainingRequestId)) {
				trainingType = trainingRequestMap.get(req.trainingRequestId).Training_Type__c;
			}
			
			// Create bulk invitation request
			String surveyType = String.isNotBlank(req.surveyType) ? req.surveyType : 'Survey';
			bulkRequests.add(new SurveyUtilities.InvitationRequest(
				req.surveyId,
				req.trainingRequestId,
				surveyType,
				trainingType
			));
			indexToRequestMap.put(i, req);
			results.add(result);
		}
		
		// Generate invitations in bulk
		if (!bulkRequests.isEmpty()) {
			try {
				Map<String, String> generatedUrls = SurveyUtilities.generateSurveyInvitationsInBulk(bulkRequests);
				
				// Query created invitations to get IDs and tokens
				List<SurveyInvitation__c> createdInvitations = [
					SELECT Id, Token__c, Survey__c, RelatedRecordId__c
					FROM SurveyInvitation__c
					WHERE Survey__c IN :surveyIds
					ORDER BY CreatedDate DESC
					LIMIT :bulkRequests.size()
				];
				
				// Map invitations to requests
				Map<String, SurveyInvitation__c> keyToInvitationMap = new Map<String, SurveyInvitation__c>();
				for (SurveyInvitation__c inv : createdInvitations) {
					String key = String.valueOf(inv.RelatedRecordId__c);
					if (!keyToInvitationMap.containsKey(key)) {
						keyToInvitationMap.put(key, inv);
					}
				}
				
				// Update results with generated URLs
				for (Integer i = 0; i < bulkRequests.size(); i++) {
					SurveyUtilities.InvitationRequest bulkReq = bulkRequests[i];
					String key = bulkReq.relatedRecordId + '_' + bulkReq.surveyType;
					InvitationResult result = results[i];
					
					if (generatedUrls.containsKey(key)) {
						result.success = true;
						result.surveyUrl = generatedUrls.get(key);
						
						// Find the invitation to get token and ID
						String invKey = String.valueOf(bulkReq.relatedRecordId);
						if (keyToInvitationMap.containsKey(invKey)) {
							SurveyInvitation__c inv = keyToInvitationMap.get(invKey);
							result.token = inv.Token__c;
							result.invitationId = inv.Id;
						}
					} else {
						result.errorMessage = 'Failed to generate invitation URL';
					}
				}
			} catch (Exception e) {
				// Update all pending results with error
				for (InvitationResult result : results) {
					if (!result.success) {
						result.errorMessage = 'Error: ' + e.getMessage();
					}
				}
			}
		}
		
		return results;
	}
}
