/**
 * GroupProposalDiscountTrigger
 * Handles Group_Proposal_Discount__c trigger events
 */
trigger GroupProposalDiscountTrigger on Group_Proposal_Discount__c (
    before insert, before update
) {
    GroupProposalDiscountTriggerHandler handler = new GroupProposalDiscountTriggerHandler();
    
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            handler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
