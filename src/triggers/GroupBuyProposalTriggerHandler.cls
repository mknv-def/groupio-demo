/**
 * GroupBuyProposalTriggerHandler
 * Business logic for Group Buy Proposal trigger
 * 
 * Key Functions:
 * 1. Track status change timestamps
 * 2. Validate status transitions
 * 3. Calculate current discount based on booked quota
 * 4. Handle cascade effects (e.g., expire orders when proposal expires)
 */
public class GroupBuyProposalTriggerHandler {
    
    /**
     * Before Insert
     * - Set default values
     * - Initialize tracking fields
     */
    public void beforeInsert(List<Group_Buy_Proposal__c> newProposals) {
        for (Group_Buy_Proposal__c proposal : newProposals) {
            // Set default status if not provided
            if (String.isBlank(proposal.Status__c)) {
                proposal.Status__c = 'Created';
            }
            
            // Initialize booked quota
            if (proposal.Booked_Quota__c == null) {
                proposal.Booked_Quota__c = 0;
            }
        }
    }
    
    /**
     * Before Update
     * - Track status change timestamps
     * - Validate status transitions
     * - Update current discount percentage
     */
    public void beforeUpdate(List<Group_Buy_Proposal__c> newProposals, Map<Id, Group_Buy_Proposal__c> oldMap) {
        Set<Id> proposalIds = new Set<Id>();
        for (Group_Buy_Proposal__c proposal : newProposals) {
            proposalIds.add(proposal.Id);
        }
        
        // Get discount tiers for all proposals
        Map<Id, List<Group_Proposal_Discount__c>> discountMap = getDiscountTiers(proposalIds);
        
        for (Group_Buy_Proposal__c newProposal : newProposals) {
            Group_Buy_Proposal__c oldProposal = oldMap.get(newProposal.Id);
            
            Boolean statusChanged = newProposal.Status__c != oldProposal.Status__c;
            
            // Track status change timestamps
            if (statusChanged) {
                trackStatusChange(newProposal, oldProposal);
            }
            
            // Calculate current discount based on booked quota
            if (newProposal.Booked_Quota__c != oldProposal.Booked_Quota__c || statusChanged) {
                updateCurrentDiscount(newProposal, discountMap.get(newProposal.Id));
            }
        }
    }
    
    /**
     * After Insert
     * - Publish events if needed
     */
    public void afterInsert(List<Group_Buy_Proposal__c> newProposals) {
        // Could publish creation events here
    }
    
    /**
     * After Update
     * - Handle status change side effects
     * - Cancel orders when proposal expires/cancelled
     */
    public void afterUpdate(List<Group_Buy_Proposal__c> newProposals, Map<Id, Group_Buy_Proposal__c> oldMap) {
        List<Group_Buy_Proposal__c> expiredProposals = new List<Group_Buy_Proposal__c>();
        List<Group_Buy_Proposal__c> cancelledProposals = new List<Group_Buy_Proposal__c>();
        List<Group_Buy_Proposal__c> closedProposals = new List<Group_Buy_Proposal__c>();
        
        for (Group_Buy_Proposal__c newProposal : newProposals) {
            Group_Buy_Proposal__c oldProposal = oldMap.get(newProposal.Id);
            
            if (newProposal.Status__c != oldProposal.Status__c) {
                if (newProposal.Status__c == 'Expired') {
                    expiredProposals.add(newProposal);
                } else if (newProposal.Status__c == 'Cancelled') {
                    cancelledProposals.add(newProposal);
                } else if (newProposal.Status__c == 'Closed') {
                    closedProposals.add(newProposal);
                }
            }
        }
        
        // Cancel orders for expired proposals
        if (!expiredProposals.isEmpty()) {
            cancelOrdersForProposals(expiredProposals, 'Proposal expired without reaching minimum quota.');
        }
        
        // Cancel orders for cancelled proposals
        if (!cancelledProposals.isEmpty()) {
            cancelOrdersForProposals(cancelledProposals, 'Proposal was cancelled.');
        }
        
        // Confirm orders for closed (successful) proposals
        // Note: This is also done in the batch job, but trigger handles manual closes
        if (!closedProposals.isEmpty()) {
            confirmOrdersForProposals(closedProposals);
        }
    }
    
    /**
     * Track status change timestamps
     */
    private void trackStatusChange(Group_Buy_Proposal__c newProposal, Group_Buy_Proposal__c oldProposal) {
        DateTime now = DateTime.now();
        
        switch on newProposal.Status__c {
            when 'Approved' {
                newProposal.Approved_Date__c = Date.today();
            }
            when 'Active' {
                newProposal.Activated_Date__c = now;
            }
            when 'Closed', 'Expired', 'Cancelled' {
                newProposal.Closed_Date__c = now;
            }
        }
    }
    
