/**
 * @description Controller for Group Buy Proposal display and Conditional Order management
 * Handles fetching proposal details, discount tiers, and creating conditional orders
 */
public with sharing class GroupProposalController {

    /**
     * @description Get Group Buy Proposal details with discount tiers
     * @param proposalId The Group_Buy_Proposal__c Id
     * @return ProposalDetails wrapper with all relevant information
     */
    @AuraEnabled
    public static ProposalDetails getProposalDetails(Id proposalId) {
        if (proposalId == null) {
            throw new AuraHandledException('Proposal ID is required');
        }

        ProposalDetails details = new ProposalDetails();

        // Get the proposal with related product info
        List<Group_Buy_Proposal__c> proposals = [
                SELECT Id, Name, Description__c, Status__c, Type__c,
                        Start_Date__c, End_Date__c, Approximate_Deliver_Start_Date__c,
                        Min_Quota__c, Max_Quota__c, Booked_Quota__c, Is_Quota_Exceeded__c,
                        Account__c, Account__r.Name,
                        Product__c, Product__r.Name, Product__r.ProductCode,
                        Product__r.Description
                FROM Group_Buy_Proposal__c
                WHERE Id = :proposalId
                LIMIT 1
        ];

        if (proposals.isEmpty()) {
            throw new AuraHandledException('Proposal not found');
        }

        Group_Buy_Proposal__c proposal = proposals[0];
        details.proposal = proposal;

        // Calculate derived fields
        details.availableQuota = (proposal.Max_Quota__c != null ? proposal.Max_Quota__c : 0) -
                (proposal.Booked_Quota__c != null ? proposal.Booked_Quota__c : 0);
        details.availableQuota = Math.max(0, details.availableQuota);

        if (proposal.Min_Quota__c != null && proposal.Min_Quota__c > 0) {
            details.progressPercentage = ((proposal.Booked_Quota__c != null ? proposal.Booked_Quota__c : 0) / proposal.Min_Quota__c) * 100;
            details.progressPercentage = Math.min(100, details.progressPercentage);
        } else {
            details.progressPercentage = 0;
        }

        details.isMinQuotaReached = proposal.Booked_Quota__c != null &&
                proposal.Min_Quota__c != null &&
                proposal.Booked_Quota__c >= proposal.Min_Quota__c;

        // Check if proposal is available for ordering
        details.isActive = proposal.Status__c == 'Active';
        details.isExpired = proposal.End_Date__c != null && proposal.End_Date__c < DateTime.now();
        details.hasAvailableQuota = details.availableQuota > 0 && !proposal.Is_Quota_Exceeded__c;
        details.canOrder = details.isActive && !details.isExpired && details.hasAvailableQuota;

        // Get discount tiers ordered by min quota
        details.discountTiers = [
                SELECT Id, Name, Min_Quota_For_Discount__c, Max_Quota_Discount__c,
                        Discount__c, Is_Main__c
                FROM Group_Proposal_Discount__c
                WHERE Group_Buy_Proposal__c = :proposalId
                ORDER BY Min_Quota_For_Discount__c ASC
        ];

        // Determine current active tier based on booked quota
        Decimal bookedQty = proposal.Booked_Quota__c != null ? proposal.Booked_Quota__c : 0;
        for (Group_Proposal_Discount__c tier : details.discountTiers) {
            Decimal minQty = tier.Min_Quota_For_Discount__c != null ? tier.Min_Quota_For_Discount__c : 0;
            Decimal maxQty = tier.Max_Quota_Discount__c != null ? tier.Max_Quota_Discount__c : 999999999;

            if (bookedQty >= minQty && bookedQty <= maxQty) {
                details.currentTierId = tier.Id;
                details.currentDiscount = tier.Discount__c;
                break;
            }
        }

        // Get product image if available
        details.productImageUrl = getProductImageUrl(proposal.Product__c);

        return details;
    }

    /**
     * @description Get all active proposals for a specific product
     * @param productId The Product2 Id
     * @return List of ProposalWithDiscounts containing proposal and discount tiers
     */
    @AuraEnabled
    public static List<ProposalWithDiscounts> getProposalsByProduct(Id productId) {
        if (productId == null) {
            return new List<ProposalWithDiscounts>();
        }

        List<ProposalWithDiscounts> results = new List<ProposalWithDiscounts>();

        // Get active proposals for this product
        List<Group_Buy_Proposal__c> proposals = [
                SELECT Id, Name, Description__c, Status__c, Type__c,
                        Start_Date__c, End_Date__c, Approximate_Deliver_Start_Date__c,
                        Min_Quota__c, Max_Quota__c, Booked_Quota__c, Is_Quota_Exceeded__c,
                        Account__c, Account__r.Name,
                        Product__c, Product__r.Name, Product__r.ProductCode
                FROM Group_Buy_Proposal__c
                WHERE Product__c = :productId
                AND Status__c = 'Active'
                AND Is_Quota_Exceeded__c = false
                AND (End_Date__c = null OR End_Date__c > :DateTime.now())
                ORDER BY End_Date__c ASC NULLS LAST
        ];

        // Get all proposal IDs for discount query
        Set<Id> proposalIds = new Set<Id>();
        for (Group_Buy_Proposal__c p : proposals) {
            proposalIds.add(p.Id);
        }

        // Get all discounts for these proposals
        Map<Id, List<Group_Proposal_Discount__c>> discountsByProposal = new Map<Id, List<Group_Proposal_Discount__c>>();
        if (!proposalIds.isEmpty()) {
            List<Group_Proposal_Discount__c> allDiscounts = [
                    SELECT Id, Name, Min_Quota_For_Discount__c, Max_Quota_Discount__c,
                            Discount__c, Is_Main__c, Group_Buy_Proposal__c
                    FROM Group_Proposal_Discount__c
                    WHERE Group_Buy_Proposal__c IN :proposalIds
                    ORDER BY Min_Quota_For_Discount__c ASC
            ];

            for (Group_Proposal_Discount__c d : allDiscounts) {
                if (!discountsByProposal.containsKey(d.Group_Buy_Proposal__c)) {
                    discountsByProposal.put(d.Group_Buy_Proposal__c, new List<Group_Proposal_Discount__c>());
                }
                discountsByProposal.get(d.Group_Buy_Proposal__c).add(d);
            }
        }

        // Build results
        for (Group_Buy_Proposal__c p : proposals) {
            ProposalWithDiscounts pwd = new ProposalWithDiscounts();
            pwd.proposal = p;
            pwd.discountTiers = discountsByProposal.containsKey(p.Id) ?
                    discountsByProposal.get(p.Id) :
                    new List<Group_Proposal_Discount__c>();

            // Calculate derived fields
            Decimal booked = p.Booked_Quota__c != null ? p.Booked_Quota__c : 0;
            Decimal maxQ = p.Max_Quota__c != null ? p.Max_Quota__c : 999999999;
            Decimal minQ = p.Min_Quota__c != null ? p.Min_Quota__c : 0;

            pwd.availableQuota = Math.max(0, maxQ - booked);
            pwd.progressPercentage = minQ > 0 ? Math.min(100, (booked / minQ) * 100) : 0;
            pwd.isMinQuotaReached = booked >= minQ;

            // Find current discount tier
            pwd.currentDiscount = 0;
            for (Group_Proposal_Discount__c tier : pwd.discountTiers) {
                Decimal tierMin = tier.Min_Quota_For_Discount__c != null ? tier.Min_Quota_For_Discount__c : 0;
                Decimal tierMax = tier.Max_Quota_Discount__c != null ? tier.Max_Quota_Discount__c : 999999999;
                if (booked >= tierMin && booked <= tierMax) {
                    pwd.currentDiscount = tier.Discount__c != null ? tier.Discount__c : 0;
                    pwd.currentTierId = tier.Id;
                    break;
                }
            }

            // Find max possible discount
            pwd.maxDiscount = 0;
            for (Group_Proposal_Discount__c tier : pwd.discountTiers) {
                if (tier.Discount__c != null && tier.Discount__c > pwd.maxDiscount) {
                    pwd.maxDiscount = tier.Discount__c;
                }
            }

            results.add(pwd);
        }

        return results;
    }

    /**
     * @description Check if account has existing orders for proposals on a product
     * @param productId The Product2 Id
     * @param accountId The Account Id
     * @return Map of proposalId to Conditional_Order__c
     */
    @AuraEnabled
    public static Map<Id, Conditional_Order__c> getExistingOrdersForProduct(Id productId, Id accountId) {
        Map<Id, Conditional_Order__c> result = new Map<Id, Conditional_Order__c>();

        List<Conditional_Order__c> orders;

        if (accountId != null) {
            // Production: query by account
            orders = [
                    SELECT Id, Group_Buy_Proposal__c, Quantity__c, Status__c
                    FROM Conditional_Order__c
                    WHERE Product__c = :productId
                    AND Account__c = :accountId
                    AND Status__c IN ('Pending', 'Confirmed')
            ];
        } else {
            // Preview mode: query by created user
            orders = [
                    SELECT Id, Group_Buy_Proposal__c, Quantity__c, Status__c
                    FROM Conditional_Order__c
                    WHERE Product__c = :productId
                    AND CreatedById = :UserInfo.getUserId()
                    AND Account__c = null
                    AND Status__c IN ('Pending', 'Confirmed')
            ];
        }

        for (Conditional_Order__c order : orders) {
            result.put(order.Group_Buy_Proposal__c, order);
        }

        return result;
    }

    /**
     * @description Get proposals available for an account in a webstore context
     * @param accountId The Account Id
     * @param productId Optional Product Id to filter
     * @return List of active proposals
     */
    @AuraEnabled
    public static List<ProposalSummary> getAvailableProposals(Id accountId, Id productId) {
        List<ProposalSummary> summaries = new List<ProposalSummary>();

        String query = 'SELECT Id, Name, Description__c, Status__c, ' +
                'Start_Date__c, End_Date__c, ' +
                'Min_Quota__c, Max_Quota__c, Booked_Quota__c, ' +
                'Product__c, Product__r.Name, Product__r.ProductCode ' +
                'FROM Group_Buy_Proposal__c ' +
                'WHERE Status__c = \'Active\' ' +
                'AND (End_Date__c = null OR End_Date__c > :now) ' +
                'AND Is_Quota_Exceeded__c = false';

        if (productId != null) {
            query += ' AND Product__c = :productId';
        }

        query += ' ORDER BY End_Date__c ASC NULLS LAST';

        DateTime now = DateTime.now();
        List<Group_Buy_Proposal__c> proposals = Database.query(query);

        for (Group_Buy_Proposal__c p : proposals) {
            ProposalSummary summary = new ProposalSummary();
            summary.proposalId = p.Id;
            summary.name = p.Name;
            summary.productName = p.Product__r?.Name;
            summary.productCode = p.Product__r?.ProductCode;
            summary.endDate = p.End_Date__c;
            summary.minQuota = p.Min_Quota__c;
            summary.maxQuota = p.Max_Quota__c;
            summary.bookedQuota = p.Booked_Quota__c != null ? p.Booked_Quota__c : 0;
            summary.availableQuota = (p.Max_Quota__c != null ? p.Max_Quota__c : 0) - summary.bookedQuota;
            summary.progressPercentage = p.Min_Quota__c != null && p.Min_Quota__c > 0 ?
                    Math.min(100, (summary.bookedQuota / p.Min_Quota__c) * 100) : 0;
            summary.productImageUrl = getProductImageUrl(p.Product__c);

            // Get best discount for this proposal
            List<Group_Proposal_Discount__c> discounts = [
                    SELECT Discount__c FROM Group_Proposal_Discount__c
                    WHERE Group_Buy_Proposal__c = :p.Id
                    ORDER BY Discount__c DESC
                    LIMIT 1
            ];
            summary.maxDiscount = !discounts.isEmpty() ? discounts[0].Discount__c : 0;

            summaries.add(summary);
        }

        return summaries;
    }

    /**
     * @description Check if account already has a conditional order for this proposal
     * @param proposalId The Group_Buy_Proposal__c Id
     * @param accountId The Account Id
     * @return Existing conditional order if found
     */
    @AuraEnabled
    public static Conditional_Order__c getExistingOrder(Id proposalId, Id accountId) {
        if (proposalId == null || accountId == null) {
            return null;
        }

        List<Conditional_Order__c> existingOrders = [
                SELECT Id, Name, Quantity__c, Subscription_Last_Date__c,
                        Product__c, Product__r.Name
                FROM Conditional_Order__c
                WHERE Group_Buy_Proposal__c = :proposalId
                AND Account__c = :accountId
                LIMIT 1
        ];

        return existingOrders.isEmpty() ? null : existingOrders[0];
    }

    /**
     * @description Create a conditional order to join the group buy
     * @param proposalId The Group_Buy_Proposal__c Id
     * @param accountId The Account Id
     * @param quantity The quantity to order
     * @return The created Conditional_Order__c
     */
    @AuraEnabled
    public static ConditionalOrderResult createConditionalOrder(
            Id proposalId,
            Id accountId,
            Decimal quantity
    ) {
        ConditionalOrderResult result = new ConditionalOrderResult();

        // Validate inputs
        if (proposalId == null) {
            throw new AuraHandledException('Proposal ID is required');
        }
        if (quantity == null || quantity <= 0) {
            throw new AuraHandledException('Quantity must be greater than zero');
        }

        // Get proposal details
        List<Group_Buy_Proposal__c> proposals = [
                SELECT Id, Name, Status__c, End_Date__c, Product__c,
                        Max_Quota__c, Booked_Quota__c, Is_Quota_Exceeded__c
                FROM Group_Buy_Proposal__c
                WHERE Id = :proposalId
                LIMIT 1
        ];

        if (proposals.isEmpty()) {
            throw new AuraHandledException('Proposal not found');
        }

        Group_Buy_Proposal__c proposal = proposals[0];

        // Validate proposal is active
        if (proposal.Status__c != 'Active') {
            throw new AuraHandledException('This proposal is not currently active');
        }

        // Check if expired
        if (proposal.End_Date__c != null && proposal.End_Date__c < DateTime.now()) {
            throw new AuraHandledException('This proposal has expired');
        }

        // Check quota availability
        Decimal bookedQty = proposal.Booked_Quota__c != null ? proposal.Booked_Quota__c : 0;
        Decimal maxQty = proposal.Max_Quota__c != null ? proposal.Max_Quota__c : 999999999;
        Decimal availableQty = maxQty - bookedQty;
        Decimal unitPrice = proposal.Base_Price__c;

        if (proposal.Is_Quota_Exceeded__c || availableQty <= 0) {
            throw new AuraHandledException('This proposal has reached its maximum quota');
        }

        if (quantity > availableQty) {
            throw new AuraHandledException('Requested quantity (' + quantity + ') exceeds available quota (' + availableQty + ')');
        }

        // Check for existing order from this account
        List<Conditional_Order__c> existingOrders = [
                SELECT Id, Quantity__c
                FROM Conditional_Order__c
                WHERE Group_Buy_Proposal__c = :proposalId
                AND Account__c = :accountId
                LIMIT 1
        ];

        if (!existingOrders.isEmpty()) {
            throw new AuraHandledException('You already have a conditional order for this proposal. Please modify your existing order instead.');
        }

        // Create the conditional order
        try {
            Conditional_Order__c order = new Conditional_Order__c();
            order.Group_Buy_Proposal__c = proposalId;
            order.Account__c = accountId;
            order.Product__c = proposal.Product__c;
            order.Quantity__c = quantity;
            order.Subscription_Last_Date__c = proposal.End_Date__c;
            order.Unit_Price__c = unitPrice;


            insert order;

            // Re-query to get auto-number name
            order = [
                    SELECT Id, Name, Quantity__c, Subscription_Last_Date__c,
                            Product__c, Product__r.Name,
                            Group_Buy_Proposal__c, Group_Buy_Proposal__r.Name,
                            Account__c, Account__r.Name
                    FROM Conditional_Order__c
                    WHERE Id = :order.Id
                    LIMIT 1
            ];

            result.success = true;
            result.order = order;
            result.message = 'Successfully joined the group buy! Your order number is ' + order.Name;

        } catch (DmlException e) {
            throw new AuraHandledException('Failed to create order: ' + e.getMessage());
        }

        return result;
    }

    /**
     * @description Update quantity on existing conditional order
     * @param orderId The Conditional_Order__c Id
     * @param newQuantity The new quantity
     * @return Updated order
     */
    @AuraEnabled
    public static ConditionalOrderResult updateConditionalOrder(Id orderId, Decimal newQuantity) {
        ConditionalOrderResult result = new ConditionalOrderResult();

        if (orderId == null) {
            throw new AuraHandledException('Order ID is required');
        }
        if (newQuantity == null || newQuantity <= 0) {
            throw new AuraHandledException('Quantity must be greater than zero');
        }

        // Get existing order with proposal details
        List<Conditional_Order__c> orders = [
                SELECT Id, Name, Quantity__c, Account__c,
                        Group_Buy_Proposal__c, Group_Buy_Proposal__r.Max_Quota__c,
                        Group_Buy_Proposal__r.Booked_Quota__c, Group_Buy_Proposal__r.Status__c
                FROM Conditional_Order__c
                WHERE Id = :orderId
                LIMIT 1
        ];

        if (orders.isEmpty()) {
            throw new AuraHandledException('Order not found');
        }

        Conditional_Order__c order = orders[0];

        // Check proposal is still active
        if (order.Group_Buy_Proposal__r.Status__c != 'Active') {
            throw new AuraHandledException('The proposal is no longer active');
        }

        // Calculate available quota (current booked - this order's qty + new qty)
        Decimal currentBooked = order.Group_Buy_Proposal__r.Booked_Quota__c != null ?
                order.Group_Buy_Proposal__r.Booked_Quota__c : 0;
        Decimal maxQuota = order.Group_Buy_Proposal__r.Max_Quota__c != null ?
                order.Group_Buy_Proposal__r.Max_Quota__c : 999999999;
        Decimal currentOrderQty = order.Quantity__c != null ? order.Quantity__c : 0;
        Decimal otherOrdersQty = currentBooked - currentOrderQty;
        Decimal availableForThis = maxQuota - otherOrdersQty;

        if (newQuantity > availableForThis) {
            throw new AuraHandledException('Requested quantity exceeds available quota. Maximum available: ' + availableForThis);
        }

        try {
            order.Quantity__c = newQuantity;
            update order;

            result.success = true;
            result.order = order;
            result.message = 'Order quantity updated successfully';

        } catch (DmlException e) {
            throw new AuraHandledException('Failed to update order: ' + e.getMessage());
        }

        return result;
    }

    /**
     * @description Cancel/delete a conditional order
     * @param orderId The Conditional_Order__c Id
     * @return Success result
     */
    @AuraEnabled
    public static ConditionalOrderResult cancelConditionalOrder(Id orderId) {
        ConditionalOrderResult result = new ConditionalOrderResult();

        if (orderId == null) {
            throw new AuraHandledException('Order ID is required');
        }

        List<Conditional_Order__c> orders = [
                SELECT Id, Name, Group_Buy_Proposal__r.Status__c
                FROM Conditional_Order__c
                WHERE Id = :orderId
                LIMIT 1
        ];

        if (orders.isEmpty()) {
            throw new AuraHandledException('Order not found');
        }

        try {
            delete orders[0];

            result.success = true;
            result.message = 'Your conditional order has been cancelled';

        } catch (DmlException e) {
            throw new AuraHandledException('Failed to cancel order: ' + e.getMessage());
        }

        return result;
    }

    /**
     * @description Get product image URL from ProductMedia
     */
    private static String getProductImageUrl(Id productId) {
        if (productId == null) {
            return null;
        }

        // Try to get from ProductMedia first
        List<ProductMedia> mediaList = [
                SELECT ElectronicMediaId
                FROM ProductMedia
                WHERE ProductId = :productId
                ORDER BY SortOrder ASC NULLS LAST
                LIMIT 1
        ];

        if (!mediaList.isEmpty() && mediaList[0].ElectronicMediaId != null) {
            return '/cms/media/' + mediaList[0].ElectronicMediaId;
        }

        return null;
    }

    // ================================
    // WRAPPER CLASSES
    // ================================

    public class ProposalDetails {
        @AuraEnabled public Group_Buy_Proposal__c proposal { get; set; }
        @AuraEnabled public List<Group_Proposal_Discount__c> discountTiers { get; set; }
        @AuraEnabled public Decimal availableQuota { get; set; }
        @AuraEnabled public Decimal progressPercentage { get; set; }
        @AuraEnabled public Boolean isMinQuotaReached { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }
        @AuraEnabled public Boolean isExpired { get; set; }
        @AuraEnabled public Boolean hasAvailableQuota { get; set; }
        @AuraEnabled public Boolean canOrder { get; set; }
        @AuraEnabled public Id currentTierId { get; set; }
        @AuraEnabled public Decimal currentDiscount { get; set; }
        @AuraEnabled public String productImageUrl { get; set; }
    }

    public class ProposalSummary {
        @AuraEnabled public Id proposalId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public String productCode { get; set; }
        @AuraEnabled public DateTime endDate { get; set; }
        @AuraEnabled public Decimal minQuota { get; set; }
        @AuraEnabled public Decimal maxQuota { get; set; }
        @AuraEnabled public Decimal bookedQuota { get; set; }
        @AuraEnabled public Decimal availableQuota { get; set; }
        @AuraEnabled public Decimal progressPercentage { get; set; }
        @AuraEnabled public Decimal maxDiscount { get; set; }
        @AuraEnabled public String productImageUrl { get; set; }
    }

    public class ProposalWithDiscounts {
        @AuraEnabled public Group_Buy_Proposal__c proposal { get; set; }
        @AuraEnabled public List<Group_Proposal_Discount__c> discountTiers { get; set; }
        @AuraEnabled public Decimal availableQuota { get; set; }
        @AuraEnabled public Decimal progressPercentage { get; set; }
        @AuraEnabled public Boolean isMinQuotaReached { get; set; }
        @AuraEnabled public Decimal currentDiscount { get; set; }
        @AuraEnabled public Decimal maxDiscount { get; set; }
        @AuraEnabled public Id currentTierId { get; set; }
    }

    public class ConditionalOrderResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Conditional_Order__c order { get; set; }

        public ConditionalOrderResult() {
            this.success = false;
        }
    }
}