/**
 * ConditionalOrderTriggerHandler
 * Business logic for Conditional Order trigger
 * 
 * Key Functions:
 * 1. Validate order quantity against available quota
 * 2. Update Booked_Quota__c on proposals (if not using rollup summary)
 * 3. Capture unit price at order time
 * 4. Handle order cancellation logic
 */
public class ConditionalOrderTriggerHandler {
    
    /**
     * Before Insert
     * - Validate proposal is active
     * - Validate quantity within available quota
     * - Capture current unit price
     */
    public void beforeInsert(List<Conditional_Order__c> newOrders) {
        Set<Id> proposalIds = new Set<Id>();
        for (Conditional_Order__c order : newOrders) {
            if (order.Group_Buy_Proposal__c != null) {
                proposalIds.add(order.Group_Buy_Proposal__c);
            }
        }
        
        if (proposalIds.isEmpty()) return;
        
        // Get proposals with current quota info
        Map<Id, Group_Buy_Proposal__c> proposalMap = new Map<Id, Group_Buy_Proposal__c>([
            SELECT Id, Status__c, Base_Price__c, Max_Quota__c, 
                   Booked_Quota__c, Available_Quota__c
            FROM Group_Buy_Proposal__c
            WHERE Id IN :proposalIds
        ]);
        
        // Track quota changes in this transaction
        Map<Id, Decimal> proposalQtyChanges = new Map<Id, Decimal>();
        
        for (Conditional_Order__c order : newOrders) {
            Group_Buy_Proposal__c proposal = proposalMap.get(order.Group_Buy_Proposal__c);
            
            if (proposal == null) {
                order.addError('Invalid proposal reference.');
                continue;
            }
            
            // Validate proposal is active
            if (proposal.Status__c != 'Active') {
                order.addError('Orders can only be placed for Active proposals. Current status: ' + proposal.Status__c);
                continue;
            }
            
            // Calculate available quota considering other orders in this transaction
            Decimal previousChanges = proposalQtyChanges.get(proposal.Id);
            if (previousChanges == null) previousChanges = 0;
            
            Decimal effectiveAvailable = (proposal.Available_Quota__c != null ? proposal.Available_Quota__c : 0) - previousChanges;
            
            if (order.Quantity__c > effectiveAvailable) {
                order.addError('Order quantity (' + order.Quantity__c + ') exceeds available quota (' + effectiveAvailable + ').');
                continue;
            }
            
            // Track this order's quantity for subsequent orders in same transaction
            proposalQtyChanges.put(proposal.Id, previousChanges + order.Quantity__c);
            
            // Set default status if not provided
            if (String.isBlank(order.Status__c)) {
                order.Status__c = 'Pending';
            }
            
            // Capture unit price at order time
            order.Unit_Price_At_Order__c = proposal.Base_Price__c;
        }
    }
    
    /**
     * Before Update
     * - Validate quantity changes
     * - Prevent edits to confirmed/cancelled orders
     * - Set cancellation timestamp
     */
    public void beforeUpdate(List<Conditional_Order__c> newOrders, Map<Id, Conditional_Order__c> oldMap) {
        Set<Id> proposalIds = new Set<Id>();
        for (Conditional_Order__c order : newOrders) {
            if (order.Group_Buy_Proposal__c != null) {
                proposalIds.add(order.Group_Buy_Proposal__c);
            }
        }
        
        Map<Id, Group_Buy_Proposal__c> proposalMap = new Map<Id, Group_Buy_Proposal__c>([
            SELECT Id, Status__c, Available_Quota__c
            FROM Group_Buy_Proposal__c
            WHERE Id IN :proposalIds
        ]);
        
        for (Conditional_Order__c newOrder : newOrders) {
            Conditional_Order__c oldOrder = oldMap.get(newOrder.Id);
            
            // Track status changes
            Boolean statusChanged = newOrder.Status__c != oldOrder.Status__c;
            Boolean quantityChanged = newOrder.Quantity__c != oldOrder.Quantity__c;
            
            // Set timestamp when cancelled
            if (statusChanged && newOrder.Status__c == 'Cancelled') {
                newOrder.Cancelled_Date__c = DateTime.now();
            }
            
            // Set timestamp when confirmed
            if (statusChanged && newOrder.Status__c == 'Confirmed') {
                newOrder.Confirmed_Date__c = DateTime.now();
                // Lock in final price (would need discount calculation)
                newOrder.Final_Unit_Price__c = newOrder.Unit_Price_At_Order__c;
                newOrder.Final_Total__c = newOrder.Final_Unit_Price__c * newOrder.Quantity__c;
            }
            
            // Validate quantity increase against available quota
            if (quantityChanged && newOrder.Quantity__c > oldOrder.Quantity__c) {
                Group_Buy_Proposal__c proposal = proposalMap.get(newOrder.Group_Buy_Proposal__c);
                if (proposal != null) {
                    Decimal quantityIncrease = newOrder.Quantity__c - oldOrder.Quantity__c;
                    Decimal available = proposal.Available_Quota__c != null ? proposal.Available_Quota__c : 0;
                    
                    if (quantityIncrease > available) {
                        newOrder.addError('Cannot increase quantity. Only ' + available + ' additional units available.');
                    }
                }
            }
        }
    }
    
