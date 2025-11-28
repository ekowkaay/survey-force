/**
 * LWC-compatible controller for building surveys with questions
 * Handles question creation, updates, and reordering
 */
public with sharing class SurveyBuilderController {
	/**
	 * Create a new survey question
	 * @param questionData Map of question field values
	 * @return ID of the created question
	 */
	@AuraEnabled
	public static Id createQuestion(Map<String, Object> questionData) {
		try {
			List<Schema.SobjectField> fields = new List<Schema.SobjectField>{
				Schema.Survey_Question__c.fields.Question__c,
				Schema.Survey_Question__c.fields.Type__c,
				Schema.Survey_Question__c.fields.Required__c,
				Schema.Survey_Question__c.fields.Choices__c,
				Schema.Survey_Question__c.fields.OrderNumber__c,
				Schema.Survey_Question__c.fields.Survey__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToCreate(Schema.Survey_Question__c.getSobjectType(), fields);

			Survey_Question__c question = new Survey_Question__c();
			question.Question__c = (String) questionData.get('Question__c');
			question.Type__c = (String) questionData.get('Type__c');
			question.Required__c = questionData.get('Required__c') != null ? (Boolean) questionData.get('Required__c') : false;
			question.Choices__c = (String) questionData.get('Choices__c');
			question.OrderNumber__c = questionData.get('OrderNumber__c') != null ? (Decimal) questionData.get('OrderNumber__c') : 1;
			question.Survey__c = (Id) questionData.get('Survey__c');

			insert question;
			return question.Id;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyBuilderController:createQuestion():' + e.getMessage());
			throw new AuraHandledException('Error creating question: ' + e.getMessage());
		}
	}

	/**
	 * Update an existing survey question
	 * @param questionData Map of question field values (must include Id)
	 * @return Success message
	 */
	@AuraEnabled
	public static String updateQuestion(Map<String, Object> questionData) {
		try {
			List<Schema.SobjectField> fields = new List<Schema.SobjectField>{
				Schema.Survey_Question__c.fields.Question__c,
				Schema.Survey_Question__c.fields.Type__c,
				Schema.Survey_Question__c.fields.Required__c,
				Schema.Survey_Question__c.fields.Choices__c,
				Schema.Survey_Question__c.fields.OrderNumber__c,
				Schema.Survey_Question__c.fields.Hide_on_Survey__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToUpdate(Schema.Survey_Question__c.getSobjectType(), fields);

			Survey_Question__c question = new Survey_Question__c();
			question.Id = (Id) questionData.get('Id');

			if (questionData.containsKey('Question__c')) {
				question.Question__c = (String) questionData.get('Question__c');
			}
			if (questionData.containsKey('Type__c')) {
				question.Type__c = (String) questionData.get('Type__c');
			}
			if (questionData.containsKey('Required__c')) {
				question.Required__c = (Boolean) questionData.get('Required__c');
			}
			if (questionData.containsKey('Choices__c')) {
				question.Choices__c = (String) questionData.get('Choices__c');
			}
			if (questionData.containsKey('OrderNumber__c')) {
				question.OrderNumber__c = (Decimal) questionData.get('OrderNumber__c');
			}
			if (questionData.containsKey('Hide_on_Survey__c')) {
				question.Hide_on_Survey__c = (Boolean) questionData.get('Hide_on_Survey__c');
			}

			update question;
			return 'Question updated successfully';
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyBuilderController:updateQuestion():' + e.getMessage());
			throw new AuraHandledException('Error updating question: ' + e.getMessage());
		}
	}

	/**
	 * Reorder survey questions
	 * @param questionIds List of question IDs in the desired order
	 * @return Success message
	 */
	@AuraEnabled
	public static String reorderQuestions(List<Id> questionIds) {
		try {
			List<Schema.SobjectField> fields = new List<Schema.SobjectField>{ Schema.Survey_Question__c.fields.OrderNumber__c };
			SurveyForceUtil.accessController.assertAuthorizedToUpdate(Schema.Survey_Question__c.getSobjectType(), fields);

			List<Survey_Question__c> questionsToUpdate = new List<Survey_Question__c>();
			Integer orderNumber = 1;

			for (Id questionId : questionIds) {
				Survey_Question__c question = new Survey_Question__c();
				question.Id = questionId;
				question.OrderNumber__c = orderNumber++;
				questionsToUpdate.add(question);
			}

			if (!questionsToUpdate.isEmpty()) {
				update questionsToUpdate;
			}

			return 'Questions reordered successfully';
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyBuilderController:reorderQuestions():' + e.getMessage());
			throw new AuraHandledException('Error reordering questions: ' + e.getMessage());
		}
	}

	/**
	 * Get question types available for surveys
	 * @return List of question type options
	 */
	@AuraEnabled(cacheable=true)
	public static List<Map<String, String>> getQuestionTypes() {
		List<Map<String, String>> types = new List<Map<String, String>>();

		types.add(new Map<String, String>{ 'label' => 'Free Text', 'value' => 'Free Text' });
		types.add(new Map<String, String>{ 'label' => 'Single Select (Vertical)', 'value' => 'Single Select--Vertical' });
		types.add(new Map<String, String>{ 'label' => 'Single Select (Horizontal)', 'value' => 'Single Select--Horizontal' });
		types.add(new Map<String, String>{ 'label' => 'Multi-Select (Vertical)', 'value' => 'Multi-Select--Vertical' });

		return types;
	}

	/**
	 * Duplicate a question within the same survey
	 * @param questionId The question to duplicate
	 * @return ID of the new question
	 */
	@AuraEnabled
	public static Id duplicateQuestion(Id questionId) {
		try {
			List<Schema.SobjectField> viewFields = new List<Schema.SobjectField>{
				Schema.Survey_Question__c.fields.Question__c,
				Schema.Survey_Question__c.fields.Type__c,
				Schema.Survey_Question__c.fields.Required__c,
				Schema.Survey_Question__c.fields.Choices__c,
				Schema.Survey_Question__c.fields.OrderNumber__c,
				Schema.Survey_Question__c.fields.Survey__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToView(Schema.Survey_Question__c.getSobjectType(), viewFields);
			SurveyForceUtil.accessController.assertAuthorizedToCreate(Schema.Survey_Question__c.getSobjectType(), viewFields);

			Survey_Question__c original = [
				SELECT Question__c, Type__c, Required__c, Choices__c, OrderNumber__c, Survey__c
				FROM Survey_Question__c
				WHERE Id = :questionId
				WITH USER_MODE
				LIMIT 1
			];

			// Get max order number for the survey
			AggregateResult maxOrder = [SELECT MAX(OrderNumber__c) maxNum FROM Survey_Question__c WHERE Survey__c = :original.Survey__c WITH USER_MODE];
			Decimal newOrder = maxOrder.get('maxNum') != null ? ((Decimal) maxOrder.get('maxNum')) + 1 : 1;

			Survey_Question__c duplicate = original.clone(false, true, false, false);
			duplicate.Question__c = 'Copy of ' + original.Question__c;
			duplicate.OrderNumber__c = newOrder;

			insert duplicate;
			return duplicate.Id;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyBuilderController:duplicateQuestion():' + e.getMessage());
			throw new AuraHandledException('Error duplicating question: ' + e.getMessage());
		}
	}
}