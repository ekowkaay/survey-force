/**
 * @description Trigger for Training_Request__c object.
 * Follows the one trigger per object pattern and delegates logic to handler.
 * Only includes context methods that have actual business logic implemented.
 */
trigger TrainingRequestTrigger on Training_Request__c(after insert) {
	TrainingRequestTriggerHandler handler = new TrainingRequestTriggerHandler();

	if (Trigger.isAfter && Trigger.isInsert) {
		handler.afterInsert(Trigger.new, Trigger.newMap);
	}
}