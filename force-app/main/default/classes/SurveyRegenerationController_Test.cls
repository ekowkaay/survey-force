/**
 * @description Test class for SurveyRegenerationController
 * Tests bulk regeneration of survey links and invitations
 */
@isTest
private class SurveyRegenerationController_Test {
	/**
	 * @description Setup test data
	 */
	@TestSetup
	static void setupTestData() {
		// Create survey templates
		Survey__c participantTemplate = new Survey__c();
		participantTemplate.Name = SurveyForceConstants.TEMPLATE_PARTICIPANT_ENGLISH;
		participantTemplate.Survey_Header__c = 'Participant Survey';
		insert participantTemplate;

		Survey__c customerTemplate = new Survey__c();
		customerTemplate.Name = SurveyForceConstants.TEMPLATE_CUSTOMER;
		customerTemplate.Survey_Header__c = 'Customer Survey';
		insert customerTemplate;

		Survey__c trainerTemplate = new Survey__c();
		trainerTemplate.Name = SurveyForceConstants.TEMPLATE_TRAINER;
		trainerTemplate.Survey_Header__c = 'Trainer Survey';
		insert trainerTemplate;

		// Create survey questions for templates
		List<Survey_Question__c> questions = new List<Survey_Question__c>();

		Survey_Question__c q1 = new Survey_Question__c();
		q1.Survey__c = participantTemplate.Id;
		q1.Question__c = 'How was the training?';
		q1.Type__c = 'Free Text';
		q1.OrderNumber__c = 1;
		questions.add(q1);

		Survey_Question__c q2 = new Survey_Question__c();
		q2.Survey__c = customerTemplate.Id;
		q2.Question__c = 'Rate our service';
		q2.Type__c = 'Single Select';
		q2.Choices__c = 'Excellent\nGood\nFair\nPoor';
		q2.OrderNumber__c = 1;
		questions.add(q2);

		Survey_Question__c q3 = new Survey_Question__c();
		q3.Survey__c = trainerTemplate.Id;
		q3.Question__c = 'Trainer feedback';
		q3.Type__c = 'Free Text';
		q3.OrderNumber__c = 1;
		questions.add(q3);

		insert questions;

		// Create Training Requests with surveys already created
		List<Training_Request__c> trainingRequests = new List<Training_Request__c>();
		for (Integer i = 0; i < 5; i++) {
			Training_Request__c tr = new Training_Request__c();
			tr.Name = 'Test Training ' + i;
			tr.Training_Type__c = SurveyForceConstants.TRAINING_TYPE_EAP;
			trainingRequests.add(tr);
		}
		insert trainingRequests;

		// Create surveys for each training request
		List<Survey__c> surveys = new List<Survey__c>();
		List<SurveyInvitation__c> invitations = new List<SurveyInvitation__c>();
		List<Participants__c> allParticipants = new List<Participants__c>();

		for (Training_Request__c tr : trainingRequests) {
			// Create participant survey
			Survey__c participantSurvey = new Survey__c();
			participantSurvey.Name = tr.Name + ' - Participant Survey';
			participantSurvey.Survey_Header__c = 'Participant Survey';
			surveys.add(participantSurvey);

			// Create customer survey
			Survey__c customerSurvey = new Survey__c();
			customerSurvey.Name = tr.Name + ' - Customer Survey';
			customerSurvey.Survey_Header__c = 'Customer Survey';
			surveys.add(customerSurvey);

			// Create trainer survey
			Survey__c trainerSurvey = new Survey__c();
			trainerSurvey.Name = tr.Name + ' - Trainer Survey';
			trainerSurvey.Survey_Header__c = 'Trainer Survey';
			surveys.add(trainerSurvey);
		}
		insert surveys;

		// Update training requests with survey URLs and create invitations
		List<Training_Request__c> requestsToUpdate = new List<Training_Request__c>();
		Integer surveyIndex = 0;
		for (Training_Request__c tr : trainingRequests) {
			Training_Request__c trToUpdate = new Training_Request__c();
			trToUpdate.Id = tr.Id;

			Survey__c participantSurvey = surveys[surveyIndex];
			Survey__c customerSurvey = surveys[surveyIndex + 1];
			Survey__c trainerSurvey = surveys[surveyIndex + 2];
			surveyIndex += 3;

			trToUpdate.Participant_Survey__c = '/TakeSurvey?id=' + participantSurvey.Id;
			trToUpdate.Customer_Survey__c = '/TakeSurvey?id=' + customerSurvey.Id;
			trToUpdate.Trainer_Survey__c = '/TakeSurvey?id=' + trainerSurvey.Id;
			requestsToUpdate.add(trToUpdate);

			// Create old customer invitation
			SurveyInvitation__c customerInv = new SurveyInvitation__c();
			customerInv.Survey__c = customerSurvey.Id;
			customerInv.Token__c = 'old-customer-token-' + tr.Id;
			customerInv.Status__c = SurveyForceConstants.STATUS_PENDING;
			customerInv.RelatedRecordId__c = tr.Id;
			invitations.add(customerInv);

			// Create old trainer invitation
			SurveyInvitation__c trainerInv = new SurveyInvitation__c();
			trainerInv.Survey__c = trainerSurvey.Id;
			trainerInv.Token__c = 'old-trainer-token-' + tr.Id;
			trainerInv.Status__c = SurveyForceConstants.STATUS_PENDING;
			trainerInv.RelatedRecordId__c = tr.Id;
			invitations.add(trainerInv);

			// Create participants for this training request
			for (Integer j = 0; j < 3; j++) {
				Participants__c p = new Participants__c();
				p.Training_Request__c = tr.Id;
				p.Participant_Name__c = 'Participant ' + j + ' for ' + tr.Name;
				p.Email__c = 'participant' + j + '@test.com';
				p.Participant_Survey__c = '/survey?token=old-participant-token-' + tr.Id + '-' + j;
				allParticipants.add(p);

				// Create old participant invitation
				SurveyInvitation__c participantInv = new SurveyInvitation__c();
				participantInv.Survey__c = participantSurvey.Id;
				participantInv.Token__c = 'old-participant-token-' + tr.Id + '-' + j;
				participantInv.Status__c = SurveyForceConstants.STATUS_PENDING;
				participantInv.RelatedRecordId__c = tr.Id;
				invitations.add(participantInv);
			}
		}

		update requestsToUpdate;
		insert invitations;
		insert allParticipants;
	}

