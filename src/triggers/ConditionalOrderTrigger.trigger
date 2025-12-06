/**
 * ConditionalOrderTrigger
 * Handles Conditional_Order__c trigger events
 */
trigger ConditionalOrderTrigger on Conditional_Order__c (
    before insert, before update, before delete,
    after insert, after update, after delete
) {
    ConditionalOrderTriggerHandler handler = new ConditionalOrderTriggerHandler();
    
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            handler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.beforeUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            handler.beforeDelete(Trigger.old);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            handler.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.afterUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            handler.afterDelete(Trigger.old);
        }
    }
}
