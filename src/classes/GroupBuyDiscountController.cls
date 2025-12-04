/**
 * GroupBuyDiscountController
 * Controller for managing volume discount tiers on Group Buy Proposals
 */
public with sharing class GroupBuyDiscountController {
    
    /**
     * Get all discount tiers for a proposal
     */
    @AuraEnabled(cacheable=true)
    public static List<Group_Proposal_Discount__c> getDiscounts(Id proposalId) {
        return [
            SELECT Id, 
                   Group_Buy_Proposal__c,
                   Min_Quota_For_Discount__c, 
                   Max_Quota_Discount__c, 
                   Discount__c,
                   CreatedDate,
                   LastModifiedDate
            FROM Group_Proposal_Discount__c
            WHERE Group_Buy_Proposal__c = :proposalId
            ORDER BY Min_Quota_For_Discount__c ASC
        ];
    }
    
    /**
     * Save discount tiers (upsert new/modified, delete removed)
     */
    @AuraEnabled
    public static void saveDiscounts(List<Group_Proposal_Discount__c> discountsToUpsert, List<Id> discountsToDelete) {
        try {
            // Delete removed tiers
            if (discountsToDelete != null && !discountsToDelete.isEmpty()) {
                List<Group_Proposal_Discount__c> toDelete = [
                    SELECT Id FROM Group_Proposal_Discount__c 
                    WHERE Id IN :discountsToDelete
                ];
                delete toDelete;
            }
            
            // Upsert new/modified tiers
            if (discountsToUpsert != null && !discountsToUpsert.isEmpty()) {
                upsert discountsToUpsert;
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error saving discounts: ' + e.getMessage());
        }
    }
    
    /**
     * Delete a single discount tier
     */
    @AuraEnabled
    public static void deleteDiscount(Id discountId) {
        try {
            delete [SELECT Id FROM Group_Proposal_Discount__c WHERE Id = :discountId];
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting discount: ' + e.getMessage());
        }
    }
}
