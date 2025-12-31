/**
 * @description Trigger for Participants__c object.
 * Follows the one trigger per object pattern.
 */
trigger ParticipantsTrigger on Participants__c(before insert, before update, after insert, after update, after delete, after undelete) {
	ParticipantsTriggerHandler handler = new ParticipantsTriggerHandler();

	if (Trigger.isBefore) {
		if (Trigger.isInsert) {
			handler.beforeInsert(Trigger.new);
		} else if (Trigger.isUpdate) {
			handler.beforeUpdate(Trigger.new, Trigger.oldMap);
		}
	} else if (Trigger.isAfter) {
		if (Trigger.isInsert) {
			handler.afterInsert(Trigger.new, Trigger.newMap);
		} else if (Trigger.isUpdate) {
			handler.afterUpdate(Trigger.new, Trigger.newMap, Trigger.oldMap);
		} else if (Trigger.isDelete) {
			handler.afterDelete(Trigger.old, Trigger.oldMap);
		} else if (Trigger.isUndelete) {
			handler.afterUndelete(Trigger.new, Trigger.newMap);
		}
	}
}