    /**
     * Before Delete
     * - Prevent deletion of confirmed orders
     */
    public void beforeDelete(List<Conditional_Order__c> oldOrders) {
        for (Conditional_Order__c order : oldOrders) {
            if (order.Status__c == 'Confirmed') {
                order.addError('Confirmed orders cannot be deleted.');
            }
        }
    }
    
    /**
     * After Insert
     * - Update proposal booked quota (if not using rollup)
     */
    public void afterInsert(List<Conditional_Order__c> newOrders) {
        updateProposalBookedQuota(newOrders, null);
    }
    
    /**
     * After Update
     * - Update proposal booked quota when quantity or status changes
     */
    public void afterUpdate(List<Conditional_Order__c> newOrders, Map<Id, Conditional_Order__c> oldMap) {
        List<Conditional_Order__c> relevantOrders = new List<Conditional_Order__c>();
        
        for (Conditional_Order__c newOrder : newOrders) {
            Conditional_Order__c oldOrder = oldMap.get(newOrder.Id);
            
            // Check if quantity or status changed
            if (newOrder.Quantity__c != oldOrder.Quantity__c || 
                newOrder.Status__c != oldOrder.Status__c) {
                relevantOrders.add(newOrder);
            }
        }
        
        if (!relevantOrders.isEmpty()) {
            updateProposalBookedQuota(relevantOrders, oldMap);
        }
    }
    
    /**
     * After Delete
     * - Update proposal booked quota
     */
    public void afterDelete(List<Conditional_Order__c> oldOrders) {
        updateProposalBookedQuota(oldOrders, null);
    }
    
    /**
     * Update Booked_Quota__c on proposals
     * Note: If using Rollup Summary field, this is not needed
     * This is useful if Conditional_Order__c uses Lookup instead of Master-Detail
     */
    private void updateProposalBookedQuota(List<Conditional_Order__c> orders, Map<Id, Conditional_Order__c> oldMap) {
        Set<Id> proposalIds = new Set<Id>();
        
        for (Conditional_Order__c order : orders) {
            if (order.Group_Buy_Proposal__c != null) {
                proposalIds.add(order.Group_Buy_Proposal__c);
            }
            // Also include old proposal if it changed
            if (oldMap != null && oldMap.containsKey(order.Id)) {
                Conditional_Order__c oldOrder = oldMap.get(order.Id);
                if (oldOrder.Group_Buy_Proposal__c != null) {
                    proposalIds.add(oldOrder.Group_Buy_Proposal__c);
                }
            }
        }
        
        if (proposalIds.isEmpty()) return;
        
        // Calculate booked quota for each proposal
        // Only count non-cancelled orders
        Map<Id, Decimal> proposalQuotas = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Group_Buy_Proposal__c, SUM(Quantity__c) totalQty
            FROM Conditional_Order__c
            WHERE Group_Buy_Proposal__c IN :proposalIds
            AND Status__c != 'Cancelled'
            GROUP BY Group_Buy_Proposal__c
        ]) {
            proposalQuotas.put((Id)ar.get('Group_Buy_Proposal__c'), (Decimal)ar.get('totalQty'));
        }
        
        // Update proposals
        List<Group_Buy_Proposal__c> proposalsToUpdate = new List<Group_Buy_Proposal__c>();
        for (Id proposalId : proposalIds) {
            Decimal bookedQty = proposalQuotas.get(proposalId);
            if (bookedQty == null) bookedQty = 0;
            
            proposalsToUpdate.add(new Group_Buy_Proposal__c(
                Id = proposalId,
                Booked_Quota__c = bookedQty
            ));
        }
        
        if (!proposalsToUpdate.isEmpty()) {
            update proposalsToUpdate;
        }
    }
}
