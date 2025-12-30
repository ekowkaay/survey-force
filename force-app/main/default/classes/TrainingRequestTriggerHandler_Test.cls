/**
 * @description Test class for TrainingRequestTriggerHandler
 */
@IsTest
private class TrainingRequestTriggerHandler_Test {
	/**
	 * @description Setup test data
	 */
	@TestSetup
	static void setupTestData() {
		// Custom Metadata Types (SiteURL__mdt) are deployed and automatically available in tests

		// Create survey settings
		SurveySettings__c settings = new SurveySettings__c();
		settings.SetupOwnerId = UserInfo.getOrganizationId();
		settings.InvitationExpirationDays__c = 30;
		insert settings;

		// Create survey templates
		List<Survey__c> templates = new List<Survey__c>();

		Survey__c participantTemplate = new Survey__c();
		participantTemplate.Name = 'PartcipantSurveyTemplate';
		participantTemplate.Thank_You_Text__c = 'Thank you for your participation!';
		templates.add(participantTemplate);

		Survey__c customerTemplate = new Survey__c();
		customerTemplate.Name = 'CustomerSurveyTemplate';
		customerTemplate.Thank_You_Text__c = 'Thank you for your feedback!';
		templates.add(customerTemplate);

		Survey__c trainerTemplate = new Survey__c();
		trainerTemplate.Name = 'TrainerSurveyTemplate';
		trainerTemplate.Thank_You_Text__c = 'Thank you for your input!';
		templates.add(trainerTemplate);

		insert templates;

		// Create questions for each template
		List<Survey_Question__c> questions = new List<Survey_Question__c>();

		for (Survey__c template : templates) {
			Survey_Question__c q1 = new Survey_Question__c();
			q1.Survey__c = template.Id;
			q1.Question__c = 'How would you rate the training?';
			q1.Type__c = 'Single Select--Vertical';
			q1.Choices__c = 'Excellent\nGood\nFair\nPoor';
			q1.OrderNumber__c = 1;
			q1.Required__c = true;
			questions.add(q1);

			Survey_Question__c q2 = new Survey_Question__c();
			q2.Survey__c = template.Id;
			q2.Question__c = 'Additional comments?';
			q2.Type__c = 'Free Text';
			q2.OrderNumber__c = 2;
			q2.Required__c = false;
			questions.add(q2);
		}

		insert questions;
	}

	/**
	 * @description Test automatic survey creation on training request insert
	 */
	@IsTest
	static void testAutoCreateSurveysOnInsert() {
		Test.startTest();

		// Create a new training request
		Training_Request__c tr = new Training_Request__c();
		tr.Training_Type__c = 'EAP Training';
		insert tr;

		Test.stopTest();

		// Query the training request with survey fields
		Training_Request__c insertedTr = [
			SELECT Id, Name, Participant_Survey__c, Customer_Survey__c, Trainer_Survey__c
			FROM Training_Request__c
			WHERE Id = :tr.Id
		];

		// Verify all three surveys were created
		System.assertNotEquals(
			null,
			insertedTr.Participant_Survey__c,
			'Participant survey should be created automatically'
		);
		System.assertNotEquals(null, insertedTr.Customer_Survey__c, 'Customer survey should be created automatically');
		System.assertNotEquals(null, insertedTr.Trainer_Survey__c, 'Trainer survey should be created automatically');

		// Verify survey URL formats:
		// - Participant: Token URL (for automatic participant token generation)
		// - Customer/Trainer: Survey ID URL (token created in background for initial use)
		System.assert(
			insertedTr.Participant_Survey__c.contains('/survey?token='),
			'Participant survey URL should contain token for automatic participant linking'
		);
		System.assert(
			insertedTr.Customer_Survey__c.contains('/TakeSurvey?id='),
			'Customer survey URL should contain survey ID'
		);
		System.assert(
			insertedTr.Trainer_Survey__c.contains('/TakeSurvey?id='),
			'Trainer survey URL should contain survey ID'
		);

		// Verify surveys have different URLs (different tokens)
		System.assertNotEquals(
			insertedTr.Participant_Survey__c,
			insertedTr.Customer_Survey__c,
			'Participant and Customer surveys should be different'
		);
		System.assertNotEquals(
			insertedTr.Participant_Survey__c,
			insertedTr.Trainer_Survey__c,
			'Participant and Trainer surveys should be different'
		);
		System.assertNotEquals(
			insertedTr.Customer_Survey__c,
			insertedTr.Trainer_Survey__c,
			'Customer and Trainer surveys should be different'
		);

		// Verify surveys were created with correct names
		List<Survey__c> createdSurveys = [
			SELECT Id, Name
			FROM Survey__c
			WHERE Name LIKE 'Test Training Request%'
			ORDER BY Name
		];
		System.assertEquals(3, createdSurveys.size(), 'Should create 3 surveys');

		// Verify each survey has questions cloned
		for (Survey__c survey : createdSurveys) {
			List<Survey_Question__c> surveyQuestions = [
				SELECT Id
				FROM Survey_Question__c
				WHERE Survey__c = :survey.Id
			];
			System.assertEquals(2, surveyQuestions.size(), 'Each survey should have 2 questions cloned');
		}

		// Verify SurveyInvitation records were created for all three survey types
		// Even though Customer/Trainer store Survey ID URLs, token invitations are created in background
		List<SurveyInvitation__c> invitations = [
			SELECT Id, Token__c, Survey__c, Status__c, ParticipantName__c
			FROM SurveyInvitation__c
			WHERE RelatedRecordId__c = :tr.Id
		];
		System.assertEquals(3, invitations.size(), 'Should create 3 survey invitations (Participant, Customer, Trainer)');

		// Verify all invitations are pending and have unique tokens
		Set<String> tokens = new Set<String>();
		for (SurveyInvitation__c inv : invitations) {
			System.assertEquals('Pending', inv.Status__c, 'Invitation should be pending');
			System.assertNotEquals(null, inv.Token__c, 'Token should not be null');
			tokens.add(inv.Token__c);
		}
		System.assertEquals(3, tokens.size(), 'All tokens should be unique');
	}

