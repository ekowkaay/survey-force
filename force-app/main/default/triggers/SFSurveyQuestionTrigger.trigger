/**
 * @description Trigger for Survey_Question__c object.
 * Follows the one trigger per object pattern and delegates logic to handler class.
 */
trigger SFSurveyQuestionTrigger on Survey_Question__c(before insert, before update) {
	SurveyQuestionTriggerHandler handler = new SurveyQuestionTriggerHandler();

	if (Trigger.isBefore) {
		if (Trigger.isInsert) {
			handler.beforeInsert(Trigger.new);
		} else if (Trigger.isUpdate) {
			handler.beforeUpdate(Trigger.new, Trigger.oldMap);
		}
	}
}