    /**
     * Get discount tiers for proposals
     */
    private Map<Id, List<Group_Proposal_Discount__c>> getDiscountTiers(Set<Id> proposalIds) {
        Map<Id, List<Group_Proposal_Discount__c>> result = new Map<Id, List<Group_Proposal_Discount__c>>();
        
        for (Group_Proposal_Discount__c discount : [
            SELECT Id, Group_Buy_Proposal__c, Min_Quota_For_Discount__c, 
                   Max_Quota_Discount__c, Discount__c
            FROM Group_Proposal_Discount__c
            WHERE Group_Buy_Proposal__c IN :proposalIds
            ORDER BY Min_Quota_For_Discount__c ASC
        ]) {
            if (!result.containsKey(discount.Group_Buy_Proposal__c)) {
                result.put(discount.Group_Buy_Proposal__c, new List<Group_Proposal_Discount__c>());
            }
            result.get(discount.Group_Buy_Proposal__c).add(discount);
        }
        
        return result;
    }
    
    /**
     * Calculate and set current discount percentage based on booked quota
     */
    private void updateCurrentDiscount(Group_Buy_Proposal__c proposal, List<Group_Proposal_Discount__c> discounts) {
        if (discounts == null || discounts.isEmpty()) {
            proposal.Current_Discount_Percent__c = 0;
            return;
        }
        
        Decimal bookedQuota = proposal.Booked_Quota__c != null ? proposal.Booked_Quota__c : 0;
        Decimal currentDiscount = 0;
        
        // Find the highest applicable discount tier
        for (Group_Proposal_Discount__c tier : discounts) {
            if (bookedQuota >= tier.Min_Quota_For_Discount__c) {
                currentDiscount = tier.Discount__c;
            }
        }
        
        proposal.Current_Discount_Percent__c = currentDiscount;
    }
    
    /**
     * Cancel all pending orders for given proposals
     */
    private void cancelOrdersForProposals(List<Group_Buy_Proposal__c> proposals, String reason) {
        Set<Id> proposalIds = new Set<Id>();
        for (Group_Buy_Proposal__c p : proposals) {
            proposalIds.add(p.Id);
        }
        
        List<Conditional_Order__c> ordersToCancel = [
            SELECT Id, Status__c, Cancellation_Reason__c
            FROM Conditional_Order__c
            WHERE Group_Buy_Proposal__c IN :proposalIds
            AND Status__c = 'Pending'
        ];
        
        if (!ordersToCancel.isEmpty()) {
            for (Conditional_Order__c order : ordersToCancel) {
                order.Status__c = 'Cancelled';
                order.Cancellation_Reason__c = reason;
                order.Cancelled_Date__c = DateTime.now();
            }
            update ordersToCancel;
        }
    }
    
    /**
     * Confirm all pending orders for successfully closed proposals
     */
    private void confirmOrdersForProposals(List<Group_Buy_Proposal__c> proposals) {
        Set<Id> proposalIds = new Set<Id>();
        Map<Id, Group_Buy_Proposal__c> proposalMap = new Map<Id, Group_Buy_Proposal__c>();
        
        for (Group_Buy_Proposal__c p : proposals) {
            proposalIds.add(p.Id);
            proposalMap.put(p.Id, p);
        }
        
        List<Conditional_Order__c> ordersToConfirm = [
            SELECT Id, Status__c, Quantity__c, Group_Buy_Proposal__c,
                   Unit_Price_At_Order__c
            FROM Conditional_Order__c
            WHERE Group_Buy_Proposal__c IN :proposalIds
            AND Status__c = 'Pending'
        ];
        
        if (!ordersToConfirm.isEmpty()) {
            DateTime now = DateTime.now();
            
            for (Conditional_Order__c order : ordersToConfirm) {
                order.Status__c = 'Confirmed';
                order.Confirmed_Date__c = now;
                
                // Calculate final price with discount
                Group_Buy_Proposal__c proposal = proposalMap.get(order.Group_Buy_Proposal__c);
                Decimal discount = proposal.Current_Discount_Percent__c != null ? proposal.Current_Discount_Percent__c : 0;
                Decimal unitPrice = order.Unit_Price_At_Order__c != null ? order.Unit_Price_At_Order__c : proposal.Base_Price__c;
                
                order.Final_Unit_Price__c = unitPrice * (1 - discount);
                order.Final_Total__c = order.Final_Unit_Price__c * order.Quantity__c;
            }
            update ordersToConfirm;
        }
    }
}