	/**
	 * @description Test bulk training request insert
	 */
	@IsTest
	static void testBulkTrainingRequestInsert() {
		Test.startTest();

		// Create multiple training requests
		List<Training_Request__c> trainingRequests = new List<Training_Request__c>();
		for (Integer i = 0; i < 10; i++) {
			Training_Request__c tr = new Training_Request__c();
			tr.Training_Type__c = 'EAP Training';
			trainingRequests.add(tr);
		}
		insert trainingRequests;

		Test.stopTest();

		// Query all training requests
		List<Training_Request__c> insertedTrs = [
			SELECT Id, Name, Participant_Survey__c, Customer_Survey__c, Trainer_Survey__c
			FROM Training_Request__c
			WHERE Name LIKE 'Bulk Training Request%'
		];

		System.assertEquals(10, insertedTrs.size(), 'Should have 10 training requests');

		// Verify all have surveys created
		Integer withParticipantSurvey = 0;
		Integer withCustomerSurvey = 0;
		Integer withTrainerSurvey = 0;

		for (Training_Request__c tr : insertedTrs) {
			if (String.isNotBlank(tr.Participant_Survey__c))
				withParticipantSurvey++;
			if (String.isNotBlank(tr.Customer_Survey__c))
				withCustomerSurvey++;
			if (String.isNotBlank(tr.Trainer_Survey__c))
				withTrainerSurvey++;
		}

		System.assertEquals(10, withParticipantSurvey, 'All requests should have participant survey');
		System.assertEquals(10, withCustomerSurvey, 'All requests should have customer survey');
		System.assertEquals(10, withTrainerSurvey, 'All requests should have trainer survey');

		// Verify 30 surveys were created (10 requests x 3 surveys each)
		List<Survey__c> createdSurveys = [
			SELECT Id, Name
			FROM Survey__c
			WHERE Name LIKE 'Bulk Training Request%'
		];
		System.assertEquals(30, createdSurveys.size(), 'Should create 30 surveys total');
	}

	/**
	 * @description Test that surveys are only created if fields are blank
	 */
	@IsTest
	static void testNoSurveyCreationIfAlreadyExists() {
		// Create a survey manually first
		Survey__c existingSurvey = new Survey__c();
		existingSurvey.Name = 'Existing Survey';
		existingSurvey.Thank_You_Text__c = 'Thank you!';
		insert existingSurvey;

		String existingUrl = 'https://example.com/TakeSurvey?id=' + existingSurvey.Id;

		Test.startTest();

		// Create training request with existing survey URL
		Training_Request__c tr = new Training_Request__c();
		tr.Training_Type__c = 'EAP Training';
		tr.Participant_Survey__c = existingUrl; // Already has participant survey
		insert tr;

		Test.stopTest();

		// Query the training request
		Training_Request__c insertedTr = [
			SELECT Id, Participant_Survey__c, Customer_Survey__c, Trainer_Survey__c
			FROM Training_Request__c
			WHERE Id = :tr.Id
		];

		// Verify participant survey was not overwritten
		System.assertEquals(existingUrl, insertedTr.Participant_Survey__c, 'Should not overwrite existing survey');

		// Verify customer and trainer surveys were created
		System.assertNotEquals(null, insertedTr.Customer_Survey__c, 'Customer survey should be created');
		System.assertNotEquals(null, insertedTr.Trainer_Survey__c, 'Trainer survey should be created');

		// Verify only 2 new surveys were created (not 3)
		List<Survey__c> newSurveys = [
			SELECT Id, Name
			FROM Survey__c
			WHERE Name LIKE 'Training with Existing Survey%'
		];
		System.assertEquals(2, newSurveys.size(), 'Should create only 2 surveys (Customer and Trainer)');
	}

