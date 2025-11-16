/**
 * LWC-compatible controller for taking surveys
 * Modern replacement for ViewSurveyController with @AuraEnabled methods
 */
public with sharing class SurveyTakerController {
	/**
	 * Survey data wrapper for LWC
	 */
	public class SurveyData {
		@AuraEnabled
		public Survey__c survey { get; set; }
		@AuraEnabled
		public List<QuestionData> questions { get; set; }
		@AuraEnabled
		public Boolean isInternal { get; set; }
		@AuraEnabled
		public String anonymousOption { get; set; }
	}

	/**
	 * Question data wrapper for LWC
	 */
	public class QuestionData {
		@AuraEnabled
		public Id id { get; set; }
		@AuraEnabled
		public String question { get; set; }
		@AuraEnabled
		public Integer orderNumber { get; set; }
		@AuraEnabled
		public String questionType { get; set; }
		@AuraEnabled
		public Boolean required { get; set; }
		@AuraEnabled
		public List<OptionData> choices { get; set; }
		@AuraEnabled
		public Boolean hideOnSurvey { get; set; }
		@AuraEnabled
		public Integer rowsForTextArea { get; set; }
	}

	/**
	 * Option data wrapper for LWC
	 */
	public class OptionData {
		@AuraEnabled
		public String label { get; set; }
		@AuraEnabled
		public String value { get; set; }
	}

	/**
	 * Response wrapper for LWC
	 */
	public class ResponseData {
		@AuraEnabled
		public Id questionId { get; set; }
		@AuraEnabled
		public String response { get; set; }
		@AuraEnabled
		public List<String> responses { get; set; }
	}

	/**
	 * Submit result wrapper
	 */
	public class SubmitResult {
		@AuraEnabled
		public Boolean success { get; set; }
		@AuraEnabled
		public String message { get; set; }
		@AuraEnabled
		public String thankYouText { get; set; }
		@AuraEnabled
		public String thankYouLink { get; set; }
	}

	/**
	 * Get survey data including questions
	 * @param surveyId Survey record ID
	 * @param caseId Optional Case ID
	 * @param contactId Optional Contact ID
	 * @return SurveyData wrapper with all survey information
	 */
	@AuraEnabled(cacheable=true)
	public static SurveyData getSurveyData(Id surveyId, String caseId, String contactId) {
		try {
			SurveyData result = new SurveyData();

			// Determine if user is internal or guest
			result.isInternal = System.UserInfo.getUserType() != 'Guest';

			// Get survey record
			Survey__c survey;
			if (System.UserInfo.getUserType() == 'Guest') {
				survey = ViewSurveyControllerWithoutSharing.getSurveyForGuestUser(surveyId);
			} else {
				List<Schema.SobjectField> surveyFields = new List<Schema.SobjectField>{
					Schema.Survey__c.fields.Name,
					Schema.Survey__c.fields.Survey_Header__c,
					Schema.Survey__c.fields.Hide_Survey_Name__c,
					Schema.Survey__c.fields.Thank_You_Text__c,
					Schema.Survey__c.fields.Thank_You_Link__c,
					Schema.Survey__c.fields.All_Responses_Anonymous__c,
					Schema.Survey__c.fields.Survey_Container_CSS__c
				};
				SurveyForceUtil.accessController.assertAuthorizedToView(Schema.Survey__c.getSobjectType(), surveyFields);

				survey = [
					SELECT Id, Name, Survey_Header__c, Hide_Survey_Name__c, Thank_You_Text__c, Thank_You_Link__c, All_Responses_Anonymous__c, Survey_Container_CSS__c
					FROM Survey__c
					WHERE Id = :surveyId
					WITH USER_MODE
					LIMIT 1
				];
			}

			if (survey == null) {
				throw new AuraHandledException('Survey not found or not available');
			}

			result.survey = survey;

			// Set anonymous option
			result.anonymousOption = (System.UserInfo.getUserType() == 'Guest' || survey.All_Responses_Anonymous__c) ? 'Anonymous' : 'User';

			// Get questions
			result.questions = getQuestions(surveyId);

			return result;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyTakerController:getSurveyData():' + e.getMessage());
			throw new AuraHandledException('Error loading survey: ' + e.getMessage());
		}
	}

	/**
	 * Get questions for a survey
	 */
	private static List<QuestionData> getQuestions(Id surveyId) {
		List<Survey_Question__c> questionRecords;

		if (System.UserInfo.getUserType() == 'Guest') {
			questionRecords = ViewSurveyControllerWithoutSharing.getSurveyQuestionsForGuestUser(surveyId);
		} else {
			List<Schema.SobjectField> questionFields = new List<Schema.SobjectField>{
				Schema.Survey_Question__c.fields.Question__c,
				Schema.Survey_Question__c.fields.OrderNumber__c,
				Schema.Survey_Question__c.fields.Type__c,
				Schema.Survey_Question__c.fields.Required__c,
				Schema.Survey_Question__c.fields.Choices__c,
				Schema.Survey_Question__c.fields.Hide_on_Survey__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToView(Schema.Survey_Question__c.getSobjectType(), questionFields);

			questionRecords = [
				SELECT Id, Question__c, OrderNumber__c, Type__c, Required__c, Choices__c, Hide_on_Survey__c
				FROM Survey_Question__c
				WHERE Survey__c = :surveyId
				WITH USER_MODE
				ORDER BY OrderNumber__c ASC NULLS LAST
			];
		}

		List<QuestionData> questions = new List<QuestionData>();
		Integer orderNumber = 1;

		for (Survey_Question__c q : questionRecords) {
			QuestionData qd = new QuestionData();
			qd.id = q.Id;
			qd.question = q.Question__c;
			qd.orderNumber = orderNumber++;
			qd.questionType = q.Type__c;
			qd.required = q.Required__c != null ? q.Required__c : false;
			qd.hideOnSurvey = q.Hide_on_Survey__c != null ? q.Hide_on_Survey__c : false;
			qd.rowsForTextArea = 3; // Default value

			// Parse choices
			if (String.isNotBlank(q.Choices__c)) {
				qd.choices = parseChoices(q.Choices__c);
			} else {
				qd.choices = new List<OptionData>();
			}

			questions.add(qd);
		}

		return questions;
	}

	/**
	 * Parse choices string into option data list
	 */
	private static List<OptionData> parseChoices(String choicesString) {
		List<OptionData> options = new List<OptionData>();
		if (String.isBlank(choicesString)) {
			return options;
		}

		List<String> choices = choicesString.split('\n');
		Integer index = 0;
		for (String choice : choices) {
			if (String.isNotBlank(choice.trim())) {
				OptionData option = new OptionData();
				option.label = choice.trim();
				option.value = String.valueOf(index++);
				options.add(option);
			}
		}

		return options;
	}

	/**
	 * Submit survey responses
	 * @param surveyId Survey record ID
	 * @param responses List of responses
	 * @param caseId Optional Case ID
	 * @param contactId Optional Contact ID
	 * @param isAnonymous Whether response should be anonymous
	 * @return SubmitResult with success status and messages
	 */
	@AuraEnabled
	public static SubmitResult submitSurveyResponses(Id surveyId, List<ResponseData> responses, String caseId, String contactId, Boolean isAnonymous) {
		SubmitResult result = new SubmitResult();
		result.success = false;

		try {
			// Validate responses
			List<QuestionData> questions = getQuestions(surveyId);
			Map<Id, QuestionData> questionMap = new Map<Id, QuestionData>();
			for (QuestionData q : questions) {
				questionMap.put(q.id, q);
			}

			// Check required questions
			Map<Id, ResponseData> responseMap = new Map<Id, ResponseData>();
			for (ResponseData r : responses) {
				responseMap.put(r.questionId, r);
			}

			for (QuestionData q : questions) {
				if (q.required && !q.hideOnSurvey) {
					ResponseData response = responseMap.get(q.id);
					if (response == null || (String.isBlank(response.response) && (response.responses == null || response.responses.isEmpty()))) {
						result.message = 'Please answer all required questions';
						return result;
					}
				}
			}

			// Create survey taker record
			Id surveyTakerId = createSurveyTaker(surveyId, caseId, contactId, isAnonymous);

			if (surveyTakerId == null) {
				result.message = 'Error creating survey response record';
				return result;
			}

			// Create response records
			List<SurveyQuestionResponse__c> responseRecords = new List<SurveyQuestionResponse__c>();

			for (ResponseData r : responses) {
				QuestionData question = questionMap.get(r.questionId);
				if (question == null || question.hideOnSurvey) {
					continue;
				}

				if (question.questionType == 'Single Select--Vertical' || question.questionType == 'Single Select--Horizontal') {
					if (String.isNotBlank(r.response)) {
						SurveyQuestionResponse__c sqr = new SurveyQuestionResponse__c();
						sqr.Survey_Question__c = r.questionId;
						sqr.SurveyTaker__c = surveyTakerId;
						sqr.Response__c = getChoiceLabel(question.choices, r.response);
						responseRecords.add(sqr);
					}
				} else if (question.questionType == 'Multi-Select--Vertical') {
					if (r.responses != null && !r.responses.isEmpty()) {
						for (String selectedValue : r.responses) {
							SurveyQuestionResponse__c sqr = new SurveyQuestionResponse__c();
							sqr.Survey_Question__c = r.questionId;
							sqr.SurveyTaker__c = surveyTakerId;
							sqr.Response__c = getChoiceLabel(question.choices, selectedValue);
							responseRecords.add(sqr);
						}
					}
				} else if (question.questionType == 'Free Text') {
					if (String.isNotBlank(r.response)) {
						SurveyQuestionResponse__c sqr = new SurveyQuestionResponse__c();
						sqr.Survey_Question__c = r.questionId;
						sqr.SurveyTaker__c = surveyTakerId;
						sqr.Response__c = r.response;
						responseRecords.add(sqr);
					}
				}
			}

			// Insert responses
			if (!responseRecords.isEmpty()) {
				ViewSurveyControllerWithoutSharing.createSurveyQuestionResponse(responseRecords);
			}

			// Get thank you information
			Survey__c survey;
			if (System.UserInfo.getUserType() == 'Guest') {
				survey = ViewSurveyControllerWithoutSharing.getSurveyForGuestUser(surveyId);
			} else {
				survey = [
					SELECT Thank_You_Text__c, Thank_You_Link__c
					FROM Survey__c
					WHERE Id = :surveyId
					WITH USER_MODE
					LIMIT 1
				];
			}

			result.success = true;
			result.message = 'Survey submitted successfully';
			result.thankYouText = String.isNotBlank(survey.Thank_You_Text__c) ? survey.Thank_You_Text__c : System.Label.LABS_SF_Survey_Submitted_Thank_you;
			result.thankYouLink = survey.Thank_You_Link__c;

			return result;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyTakerController:submitSurveyResponses():' + e.getMessage());
			result.message = 'Error submitting survey: ' + e.getMessage();
			return result;
		}
	}

	/**
	 * Get choice label from value
	 */
	private static String getChoiceLabel(List<OptionData> choices, String value) {
		for (OptionData option : choices) {
			if (option.value == value) {
				return option.label;
			}
		}
		return value;
	}

	/**
	 * Create survey taker record
	 */
	private static Id createSurveyTaker(Id surveyId, String caseId, String contactId, Boolean isAnonymous) {
		try {
			// Get survey to check if responses are forced anonymous
			Survey__c survey;
			if (System.UserInfo.getUserType() == 'Guest') {
				survey = ViewSurveyControllerWithoutSharing.getSurveyForGuestUser(surveyId);
			} else {
				survey = [SELECT All_Responses_Anonymous__c FROM Survey__c WHERE Id = :surveyId WITH USER_MODE LIMIT 1];
			}

			SurveyTaker__c st = new SurveyTaker__c();
			st.Survey__c = surveyId;
			st.Completed__c = true;

			// Handle case and contact
			if (String.isNotBlank(caseId) && caseId != 'none' && caseId instanceof Id) {
				st.Case__c = caseId;
			}
			if (String.isNotBlank(contactId) && contactId != 'none' && contactId instanceof Id) {
				st.Contact__c = contactId;
			}

			// Handle user tracking
			if (System.UserInfo.getUserType() == 'Guest') {
				st.User__c = System.UserInfo.getUserId();
			} else if (survey.All_Responses_Anonymous__c || isAnonymous) {
				st.User__c = null;
			} else {
				st.User__c = System.UserInfo.getUserId();
			}

			// Check for duplicate survey taker
			if (!isAnonymous && System.Site.getName() == null && st.User__c != null) {
				List<SurveyTaker__c> existing = [
					SELECT Id
					FROM SurveyTaker__c
					WHERE
						Survey__c = :surveyId
						AND User__c = :st.User__c
						AND User__r.UserType != 'Guest'
						AND ((Contact__c != NULL
						AND Contact__c = :st.Contact__c)
						OR (Case__c != NULL
						AND Case__c = :st.Case__c))
					WITH USER_MODE
					LIMIT 1
				];

				if (!existing.isEmpty()) {
					throw new AuraHandledException(System.Label.LABS_SF_You_have_already_taken_this_survey);
				}
			}

			ViewSurveyControllerWithoutSharing.createSurveyTaken(st);
			return st.Id;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyTakerController:createSurveyTaker():' + e.getMessage());
			throw new AuraHandledException('Error creating survey taker: ' + e.getMessage());
		}
	}
}