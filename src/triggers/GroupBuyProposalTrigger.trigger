/**
 * GroupBuyProposalTrigger
 * Handles Group_Buy_Proposal__c trigger events
 */
trigger GroupBuyProposalTrigger on Group_Buy_Proposal__c (
    before insert, before update,
    after insert, after update
) {
    GroupBuyProposalTriggerHandler handler = new GroupBuyProposalTriggerHandler();
    
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            handler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            handler.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