	/**
	 * @description Test regenerating surveys for a single training request
	 */
	@isTest
	static void testRegenerateSingleTrainingRequest() {
		// Get a training request
		Training_Request__c tr = [SELECT Id, Name FROM Training_Request__c LIMIT 1];

		// Count old invitations
		Integer oldInvitationCount = [SELECT COUNT() FROM SurveyInvitation__c WHERE RelatedRecordId__c = :tr.Id];
		System.assert(oldInvitationCount > 0, 'Should have old invitations');

		// Create regeneration request
		SurveyRegenerationController.RegenerationRequest request = new SurveyRegenerationController.RegenerationRequest();
		request.trainingRequestIds = new List<Id>{ tr.Id };
		request.regenerateParticipant = true;
		request.regenerateCustomer = true;
		request.regenerateTrainer = true;

		Test.startTest();
		List<SurveyRegenerationController.RegenerationResult> results = SurveyRegenerationController.regenerateSurveyLinks(new List<SurveyRegenerationController.RegenerationRequest>{ request });
		Test.stopTest();

		// Verify results
		System.assertEquals(1, results.size(), 'Should have one result');
		SurveyRegenerationController.RegenerationResult result = results[0];
		System.assert(result.success, 'Should succeed: ' + result.message);
		System.assertEquals(1, result.totalProcessed, 'Should process 1 training request');
		System.assertEquals(1, result.totalSuccess, 'Should have 1 success');
		System.assertEquals(0, result.totalFailed, 'Should have 0 failures');

		// Verify new invitations were created
		List<SurveyInvitation__c> newInvitations = [
			SELECT Id, Token__c, Survey__c, RelatedRecordId__c
			FROM SurveyInvitation__c
			WHERE RelatedRecordId__c = :tr.Id
		];

		System.assert(newInvitations.size() > 0, 'Should have new invitations');

		// Verify old tokens are gone
		for (SurveyInvitation__c inv : newInvitations) {
			System.assert(!inv.Token__c.startsWith('old-'), 'Should have new token: ' + inv.Token__c);
		}

		// Verify participant survey URLs were updated
		List<Participants__c> participants = [SELECT Id, Participant_Survey__c FROM Participants__c WHERE Training_Request__c = :tr.Id];

		for (Participants__c p : participants) {
			System.assert(String.isNotBlank(p.Participant_Survey__c), 'Participant should have survey URL');
			System.assert(!p.Participant_Survey__c.contains('old-'), 'Should have new survey URL');
		}

		Training_Request__c updatedRequest = [
			SELECT Customer_Survey__c, Trainer_Survey__c
			FROM Training_Request__c
			WHERE Id = :tr.Id
		];
		System.assert(updatedRequest.Customer_Survey__c.contains('id='), 'Customer survey URL should include survey id');
		System.assert(updatedRequest.Trainer_Survey__c.contains('id='), 'Trainer survey URL should include survey id');
	}

