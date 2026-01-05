/**
 * @description Handler for Survey_Question__c trigger.
 * Implements trigger logic for survey question operations, including
 * automatic name field population from question text.
 * Follows best practices by separating trigger logic from trigger itself.
 */
public with sharing class SurveyQuestionTriggerHandler {
	/** Maximum length for the Name field */
	private static final Integer MAX_NAME_LENGTH = 80;

	/** Static flag to prevent recursive trigger execution */
	private static Boolean isExecuting = false;

	/**
	 * @description Before insert handler - sets Name field from Question text
	 * @param newRecords List of new Survey Question records
	 */
	public void beforeInsert(List<Survey_Question__c> newRecords) {
		if (isExecuting) {
			return;
		}

		isExecuting = true;
		try {
			setQuestionNames(newRecords);
		} finally {
			isExecuting = false;
		}
	}

	/**
	 * @description Before update handler - updates Name field from Question text if changed
	 * @param newRecords List of updated Survey Question records
	 * @param oldMap Map of old Survey Question records
	 */
	public void beforeUpdate(List<Survey_Question__c> newRecords, Map<Id, Survey_Question__c> oldMap) {
		if (isExecuting) {
			return;
		}

		isExecuting = true;
		try {
			setQuestionNames(newRecords);
		} finally {
			isExecuting = false;
		}
	}

	/**
	 * @description Set Name field from Question__c field with proper truncation and escaping
	 * @param questions List of Survey Question records to process
	 */
	private void setQuestionNames(List<Survey_Question__c> questions) {
		for (Survey_Question__c sq : questions) {
			if (String.isBlank(sq.Question__c)) {
				continue;
			}

			// Escape single quotes for SOQL safety
			String escapedQuestion = String.escapeSingleQuotes(sq.Question__c);

			// Truncate to max length if needed
			if (escapedQuestion.length() > MAX_NAME_LENGTH) {
				sq.Name = escapedQuestion.substring(0, MAX_NAME_LENGTH - 1);
			} else {
				sq.Name = escapedQuestion;
			}
		}
	}
}
