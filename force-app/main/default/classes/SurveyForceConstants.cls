/**
 * @description Central repository for all constants used in Survey Force application.
 * Provides type-safe access to commonly used string literals and configuration values.
 * Following DRY principle and improving maintainability by centralizing constant definitions.
 */
public class SurveyForceConstants {
	/**
	 * @description Survey invitation status values
	 */
	public enum InvitationStatus {
		PENDING,
		COMPLETED,
		EXPIRED
	}

	/**
	 * @description Survey type enumeration for type-safe operations
	 */
	public enum SurveyType {
		PARTICIPANT,
		CUSTOMER,
		TRAINER
	}

	/**
	 * @description Language enumeration for survey templates
	 */
	public enum Language {
		ENGLISH,
		SPANISH
	}

	/**
	 * @description Question type enumeration
	 */
	public enum QuestionType {
		FREE_TEXT,
		SINGLE_SELECT_VERTICAL,
		SINGLE_SELECT_HORIZONTAL,
		MULTI_SELECT_VERTICAL
	}

	/** Survey invitation status string constants */
	public static final String STATUS_PENDING = 'Pending';
	public static final String STATUS_COMPLETED = 'Completed';
	public static final String STATUS_EXPIRED = 'Expired';

	/** Survey type string constants */
	public static final String SURVEY_TYPE_PARTICIPANT = 'Participant';
	public static final String SURVEY_TYPE_CUSTOMER = 'Customer';
	public static final String SURVEY_TYPE_TRAINER = 'Trainer';

	/** Language string constants */
	public static final String LANGUAGE_ENGLISH = 'English';
	public static final String LANGUAGE_SPANISH = 'Spanish';

	/** Question type string constants */
	public static final String QUESTION_TYPE_FREE_TEXT = 'Free Text';
	public static final String QUESTION_TYPE_SINGLE_SELECT_VERTICAL = 'Single Select--Vertical';
	public static final String QUESTION_TYPE_SINGLE_SELECT_HORIZONTAL = 'Single Select--Horizontal';
	public static final String QUESTION_TYPE_MULTI_SELECT_VERTICAL = 'Multi-Select--Vertical';

	/** Training type constants */
	public static final String TRAINING_TYPE_EAP = 'EAP Training';

	/** Site URL metadata constants */
	public static final String SITE_URL_EAP_TRAINING = 'EAP_Training';
	public static final String SITE_URL_RESELLER_TRAINING = 'Reseller_Training';

	/** Survey template names */
	public static final String TEMPLATE_PARTICIPANT_ENGLISH = 'ParticipantSurveyTemplate';
	public static final String TEMPLATE_PARTICIPANT_SPANISH = 'ParticipantSurveyTemplate Spanish';
	public static final String TEMPLATE_CUSTOMER = 'CustomerSurveyTemplate';
	public static final String TEMPLATE_TRAINER = 'TrainerSurveyTemplate';

	/** Default configuration values */
	public static final Integer DEFAULT_EXPIRATION_DAYS = 30;
	public static final Integer MAX_BULK_INVITATIONS = 200;
	public static final Integer DEFAULT_TEXTAREA_ROWS = 3;

	/** URL path constants */
	public static final String SURVEY_PAGE_PATH = '/survey';
	public static final String TAKE_SURVEY_PATH = '/TakeSurvey';

	/** Anonymous response option values */
	public static final String ANONYMOUS_OPTION_ANONYMOUS = 'Anonymous';
	public static final String ANONYMOUS_OPTION_USER = 'User';

	/**
	 * @description Convert InvitationStatus enum to string
	 * @param status The enum value
	 * @return String representation of the status
	 */
	public static String getStatusString(InvitationStatus status) {
		switch on status {
			when PENDING {
				return STATUS_PENDING;
			}
			when COMPLETED {
				return STATUS_COMPLETED;
			}
			when EXPIRED {
				return STATUS_EXPIRED;
			}
			when else {
				return STATUS_PENDING;
			}
		}
	}

	/**
	 * @description Convert SurveyType enum to string
	 * @param surveyType The enum value
	 * @return String representation of the survey type
	 */
	public static String getSurveyTypeString(SurveyType surveyType) {
		switch on surveyType {
			when PARTICIPANT {
				return SURVEY_TYPE_PARTICIPANT;
			}
			when CUSTOMER {
				return SURVEY_TYPE_CUSTOMER;
			}
			when TRAINER {
				return SURVEY_TYPE_TRAINER;
			}
			when else {
				return SURVEY_TYPE_PARTICIPANT;
			}
		}
	}

	/**
	 * @description Convert Language enum to string
	 * @param language The enum value
	 * @return String representation of the language
	 */
	public static String getLanguageString(Language language) {
		switch on language {
			when ENGLISH {
				return LANGUAGE_ENGLISH;
			}
			when SPANISH {
				return LANGUAGE_SPANISH;
			}
			when else {
				return LANGUAGE_ENGLISH;
			}
		}
	}

	/**
	 * @description Get survey template name based on type and language
	 * @param surveyType The survey type
	 * @param language The language
	 * @return String The template name or null if invalid combination
	 */
	public static String getTemplateName(SurveyType surveyType, Language language) {
		switch on surveyType {
			when PARTICIPANT {
				return language == SurveyForceConstants.Language.SPANISH ? TEMPLATE_PARTICIPANT_SPANISH : TEMPLATE_PARTICIPANT_ENGLISH;
			}
			when CUSTOMER {
				return TEMPLATE_CUSTOMER;
			}
			when TRAINER {
				return TEMPLATE_TRAINER;
			}
			when else {
				return null;
			}
		}
	}

	/**
	 * @description Check if question type is a select type (single or multi)
	 * @param questionType The question type string
	 * @return Boolean true if it's a select type
	 */
	public static Boolean isSelectQuestionType(String questionType) {
		return questionType == QUESTION_TYPE_SINGLE_SELECT_VERTICAL || questionType == QUESTION_TYPE_SINGLE_SELECT_HORIZONTAL || questionType == QUESTION_TYPE_MULTI_SELECT_VERTICAL;
	}

	/**
	 * @description Check if question type is single select
	 * @param questionType The question type string
	 * @return Boolean true if it's single select
	 */
	public static Boolean isSingleSelectQuestionType(String questionType) {
		return questionType == QUESTION_TYPE_SINGLE_SELECT_VERTICAL || questionType == QUESTION_TYPE_SINGLE_SELECT_HORIZONTAL;
	}

	/**
	 * @description Check if question type is multi select
	 * @param questionType The question type string
	 * @return Boolean true if it's multi select
	 */
	public static Boolean isMultiSelectQuestionType(String questionType) {
		return questionType == QUESTION_TYPE_MULTI_SELECT_VERTICAL;
	}
}