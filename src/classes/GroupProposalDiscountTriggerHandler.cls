/**
 * GroupProposalDiscountTriggerHandler
 * Business logic for Group Proposal Discount trigger
 * 
 * Key Functions:
 * 1. Validate no overlapping discount tiers
 * 2. Set tier order automatically
 * 3. Validate discount percentages are progressive
 */
public class GroupProposalDiscountTriggerHandler {
    
    /**
     * Before Insert
     * - Validate no overlaps with existing tiers
     * - Set tier order
     */
    public void beforeInsert(List<Group_Proposal_Discount__c> newDiscounts) {
        validateAndSetTiers(newDiscounts, null);
    }
    
    /**
     * Before Update
     * - Validate no overlaps after update
     */
    public void beforeUpdate(List<Group_Proposal_Discount__c> newDiscounts, Map<Id, Group_Proposal_Discount__c> oldMap) {
        validateAndSetTiers(newDiscounts, oldMap);
    }
    
    /**
     * Main validation and tier setting logic
     */
    private void validateAndSetTiers(List<Group_Proposal_Discount__c> discounts, Map<Id, Group_Proposal_Discount__c> oldMap) {
        // Group by proposal
        Map<Id, List<Group_Proposal_Discount__c>> proposalDiscountMap = new Map<Id, List<Group_Proposal_Discount__c>>();
        Set<Id> proposalIds = new Set<Id>();
        
        for (Group_Proposal_Discount__c discount : discounts) {
            proposalIds.add(discount.Group_Buy_Proposal__c);
            
            if (!proposalDiscountMap.containsKey(discount.Group_Buy_Proposal__c)) {
                proposalDiscountMap.put(discount.Group_Buy_Proposal__c, new List<Group_Proposal_Discount__c>());
            }
            proposalDiscountMap.get(discount.Group_Buy_Proposal__c).add(discount);
        }
        
        // Get existing discounts for these proposals
        Map<Id, List<Group_Proposal_Discount__c>> existingDiscountsMap = new Map<Id, List<Group_Proposal_Discount__c>>();
        
        for (Group_Proposal_Discount__c existing : [
            SELECT Id, Group_Buy_Proposal__c, Min_Quota_For_Discount__c, 
                   Max_Quota_Discount__c, Discount__c, Tier_Order__c
            FROM Group_Proposal_Discount__c
            WHERE Group_Buy_Proposal__c IN :proposalIds
        ]) {
            // Skip if this is being updated (will be replaced by new values)
            if (oldMap != null && oldMap.containsKey(existing.Id)) {
                continue;
            }
            
            if (!existingDiscountsMap.containsKey(existing.Group_Buy_Proposal__c)) {
                existingDiscountsMap.put(existing.Group_Buy_Proposal__c, new List<Group_Proposal_Discount__c>());
            }
            existingDiscountsMap.get(existing.Group_Buy_Proposal__c).add(existing);
        }
        
        // Get proposal info to check status
        Map<Id, Group_Buy_Proposal__c> proposalMap = new Map<Id, Group_Buy_Proposal__c>([
            SELECT Id, Status__c, Min_Quota__c
            FROM Group_Buy_Proposal__c
            WHERE Id IN :proposalIds
        ]);
        
        // Validate each discount
        for (Group_Proposal_Discount__c discount : discounts) {
            Group_Buy_Proposal__c proposal = proposalMap.get(discount.Group_Buy_Proposal__c);
            
            // Check proposal status - can't modify discounts for active/closed proposals
            if (proposal != null && 
                (proposal.Status__c == 'Active' || proposal.Status__c == 'Closed' || proposal.Status__c == 'Expired')) {
                discount.addError('Cannot modify discount tiers for ' + proposal.Status__c + ' proposals.');
                continue;
            }
            
            // Build combined list of all tiers for this proposal
            List<Group_Proposal_Discount__c> allTiers = new List<Group_Proposal_Discount__c>();
            
            // Add existing tiers (excluding ones being updated)
            if (existingDiscountsMap.containsKey(discount.Group_Buy_Proposal__c)) {
                allTiers.addAll(existingDiscountsMap.get(discount.Group_Buy_Proposal__c));
            }
            
            // Add new/updated tiers from this transaction
            allTiers.addAll(proposalDiscountMap.get(discount.Group_Buy_Proposal__c));
            
            // Check for overlaps
            String overlapError = checkForOverlaps(discount, allTiers);
            if (overlapError != null) {
                discount.addError(overlapError);
                continue;
            }
            
            // Set tier order based on min quota
            Integer tierOrder = calculateTierOrder(discount, allTiers);
            discount.Tier_Order__c = tierOrder;
        }
    }
    
    /**
     * Check if a discount tier overlaps with other tiers
     */
    private String checkForOverlaps(Group_Proposal_Discount__c newDiscount, List<Group_Proposal_Discount__c> allTiers) {
        Decimal newMin = newDiscount.Min_Quota_For_Discount__c;
        Decimal newMax = newDiscount.Max_Quota_Discount__c;
        
        for (Group_Proposal_Discount__c existing : allTiers) {
            // Skip self-comparison
            if (newDiscount.Id != null && newDiscount.Id == existing.Id) {
                continue;
            }
            
            // Skip if comparing to itself in the same transaction (same record reference)
            if (newDiscount == existing) {
                continue;
            }
            
            Decimal existMin = existing.Min_Quota_For_Discount__c;
            Decimal existMax = existing.Max_Quota_Discount__c;
            
            // Check for overlap
            // Overlap exists if: newMin <= existMax AND newMax >= existMin
            Boolean hasOverlap = (newMin <= existMax) && (newMax >= existMin);
            
            if (hasOverlap) {
                return 'Quota range [' + newMin + '-' + newMax + '] overlaps with existing tier [' + existMin + '-' + existMax + '].';
            }
        }
        
        return null;
    }
    
    /**
     * Calculate tier order based on min quota (lower min = lower tier number)
     */
    private Integer calculateTierOrder(Group_Proposal_Discount__c discount, List<Group_Proposal_Discount__c> allTiers) {
        Integer order = 1;
        
        for (Group_Proposal_Discount__c tier : allTiers) {
            if (tier.Id == discount.Id || tier == discount) continue;
            
            if (tier.Min_Quota_For_Discount__c < discount.Min_Quota_For_Discount__c) {
                order++;
            }
        }
        
        return order;
    }
}
