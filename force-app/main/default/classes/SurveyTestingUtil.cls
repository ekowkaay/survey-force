public with sharing class SurveyTestingUtil {
	public Id surveyId { get; set; }
	public List<String> questionIds { get; set; }
	public String contactId { get; set; }
	public String surveyTakerId { get; set; }
	public String contactId2 { get; set; }
	public Survey__c survey;

	public SurveyTestingUtil() {
		questionIds = new List<String>();
		createTestSurvey();
		createTestQuestions();
		createTestContact();
		createSurveyTaker();
		createTestResponses();
	}

	private void createSurveyTaker() {
		SurveyTaker__c st = (SurveyTaker__c) SurveyTaker__c.sObjectType.newSObject(null, true);
		st.Contact__c = contactId;
		st.Survey__c = surveyId;
		st.Completed__c = false;
		insert st;
		surveyTakerId = st.Id;
	}

	public void createTestSurvey() {
		Survey__c s = (Survey__c) Survey__c.sObjectType.newSObject(null, true);
		s.Name = 'Testing Survey';
		s.Thank_You_Text__c = 'empty';
		insert s;
		surveyId = s.Id;
		this.survey = s;
	}

	public static final Integer QUESTION_TYPES = Schema.sObjectType.Survey_Question__c.fields.Type__c.getPicklistValues().size();

	public void createTestQuestions() {
		for (Integer i = 0; i < QUESTION_TYPES; i++) {
			questionIds.add(createQuestion(i).Id);
		}
	}

	private Survey_Question__c createQuestion(Integer i) {
		Survey_Question__c q = (Survey_Question__c) Survey_Question__c.sObjectType.newSObject(null, true);
		q.Name = 'Testing Question';
		q.Survey__c = surveyId;
		q.Type__c = getType(i);
		q.Choices__c = getChoices();
		q.Question__c = 'Testing Question question';
		q.OrderNumber__c = i;
		insert q;
		return q;
	}

	private void createTestContact() {
		Contact c = new Contact();
		c.LastName = 'Doe';
		c.FirstName = 'John';
		c.Email = 'surveyAppUser@hotmail.com';
		insert c;
		contactId = c.Id;

		Contact c2 = new Contact();
		c2.LastName = 'Doe2';
		c2.FirstName = 'John2';
		c2.Email = 'surveyAppUser2@hotmail.com';
		insert c2;
		contactId2 = c2.Id;
	}

	private void createTestResponses() {
		SurveyQuestionResponse__c r = new SurveyQuestionResponse__c();
		r.Response__c = 'two';
		Survey_Question__c sq = [SELECT Id FROM Survey_Question__c WHERE id = :questionIds[1] LIMIT 1];
		r.Survey_Question__c = sq.id;
		r.SurveyTaker__c = surveyTakerId;
		insert r;
	}

	public static String getType(Integer i) {
		Schema.DescribeFieldResult dfr = Schema.sObjectType.Survey_Question__c.fields.Type__c;
		List<Schema.PicklistEntry> ples = dfr.getPicklistValues();

		Integer picklistItem = math.mod(i, ples.size());
		return ples[picklistItem].getValue();

		/* if      (i==1)
		{return 'Multi-Select--Vertical';}
		else if (i==2)
		{return 'Single Select--Vertical';}
		else if (i==3)
		{return 'Free Text';}
		else
		{return 'Single Select--Horizontal';} */
	}
	private String getChoices() {
		return 'one\ntwo\nthree\n';
	}

	public static User createNewAdminPermissionSetUser() {
		/* PermissionSet p = [SELECT Id FROM PermissionSet WHERE IsOwnedByProfile = false AND Name = 'Survey_Force_SuperAdmin' LIMIT 1];
		PermissionSetAssignment psa = new PermissionSetAssignment();
		psa.AssigneeId = System.UserInfo.getUserId();
		psa.PermissionSetId = p.Id;
		try{
			insert psa;
		} catch (Exception e){
			System.debug('Could not assign permission set - it may already be assigned');
		} */

		String uniqueUserName = 'standarduser' + DateTime.now().getTime() + '@testorg.com';
		// This code runs as the system user
		Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
		User u = new User(
			Alias = 'standt',
			Email = 'standarduser@testorg.com',
			EmailEncodingKey = 'UTF-8',
			LastName = 'Testing',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			ProfileId = p.Id,
			TimeZoneSidKey = 'America/Los_Angeles',
			UserName = uniqueUserName
		);

		insert u;

		PermissionSet ps = [SELECT Id, Name FROM PermissionSet WHERE Name = 'Survey_Force_SuperAdmin'];
		System.debug('Permission Set ' + ps);
		PermissionSetAssignment psa = new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
		insert psa;

		System.debug('PERM SET ASSIGNMENT: ' + psa);

		return u;
	}

	/**
	 * @description Creates a test Training Request record (does not insert)
	 * @return Training_Request__c The created test training request
	 */
	public static Training_Request__c createTrainingRequest() {
		Training_Request__c tr = new Training_Request__c();
		tr.Training_Type__c = 'EAP Training';
		return tr;
	}

	/**
	 * @description Creates a test Survey record (does not insert)
	 * Uses newSObject(null, true) for consistency with existing code pattern
	 * @return Survey__c The created test survey
	 */
	public static Survey__c createSurvey() {
		Survey__c s = (Survey__c) Survey__c.sObjectType.newSObject(null, true);
		s.Name = 'Test Survey';
		s.Thank_You_Text__c = 'Thank you for completing the survey';
		return s;
	}

	/**
	 * @description Ensures required Survey__c template records exist for tests
	 *
	 * This method creates Survey__c template records with names that match the
	 * SurveyForceConstants.TEMPLATE_* values used by trigger logic
	 * (e.g., TrainingRequestTriggerHandler / SurveyUtilities.createSurveysInBulk()).
	 * It is intended for use in test setup so that trigger-driven survey creation
	 * can successfully find and use these templates.
	 *
	 * The method is idempotent: if templates already exist with the required
	 * names, they are not recreated.
	 *
	 * Usage example (in a test):
	 * @TestSetup
	 * static void setup() {
	 *     SurveyTestingUtil.createSurveyTemplates();
	 *     // Insert Training_Request__c records here; triggers will create surveys
	 * }
	 */
	public static void createSurveyTemplates() {
		// Collect the template names required by the application.
		List<String> templateNames = new List<String>();

		// Add known template constant values used in the codebase.
		if (String.isNotBlank(SurveyForceConstants.TEMPLATE_PARTICIPANT_ENGLISH)) {
			templateNames.add(SurveyForceConstants.TEMPLATE_PARTICIPANT_ENGLISH);
		}
		if (String.isNotBlank(SurveyForceConstants.TEMPLATE_PARTICIPANT_SPANISH)) {
			templateNames.add(SurveyForceConstants.TEMPLATE_PARTICIPANT_SPANISH);
		}
		if (String.isNotBlank(SurveyForceConstants.TEMPLATE_CUSTOMER)) {
			templateNames.add(SurveyForceConstants.TEMPLATE_CUSTOMER);
		}
		if (String.isNotBlank(SurveyForceConstants.TEMPLATE_TRAINER)) {
			templateNames.add(SurveyForceConstants.TEMPLATE_TRAINER);
		}

		// Return early if there are no templates to create.
		if (templateNames.isEmpty()) {
			return;
		}

		// Query existing templates by name to avoid duplicates.
		List<Survey__c> existingTemplates = [
			SELECT Id, Name
			FROM Survey__c
			WHERE Name IN :templateNames
			WITH USER_MODE
		];

		Set<String> existingNames = new Set<String>();
		for (Survey__c existing : existingTemplates) {
			existingNames.add(existing.Name);
		}

		// Build new Survey__c template records for any missing names.
		List<Survey__c> templatesToInsert = new List<Survey__c>();
		for (String templateName : templateNames) {
			if (existingNames.contains(templateName)) {
				continue;
			}

			Survey__c templateSurvey = (Survey__c) Survey__c.sObjectType.newSObject(null, true);
			templateSurvey.Name = templateName;
			templateSurvey.Thank_You_Text__c = 'Thank you for completing the survey';

			templatesToInsert.add(templateSurvey);
		}

		// No DML if everything already exists.
		if (templatesToInsert.isEmpty()) {
			return;
		}

		// Insert templates in user mode with exception handling.
		try {
			Database.insert(templatesToInsert, AccessLevel.USER_MODE);
		} catch (DmlException e) {
			// In test utilities, we do not rethrow; tests can still proceed even if
			// some templates fail to insert, though they may fail functionally.
			System.debug('Failed to insert survey templates: ' + e.getMessage());
		}
	}
}