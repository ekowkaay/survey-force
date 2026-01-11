/**
 * @description Trigger for Participants__c object.
 * Follows the one trigger per object pattern and delegates logic to handler.
 * Only includes context methods that have actual business logic implemented.
 */
trigger ParticipantsTrigger on Participants__c(after insert) {
	ParticipantsTriggerHandler handler = new ParticipantsTriggerHandler();

	if (Trigger.isAfter && Trigger.isInsert) {
		handler.afterInsert(Trigger.new, Trigger.newMap);
	}
}