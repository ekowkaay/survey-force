/**
 * @description Test class for SurveyForceConstants
 * Validates constant values and helper methods
 */
@IsTest
private class SurveyForceConstants_Test {
	/**
	 * @description Test status string conversion
	 */
	@IsTest
	static void testGetStatusString() {
		// Test
		String pendingStatus = SurveyForceConstants.getStatusString(SurveyForceConstants.InvitationStatus.PENDING);
		String completedStatus = SurveyForceConstants.getStatusString(SurveyForceConstants.InvitationStatus.COMPLETED);
		String expiredStatus = SurveyForceConstants.getStatusString(SurveyForceConstants.InvitationStatus.EXPIRED);

		// Assert
		System.assertEquals('Pending', pendingStatus, 'Pending status should match');
		System.assertEquals('Completed', completedStatus, 'Completed status should match');
		System.assertEquals('Expired', expiredStatus, 'Expired status should match');
	}

	/**
	 * @description Test survey type string conversion
	 */
	@IsTest
	static void testGetSurveyTypeString() {
		// Test
		String participantType = SurveyForceConstants.getSurveyTypeString(SurveyForceConstants.SurveyType.PARTICIPANT);
		String customerType = SurveyForceConstants.getSurveyTypeString(SurveyForceConstants.SurveyType.CUSTOMER);
		String trainerType = SurveyForceConstants.getSurveyTypeString(SurveyForceConstants.SurveyType.TRAINER);

		// Assert
		System.assertEquals('Participant', participantType, 'Participant type should match');
		System.assertEquals('Customer', customerType, 'Customer type should match');
		System.assertEquals('Trainer', trainerType, 'Trainer type should match');
	}

	/**
	 * @description Test language string conversion
	 */
	@IsTest
	static void testGetLanguageString() {
		// Test
		String englishLang = SurveyForceConstants.getLanguageString(SurveyForceConstants.Language.ENGLISH);
		String spanishLang = SurveyForceConstants.getLanguageString(SurveyForceConstants.Language.SPANISH);

		// Assert
		System.assertEquals('English', englishLang, 'English language should match');
		System.assertEquals('Spanish', spanishLang, 'Spanish language should match');
	}

	/**
	 * @description Test template name retrieval
	 */
	@IsTest
	static void testGetTemplateName() {
		// Test
		String participantEnglish = SurveyForceConstants.getTemplateName(SurveyForceConstants.SurveyType.PARTICIPANT, SurveyForceConstants.Language.ENGLISH);
		String participantSpanish = SurveyForceConstants.getTemplateName(SurveyForceConstants.SurveyType.PARTICIPANT, SurveyForceConstants.Language.SPANISH);
		String customer = SurveyForceConstants.getTemplateName(SurveyForceConstants.SurveyType.CUSTOMER, SurveyForceConstants.Language.ENGLISH);
		String trainer = SurveyForceConstants.getTemplateName(SurveyForceConstants.SurveyType.TRAINER, SurveyForceConstants.Language.ENGLISH);

		// Assert
		System.assertEquals('ParticipantSurveyTemplate', participantEnglish, 'Participant English template should match');
		System.assertEquals('ParticipantSurveyTemplate Spanish', participantSpanish, 'Participant Spanish template should match');
		System.assertEquals('CustomerSurveyTemplate', customer, 'Customer template should match');
		System.assertEquals('TrainerSurveyTemplate', trainer, 'Trainer template should match');
	}

	/**
	 * @description Test question type helpers
	 */
	@IsTest
	static void testQuestionTypeHelpers() {
		// Test single select
		System.assert(SurveyForceConstants.isSelectQuestionType(SurveyForceConstants.QUESTION_TYPE_SINGLE_SELECT_VERTICAL), 'Single select vertical should be a select type');
		System.assert(
			SurveyForceConstants.isSelectQuestionType(SurveyForceConstants.QUESTION_TYPE_SINGLE_SELECT_HORIZONTAL),
			'Single select horizontal should be a select type'
		);
		System.assert(SurveyForceConstants.isSingleSelectQuestionType(SurveyForceConstants.QUESTION_TYPE_SINGLE_SELECT_VERTICAL), 'Should be single select');

		// Test multi select
		System.assert(SurveyForceConstants.isSelectQuestionType(SurveyForceConstants.QUESTION_TYPE_MULTI_SELECT_VERTICAL), 'Multi select should be a select type');
		System.assert(SurveyForceConstants.isMultiSelectQuestionType(SurveyForceConstants.QUESTION_TYPE_MULTI_SELECT_VERTICAL), 'Should be multi select');

		// Test free text is not select
		System.assert(!SurveyForceConstants.isSelectQuestionType(SurveyForceConstants.QUESTION_TYPE_FREE_TEXT), 'Free text should not be a select type');
	}

	/**
	 * @description Test constant values are not null
	 */
	@IsTest
	static void testConstantValues() {
		// Assert all constants are defined
		System.assertNotEquals(null, SurveyForceConstants.STATUS_PENDING, 'Pending status should be defined');
		System.assertNotEquals(null, SurveyForceConstants.STATUS_COMPLETED, 'Completed status should be defined');
		System.assertNotEquals(null, SurveyForceConstants.STATUS_EXPIRED, 'Expired status should be defined');

		System.assertNotEquals(null, SurveyForceConstants.SURVEY_TYPE_PARTICIPANT, 'Participant type should be defined');
		System.assertNotEquals(null, SurveyForceConstants.SURVEY_TYPE_CUSTOMER, 'Customer type should be defined');
		System.assertNotEquals(null, SurveyForceConstants.SURVEY_TYPE_TRAINER, 'Trainer type should be defined');

		System.assertNotEquals(null, SurveyForceConstants.TEMPLATE_PARTICIPANT_ENGLISH, 'Participant English template should be defined');
		System.assertNotEquals(null, SurveyForceConstants.TEMPLATE_CUSTOMER, 'Customer template should be defined');
		System.assertNotEquals(null, SurveyForceConstants.TEMPLATE_TRAINER, 'Trainer template should be defined');

		System.assert(SurveyForceConstants.DEFAULT_EXPIRATION_DAYS > 0, 'Default expiration days should be positive');
		System.assert(SurveyForceConstants.MAX_BULK_INVITATIONS > 0, 'Max bulk invitations should be positive');
	}
}
