/**
 * @description Trigger for Training_Request__c object.
 * Follows the one trigger per object pattern.
 */
trigger TrainingRequestTrigger on Training_Request__c(
	before insert,
	before update,
	after insert,
	after update,
	after delete,
	after undelete
) {
	TrainingRequestTriggerHandler handler = new TrainingRequestTriggerHandler();

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