	/**
	 * @description Test recursion prevention
	 */
	@IsTest
	static void testRecursionPrevention() {
		Test.startTest();

		// Create training request
		Training_Request__c tr = new Training_Request__c();
		tr.Training_Type__c = 'EAP Training';
		insert tr;

		// Update the training request multiple times
		tr.Training_Type__c = 'Reseller Training';
		update tr;

		tr.Training_Type__c = 'EAP Training';
		update tr;

		Test.stopTest();

		// Verify only 3 surveys were created (not duplicated on updates)
		List<Survey__c> createdSurveys = [
			SELECT Id, Name
			FROM Survey__c
			WHERE Name LIKE '%Recursion Test%' OR Name LIKE '%Updated Name%'
		];
		System.assertEquals(3, createdSurveys.size(), 'Should create only 3 surveys despite updates');
	}

	/**
	 * @description Test before insert handler
	 */
	@IsTest
	static void testBeforeInsert() {
		Test.startTest();

		Training_Request__c tr = new Training_Request__c();
		tr.Training_Type__c = 'EAP Training';
		insert tr;

		Test.stopTest();

		// Verify training request was inserted
		List<Training_Request__c> inserted = [
			SELECT Id
			FROM Training_Request__c
			WHERE Name = 'Before Insert Test'
		];
		System.assertEquals(1, inserted.size(), 'Training request should be inserted');
	}

	/**
	 * @description Test update handler
	 */
	@IsTest
	static void testAfterUpdate() {
		// Create training request
		Training_Request__c tr = new Training_Request__c();
		tr.Training_Type__c = 'EAP Training';
		insert tr;

		Test.startTest();

		// Update training request
		tr.Training_Type__c = 'Reseller Training';
		update tr;

		Test.stopTest();

		// Verify update was successful
		Training_Request__c updated = [
			SELECT Id, Name
			FROM Training_Request__c
			WHERE Id = :tr.Id
		];
		System.assertEquals('Updated Training Request', updated.Name, 'Name should be updated');
	}

	/**
	 * @description Test delete handler
	 */
	@IsTest
	static void testAfterDelete() {
		Training_Request__c tr = new Training_Request__c();
		tr.Training_Type__c = 'EAP Training';
		insert tr;

		Test.startTest();

		delete tr;

		Test.stopTest();

		// Verify deletion
		List<Training_Request__c> deleted = [
			SELECT Id
			FROM Training_Request__c
			WHERE Id = :tr.Id
		];
		System.assertEquals(0, deleted.size(), 'Training request should be deleted');
	}

	/**
	 * @description Test undelete handler
	 */
	@IsTest
	static void testAfterUndelete() {
		Training_Request__c tr = new Training_Request__c();
		tr.Training_Type__c = 'EAP Training';
		insert tr;

		delete tr;

		Test.startTest();

		undelete tr;

		Test.stopTest();

		// Verify undelete
		List<Training_Request__c> undeleted = [
			SELECT Id
			FROM Training_Request__c
			WHERE Id = :tr.Id
		];
		System.assertEquals(1, undeleted.size(), 'Training request should be undeleted');
	}

	/**
	 * @description Test survey name generation
	 */
	@IsTest
	static void testSurveyNameGeneration() {
		Test.startTest();

		Training_Request__c tr = new Training_Request__c();
		tr.Training_Type__c = 'EAP Training';
		insert tr;

		Test.stopTest();

		// Verify survey names include training request name
		List<Survey__c> surveys = [
			SELECT Id, Name
			FROM Survey__c
			WHERE Name LIKE 'Corporate Training 2024%'
			ORDER BY Name
		];

		System.assertEquals(3, surveys.size(), 'Should create 3 surveys');

		Boolean hasCustomerSurvey = false;
		Boolean hasParticipantSurvey = false;
		Boolean hasTrainerSurvey = false;

		for (Survey__c survey : surveys) {
			if (survey.Name.contains('Customer Survey'))
				hasCustomerSurvey = true;
			if (survey.Name.contains('Participant Survey'))
				hasParticipantSurvey = true;
			if (survey.Name.contains('Trainer Survey'))
				hasTrainerSurvey = true;
		}

		System.assert(hasCustomerSurvey, 'Should have Customer Survey');
		System.assert(hasParticipantSurvey, 'Should have Participant Survey');
		System.assert(hasTrainerSurvey, 'Should have Trainer Survey');
	}

	/**
	 * @description Test error handling when template is missing
	 */
	@IsTest
	static void testMissingTemplate() {
		// Delete one of the templates
		Survey__c customerTemplate = [SELECT Id FROM Survey__c WHERE Name = 'CustomerSurveyTemplate' LIMIT 1];
		delete customerTemplate;

		Test.startTest();

		Training_Request__c tr = new Training_Request__c();
		tr.Training_Type__c = 'EAP Training';
		insert tr;

		Test.stopTest();

		// Query the training request
		Training_Request__c insertedTr = [
			SELECT Id, Participant_Survey__c, Customer_Survey__c, Trainer_Survey__c
			FROM Training_Request__c
			WHERE Id = :tr.Id
		];

		// Verify participant and trainer surveys were created, but customer was not
		System.assertNotEquals(null, insertedTr.Participant_Survey__c, 'Participant survey should be created');
		System.assertEquals(null, insertedTr.Customer_Survey__c, 'Customer survey should not be created (no template)');
		System.assertNotEquals(null, insertedTr.Trainer_Survey__c, 'Trainer survey should be created');
	}
}
