public with sharing class GroupBuyDiscountController {

    @AuraEnabled(cacheable=true)
    public static List<Group_Proposal_Discount__c> getDiscounts(String proposalId) {
        return [
                SELECT Id, Name, Discount__c, Min_Quota_For_Discount__c, Max_Quota_Discount__c
                FROM Group_Proposal_Discount__c
                WHERE Group_Buy_Proposal__c = :proposalId
                ORDER BY Min_Quota_For_Discount__c ASC
        ];
    }

    @AuraEnabled
    public static void saveDiscounts(List<Group_Proposal_Discount__c> discountsToUpsert, List<Id> discountsToDelete) {
        try {
            if (discountsToDelete != null && !discountsToDelete.isEmpty()) {
                delete [SELECT Id FROM Group_Proposal_Discount__c WHERE Id IN :discountsToDelete];
            }

            if (discountsToUpsert != null && !discountsToUpsert.isEmpty()) {
                upsert discountsToUpsert;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}