	/**
	 * @description Test regenerating surveys for multiple training requests (bulk)
	 */
	@isTest
	static void testRegenerateBulkTrainingRequests() {
		// Get multiple training requests
		List<Training_Request__c> trainingRequests = [SELECT Id FROM Training_Request__c LIMIT 5];
		List<Id> trainingRequestIds = new List<Id>();
		for (Training_Request__c tr : trainingRequests) {
			trainingRequestIds.add(tr.Id);
		}

		// Create regeneration request
		SurveyRegenerationController.RegenerationRequest request = new SurveyRegenerationController.RegenerationRequest();
		request.trainingRequestIds = trainingRequestIds;
		request.regenerateParticipant = true;
		request.regenerateCustomer = true;
		request.regenerateTrainer = true;

		Test.startTest();
		List<SurveyRegenerationController.RegenerationResult> results = SurveyRegenerationController.regenerateSurveyLinks(new List<SurveyRegenerationController.RegenerationRequest>{ request });
		Test.stopTest();

		// Verify results
		System.assertEquals(1, results.size(), 'Should have one result');
		SurveyRegenerationController.RegenerationResult result = results[0];
		System.assert(result.success, 'Should succeed: ' + result.message);
		System.assertEquals(5, result.totalProcessed, 'Should process 5 training requests');
		System.assertEquals(5, result.totalSuccess, 'Should have 5 successes');
		System.assertEquals(0, result.totalFailed, 'Should have 0 failures');

		// Verify invitations were created for all training requests
		for (Id trId : trainingRequestIds) {
			List<SurveyInvitation__c> invitations = [SELECT Id, Token__c FROM SurveyInvitation__c WHERE RelatedRecordId__c = :trId];

			System.assert(invitations.size() > 0, 'Should have invitations for training request ' + trId);

			for (SurveyInvitation__c inv : invitations) {
				System.assert(!inv.Token__c.startsWith('old-'), 'Should have new token');
			}
		}
	}

	/**
	 * @description Test regenerating only specific survey types
	 */
	@isTest
	static void testRegenerateSpecificSurveyTypes() {
		// Get a training request
		Training_Request__c tr = [SELECT Id FROM Training_Request__c LIMIT 1];

		// Create regeneration request - only customer surveys
		SurveyRegenerationController.RegenerationRequest request = new SurveyRegenerationController.RegenerationRequest();
		request.trainingRequestIds = new List<Id>{ tr.Id };
		request.regenerateParticipant = false;
		request.regenerateCustomer = true;
		request.regenerateTrainer = false;

		Test.startTest();
		List<SurveyRegenerationController.RegenerationResult> results = SurveyRegenerationController.regenerateSurveyLinks(new List<SurveyRegenerationController.RegenerationRequest>{ request });
		Test.stopTest();

		// Verify results
		SurveyRegenerationController.RegenerationResult result = results[0];
		System.assert(result.success, 'Should succeed: ' + result.message);
		System.assertEquals(1, result.customerLinksGenerated, 'Should generate 1 customer link');
		System.assertEquals(0, result.participantLinksGenerated, 'Should not generate participant links');
		System.assertEquals(0, result.trainerLinksGenerated, 'Should not generate trainer links');
	}

