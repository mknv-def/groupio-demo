/**
 * ConditionalOrderController
 * Controller for managing customer conditional orders in group buy proposals
 */
public with sharing class ConditionalOrderController {

    /**
     * Wrapper class for grouped order data
     */
    public class OrderGroup {
        @AuraEnabled public Group_Buy_Proposal__c proposal { get; set; }
        @AuraEnabled public List<Conditional_Order__c> orders { get; set; }
        @AuraEnabled public List<Group_Proposal_Discount__c> discounts { get; set; }

        public OrderGroup() {
            this.orders = new List<Conditional_Order__c>();
            this.discounts = new List<Group_Proposal_Discount__c>();
        }
    }

    /**
     * Get all orders for an account, grouped by proposal
     */
    @AuraEnabled(cacheable=true)
    public static List<OrderGroup> getOrdersGroupedByProposal(Id accountId) {
        // Build query filter
        String whereClause;
        if (accountId != null) {
            whereClause = 'Account__c = :accountId';
        } else {
            // Preview mode - get orders created by current user
            whereClause = 'CreatedById = :userId';
        }

        Id userId = UserInfo.getUserId();

        // Get all conditional orders for this account
        List<Conditional_Order__c> orders = Database.query(
                'SELECT Id, Name, Status__c, Quantity__c, Group_Buy_Proposal__c, ' +
                        '       Account__c, CreatedDate, LastModifiedDate ' +
                        'FROM Conditional_Order__c ' +
                        'WHERE ' + whereClause + ' ' +
                        'ORDER BY CreatedDate DESC'
        );

        if (orders.isEmpty()) {
            return new List<OrderGroup>();
        }

        // Collect proposal IDs
        Set<Id> proposalIds = new Set<Id>();
        for (Conditional_Order__c order : orders) {
            if (order.Group_Buy_Proposal__c != null) {
                proposalIds.add(order.Group_Buy_Proposal__c);
            }
        }

        // Get proposals with related data
        Map<Id, Group_Buy_Proposal__c> proposalMap = new Map<Id, Group_Buy_Proposal__c>([
                SELECT Id, Name, Status__c, Type__c, Base_Price__c,
                        Min_Quota__c, Max_Quota__c, Booked_Quota__c,
                        Available_Quota__c, Progress_Percentage__c,
                        Start_Date__c, End_Date__c, Approximate_Deliver_Start_Date__c,
                        Description__c, Is_Min_Quota_Reached__c,
                        Product__c, Product__r.Name, Product__r.ProductCode,
                        Account__c, Account__r.Name
                FROM Group_Buy_Proposal__c
                WHERE Id IN :proposalIds
        ]);

        // Get discounts for all proposals
        List<Group_Proposal_Discount__c> allDiscounts = [
                SELECT Id, Group_Buy_Proposal__c, Min_Quota_For_Discount__c,
                        Max_Quota_Discount__c, Discount__c
                FROM Group_Proposal_Discount__c
                WHERE Group_Buy_Proposal__c IN :proposalIds
                ORDER BY Min_Quota_For_Discount__c ASC
        ];

        // Group discounts by proposal
        Map<Id, List<Group_Proposal_Discount__c>> discountMap = new Map<Id, List<Group_Proposal_Discount__c>>();
        for (Group_Proposal_Discount__c discount : allDiscounts) {
            if (!discountMap.containsKey(discount.Group_Buy_Proposal__c)) {
                discountMap.put(discount.Group_Buy_Proposal__c, new List<Group_Proposal_Discount__c>());
            }
            discountMap.get(discount.Group_Buy_Proposal__c).add(discount);
        }

        // Group orders by proposal
        Map<Id, OrderGroup> groupMap = new Map<Id, OrderGroup>();
        for (Conditional_Order__c order : orders) {
            Id propId = order.Group_Buy_Proposal__c;
            if (propId == null) continue;

            if (!groupMap.containsKey(propId)) {
                OrderGroup og = new OrderGroup();
                og.proposal = proposalMap.get(propId);
                og.discounts = discountMap.containsKey(propId) ? discountMap.get(propId) : new List<Group_Proposal_Discount__c>();
                groupMap.put(propId, og);
            }
            groupMap.get(propId).orders.add(order);
        }

        return groupMap.values();
    }

    /**
     * Update the quantity of an existing order
     */
    @AuraEnabled
    public static Conditional_Order__c updateOrderQuantity(Id orderId, Integer newQuantity) {
        if (orderId == null) {
            throw new AuraHandledException('Order ID is required');
        }

        if (newQuantity == null || newQuantity < 1) {
            throw new AuraHandledException('Quantity must be at least 1');
        }

        // Get the order
        List<Conditional_Order__c> orders = [
                SELECT Id, Status__c, Quantity__c, Group_Buy_Proposal__c,
                        Group_Buy_Proposal__r.Max_Quota__c,
                        Group_Buy_Proposal__r.Available_Quota__c
                FROM Conditional_Order__c
                WHERE Id = :orderId
                LIMIT 1
        ];

        if (orders.isEmpty()) {
            throw new AuraHandledException('Order not found');
        }

        Conditional_Order__c order = orders[0];

        // Check if order can be edited
        if (order.Status__c == 'Confirmed') {
            throw new AuraHandledException('Cannot edit a confirmed order');
        }

        if (order.Status__c == 'Cancelled') {
            throw new AuraHandledException('Cannot edit a cancelled order');
        }

        // Calculate available quota considering current order quantity
        Decimal currentQty = order.Quantity__c != null ? order.Quantity__c : 0;
        Decimal availableQuota = order.Group_Buy_Proposal__r.Available_Quota__c != null
                ? order.Group_Buy_Proposal__r.Available_Quota__c : 0;
        Decimal maxAvailable = availableQuota + currentQty;

        if (newQuantity > maxAvailable) {
            throw new AuraHandledException('Quantity exceeds available quota. Maximum available: ' + maxAvailable.intValue());
        }

        // Update the order
        order.Quantity__c = newQuantity;
        update order;

        return order;
    }

    /**
     * Cancel an order
     */
    @AuraEnabled
    public static void cancelOrder(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('Order ID is required');
        }

        // Get the order
        List<Conditional_Order__c> orders = [
                SELECT Id, Status__c
                FROM Conditional_Order__c
                WHERE Id = :orderId
                LIMIT 1
        ];

        if (orders.isEmpty()) {
            throw new AuraHandledException('Order not found');
        }

        Conditional_Order__c order = orders[0];

        // Check if order can be cancelled
        if (order.Status__c == 'Confirmed') {
            throw new AuraHandledException('Cannot cancel a confirmed order');
        }

        if (order.Status__c == 'Cancelled') {
            throw new AuraHandledException('Order is already cancelled');
        }

        // Cancel the order
        order.Status__c = 'Cancelled';
        update order;
    }

    /**
     * Get a single order by ID
     */
    @AuraEnabled(cacheable=true)
    public static Conditional_Order__c getOrderById(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('Order ID is required');
        }

        List<Conditional_Order__c> orders = [
                SELECT Id, Name, Status__c, Quantity__c,
                        Group_Buy_Proposal__c, Group_Buy_Proposal__r.Name,
                        Group_Buy_Proposal__r.Base_Price__c,
                        Group_Buy_Proposal__r.Product__r.Name,
                        Account__c, Account__r.Name,
                        CreatedDate, LastModifiedDate
                FROM Conditional_Order__c
                WHERE Id = :orderId
                LIMIT 1
        ];

        if (orders.isEmpty()) {
            throw new AuraHandledException('Order not found');
        }

        return orders[0];
    }
}