	/**
	 * @description Test with no training request IDs
	 */
	@isTest
	static void testNoTrainingRequestIds() {
		// Create empty request
		SurveyRegenerationController.RegenerationRequest request = new SurveyRegenerationController.RegenerationRequest();
		request.trainingRequestIds = new List<Id>();

		Test.startTest();
		List<SurveyRegenerationController.RegenerationResult> results = SurveyRegenerationController.regenerateSurveyLinks(new List<SurveyRegenerationController.RegenerationRequest>{ request });
		Test.stopTest();

		// Verify results
		System.assertEquals(1, results.size(), 'Should have one result');
		SurveyRegenerationController.RegenerationResult result = results[0];
		System.assertEquals(false, result.success, 'Should fail');
		System.assert(result.message.contains('No Training Request IDs'), 'Should have appropriate error message');
	}

	/**
	 * @description Test with null request
	 */
	@isTest
	static void testNullRequest() {
		Test.startTest();
		List<SurveyRegenerationController.RegenerationResult> results = SurveyRegenerationController.regenerateSurveyLinks(null);
		Test.stopTest();

		// Verify results
		System.assertEquals(1, results.size(), 'Should have one result');
		SurveyRegenerationController.RegenerationResult result = results[0];
		System.assertEquals(false, result.success, 'Should fail');
		System.assert(result.message.contains('No requests'), 'Should have appropriate error message');
	}

	/**
	 * @description Test with invalid training request ID
	 */
	@isTest
	static void testInvalidTrainingRequestId() {
		// Create a fake ID using string manipulation
		// Training_Request__c has a key prefix, so we construct an ID that won't exist
		String fakeIdStr = String.valueOf(Training_Request__c.SObjectType.getDescribe().getKeyPrefix()) + '0'.repeat(15);
		Id fakeId = (Id) fakeIdStr;

		SurveyRegenerationController.RegenerationRequest request = new SurveyRegenerationController.RegenerationRequest();
		request.trainingRequestIds = new List<Id>{ fakeId };

		Test.startTest();
		List<SurveyRegenerationController.RegenerationResult> results = SurveyRegenerationController.regenerateSurveyLinks(new List<SurveyRegenerationController.RegenerationRequest>{ request });
		Test.stopTest();

		// Verify results
		System.assertEquals(1, results.size(), 'Should have one result');
		SurveyRegenerationController.RegenerationResult result = results[0];
		System.assertEquals(false, result.success, 'Should fail');
		System.assert(result.message.contains('No Training Requests found'), 'Should indicate no training requests found');
	}

	/**
	 * @description Test regenerating when training request has no participants
	 */
	@isTest
	static void testRegenerateWithNoParticipants() {
		// Create a new training request with surveys but no participants
		Training_Request__c tr = new Training_Request__c();
		tr.Name = 'Test Training No Participants';
		tr.Training_Type__c = SurveyForceConstants.TRAINING_TYPE_EAP;
		insert tr;

		// Create surveys
		Survey__c participantSurvey = new Survey__c();
		participantSurvey.Name = tr.Name + ' - Participant Survey';
		insert participantSurvey;

		Survey__c customerSurvey = new Survey__c();
		customerSurvey.Name = tr.Name + ' - Customer Survey';
		insert customerSurvey;

		// Update training request with survey URLs
		tr.Participant_Survey__c = '/TakeSurvey?id=' + participantSurvey.Id;
		tr.Customer_Survey__c = '/TakeSurvey?id=' + customerSurvey.Id;
		update tr;

		// Create regeneration request
		SurveyRegenerationController.RegenerationRequest request = new SurveyRegenerationController.RegenerationRequest();
		request.trainingRequestIds = new List<Id>{ tr.Id };

		Test.startTest();
		List<SurveyRegenerationController.RegenerationResult> results = SurveyRegenerationController.regenerateSurveyLinks(new List<SurveyRegenerationController.RegenerationRequest>{ request });
		Test.stopTest();

		// Verify results - should succeed even with no participants
		SurveyRegenerationController.RegenerationResult result = results[0];
		System.assert(result.success, 'Should succeed even with no participants');
		System.assertEquals(0, result.participantLinksGenerated, 'Should generate 0 participant links');
		System.assertEquals(1, result.customerLinksGenerated, 'Should generate 1 customer link');
	}
}
