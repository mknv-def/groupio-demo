/**
 * @description Test class for GroupProposalController
 * Tests proposal retrieval, conditional order creation, and order management
 */
@isTest
private class GroupProposalControllerTest {

    /**
     * @description Setup test data
     */
    @TestSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
                Name = 'Test Account for Group Buy'
        );
        insert testAccount;

        // Create test Product
        Product2 testProduct = new Product2(
                Name = 'Test Group Buy Product',
                ProductCode = 'GBP-001',
                IsActive = true
        );
        insert testProduct;

        // Create test Group Buy Proposal
        Group_Buy_Proposal__c testProposal = new Group_Buy_Proposal__c(
                Name = 'Test Group Buy',
                Account__c = testAccount.Id,
                Product__c = testProduct.Id,
                Status__c = 'Active',
                Type__c = 'Payment After Reach Quota',
                Min_Quota__c = 100,
                Max_Quota__c = 500,
                Start_Date__c = DateTime.now().addDays(-1),
                End_Date__c = DateTime.now().addDays(30),
                Approximate_Deliver_Start_Date__c = Date.today().addDays(45),
                Description__c = '<p>Test description</p>'
        );
        insert testProposal;

        // Create discount tiers
        List<Group_Proposal_Discount__c> discounts = new List<Group_Proposal_Discount__c>();

        // Tier 1: 0-99 = 5%
        discounts.add(new Group_Proposal_Discount__c(
                Group_Buy_Proposal__c = testProposal.Id,
                Min_Quota_For_Discount__c = 0,
                Max_Quota_Discount__c = 99,
                Discount__c = 5,
                Is_Main__c = false
        ));

        // Tier 2: 100-299 = 10%
        discounts.add(new Group_Proposal_Discount__c(
                Group_Buy_Proposal__c = testProposal.Id,
                Min_Quota_For_Discount__c = 100,
                Max_Quota_Discount__c = 299,
                Discount__c = 10,
                Is_Main__c = true
        ));

        // Tier 3: 300-500 = 15%
        discounts.add(new Group_Proposal_Discount__c(
                Group_Buy_Proposal__c = testProposal.Id,
                Min_Quota_For_Discount__c = 300,
                Max_Quota_Discount__c = 500,
                Discount__c = 15,
                Is_Main__c = false
        ));

        insert discounts;

        // Create an expired proposal for testing
        Group_Buy_Proposal__c expiredProposal = new Group_Buy_Proposal__c(
                Name = 'Expired Group Buy',
                Product__c = testProduct.Id,
                Status__c = 'Active',
                Type__c = 'Immediate Payment',
                Min_Quota__c = 50,
                Max_Quota__c = 100,
                Start_Date__c = DateTime.now().addDays(-30),
                End_Date__c = DateTime.now().addDays(-1)
        );
        insert expiredProposal;

        // Create an inactive proposal
        Group_Buy_Proposal__c inactiveProposal = new Group_Buy_Proposal__c(
                Name = 'Pending Approval Group Buy',
                Product__c = testProduct.Id,
                Status__c = 'Pending Approval',
                Type__c = 'Immediate Payment',
                Min_Quota__c = 50,
                Max_Quota__c = 100
        );
        insert inactiveProposal;
    }

    /**
     * @description Test getProposalDetails with valid proposal
     */
    @isTest
    static void testGetProposalDetails() {
        Group_Buy_Proposal__c proposal = [
                SELECT Id FROM Group_Buy_Proposal__c WHERE Name = 'Test Group Buy' LIMIT 1
        ];

        Test.startTest();
        GroupProposalController.ProposalDetails details =
                GroupProposalController.getProposalDetails(proposal.Id);
        Test.stopTest();

        System.assertNotEquals(null, details, 'Details should not be null');
        System.assertNotEquals(null, details.proposal, 'Proposal should not be null');
        System.assertEquals('Test Group Buy', details.proposal.Name, 'Proposal name should match');
        System.assertEquals(500, details.availableQuota, 'Available quota should be 500');
        System.assertEquals(0, details.progressPercentage, 'Progress should be 0');
        System.assertEquals(false, details.isMinQuotaReached, 'Min quota should not be reached');
        System.assertEquals(true, details.isActive, 'Proposal should be active');
        System.assertEquals(true, details.canOrder, 'Should be able to order');
        System.assertEquals(3, details.discountTiers.size(), 'Should have 3 discount tiers');
    }

    /**
     * @description Test getProposalDetails with null ID
     */
    @isTest
    static void testGetProposalDetailsNullId() {
        Test.startTest();
        try {
            GroupProposalController.getProposalDetails(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should indicate ID required');
        }
        Test.stopTest();
    }

    /**
     * @description Test getProposalDetails with invalid ID
     */
    @isTest
    static void testGetProposalDetailsInvalidId() {
        Test.startTest();
        try {
            // Use a fake ID
            GroupProposalController.getProposalDetails('a00000000000000AAA');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not found'), 'Should indicate not found');
        }
        Test.stopTest();
    }

    /**
     * @description Test getAvailableProposals
     */
    @isTest
    static void testGetAvailableProposals() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];

        Test.startTest();
        List<GroupProposalController.ProposalSummary> summaries =
                GroupProposalController.getAvailableProposals(testAccount.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, summaries, 'Summaries should not be null');
        // Should only return active, non-expired proposals
        System.assertEquals(1, summaries.size(), 'Should have 1 available proposal');
        System.assertEquals('Test Group Buy', summaries[0].name, 'Name should match');
    }

    /**
     * @description Test getAvailableProposals with product filter
     */
    @isTest
    static void testGetAvailableProposalsWithProduct() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];
        Product2 testProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'GBP-001' LIMIT 1];

        Test.startTest();
        List<GroupProposalController.ProposalSummary> summaries =
                GroupProposalController.getAvailableProposals(testAccount.Id, testProduct.Id);
        Test.stopTest();

        System.assertEquals(1, summaries.size(), 'Should have 1 proposal for this product');
    }

    /**
     * @description Test getExistingOrder when no order exists
     */
    @isTest
    static void testGetExistingOrderNone() {
        Group_Buy_Proposal__c proposal = [
                SELECT Id FROM Group_Buy_Proposal__c WHERE Name = 'Test Group Buy' LIMIT 1
        ];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];

        Test.startTest();
        Conditional_Order__c existingOrder =
                GroupProposalController.getExistingOrder(proposal.Id, testAccount.Id);
        Test.stopTest();

        System.assertEquals(null, existingOrder, 'Should return null when no order exists');
    }

    /**
     * @description Test createConditionalOrder success
     */
    @isTest
    static void testCreateConditionalOrderSuccess() {
        Group_Buy_Proposal__c proposal = [
                SELECT Id FROM Group_Buy_Proposal__c WHERE Name = 'Test Group Buy' LIMIT 1
        ];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];

        Test.startTest();
        GroupProposalController.ConditionalOrderResult result =
                GroupProposalController.createConditionalOrder(proposal.Id, testAccount.Id, 10);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should succeed');
        System.assertNotEquals(null, result.order, 'Order should not be null');
        System.assertEquals(10, result.order.Quantity__c, 'Quantity should be 10');
        System.assert(result.message.contains('Successfully'), 'Message should indicate success');
    }

    /**
     * @description Test createConditionalOrder with missing proposal ID
     */
    @isTest
    static void testCreateConditionalOrderMissingProposal() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];

        Test.startTest();
        try {
            GroupProposalController.createConditionalOrder(null, testAccount.Id, 10);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Proposal ID is required'), 'Should indicate proposal required');
        }
        Test.stopTest();
    }

    /**
     * @description Test createConditionalOrder with missing account ID
     */
    @isTest
    static void testCreateConditionalOrderMissingAccount() {
        Group_Buy_Proposal__c proposal = [
                SELECT Id FROM Group_Buy_Proposal__c WHERE Name = 'Test Group Buy' LIMIT 1
        ];

        Test.startTest();
        try {
            GroupProposalController.createConditionalOrder(proposal.Id, null, 10);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Account ID is required'), 'Should indicate account required');
        }
        Test.stopTest();
    }

    /**
     * @description Test createConditionalOrder with invalid quantity
     */
    @isTest
    static void testCreateConditionalOrderInvalidQuantity() {
        Group_Buy_Proposal__c proposal = [
                SELECT Id FROM Group_Buy_Proposal__c WHERE Name = 'Test Group Buy' LIMIT 1
        ];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];

        Test.startTest();
        try {
            GroupProposalController.createConditionalOrder(proposal.Id, testAccount.Id, 0);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('greater than zero'), 'Should indicate quantity must be > 0');
        }
        Test.stopTest();
    }

    /**
     * @description Test createConditionalOrder with expired proposal
     */
    @isTest
    static void testCreateConditionalOrderExpiredProposal() {
        Group_Buy_Proposal__c proposal = [
                SELECT Id FROM Group_Buy_Proposal__c WHERE Name = 'Expired Group Buy' LIMIT 1
        ];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];

        Test.startTest();
        try {
            GroupProposalController.createConditionalOrder(proposal.Id, testAccount.Id, 10);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('expired'), 'Should indicate expired');
        }
        Test.stopTest();
    }

    /**
     * @description Test createConditionalOrder with inactive proposal
     */
    @isTest
    static void testCreateConditionalOrderInactiveProposal() {
        Group_Buy_Proposal__c proposal = [
                SELECT Id FROM Group_Buy_Proposal__c WHERE Name = 'Pending Approval Group Buy' LIMIT 1
        ];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];

        Test.startTest();
        try {
            GroupProposalController.createConditionalOrder(proposal.Id, testAccount.Id, 10);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not currently active'), 'Should indicate not active');
        }
        Test.stopTest();
    }

    /**
     * @description Test createConditionalOrder with quantity exceeding quota
     */
    @isTest
    static void testCreateConditionalOrderExceedsQuota() {
        Group_Buy_Proposal__c proposal = [
                SELECT Id FROM Group_Buy_Proposal__c WHERE Name = 'Test Group Buy' LIMIT 1
        ];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];

        Test.startTest();
        try {
            // Max quota is 500, try to order 600
            GroupProposalController.createConditionalOrder(proposal.Id, testAccount.Id, 600);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('exceeds available'), 'Should indicate exceeds quota');
        }
        Test.stopTest();
    }

    /**
     * @description Test createConditionalOrder duplicate order
     */
    @isTest
    static void testCreateConditionalOrderDuplicate() {
        Group_Buy_Proposal__c proposal = [
                SELECT Id, Product__c FROM Group_Buy_Proposal__c WHERE Name = 'Test Group Buy' LIMIT 1
        ];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];

        // Create first order
        Conditional_Order__c existingOrder = new Conditional_Order__c(
                Group_Buy_Proposal__c = proposal.Id,
                Account__c = testAccount.Id,
                Product__c = proposal.Product__c,
                Quantity__c = 5
        );
        insert existingOrder;

        Test.startTest();
        try {
            GroupProposalController.createConditionalOrder(proposal.Id, testAccount.Id, 10);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('already have'), 'Should indicate already has order');
        }
        Test.stopTest();
    }

    /**
     * @description Test getExistingOrder when order exists
     */
    @isTest
    static void testGetExistingOrderExists() {
        Group_Buy_Proposal__c proposal = [
                SELECT Id, Product__c FROM Group_Buy_Proposal__c WHERE Name = 'Test Group Buy' LIMIT 1
        ];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];

        // Create order
        Conditional_Order__c order = new Conditional_Order__c(
                Group_Buy_Proposal__c = proposal.Id,
                Account__c = testAccount.Id,
                Product__c = proposal.Product__c,
                Quantity__c = 25
        );
        insert order;

        Test.startTest();
        Conditional_Order__c existingOrder =
                GroupProposalController.getExistingOrder(proposal.Id, testAccount.Id);
        Test.stopTest();

        System.assertNotEquals(null, existingOrder, 'Should return existing order');
        System.assertEquals(25, existingOrder.Quantity__c, 'Quantity should match');
    }

    /**
     * @description Test updateConditionalOrder success
     */
    @isTest
    static void testUpdateConditionalOrderSuccess() {
        Group_Buy_Proposal__c proposal = [
                SELECT Id, Product__c FROM Group_Buy_Proposal__c WHERE Name = 'Test Group Buy' LIMIT 1
        ];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];

        // Create order
        Conditional_Order__c order = new Conditional_Order__c(
                Group_Buy_Proposal__c = proposal.Id,
                Account__c = testAccount.Id,
                Product__c = proposal.Product__c,
                Quantity__c = 10
        );
        insert order;

        Test.startTest();
        GroupProposalController.ConditionalOrderResult result =
                GroupProposalController.updateConditionalOrder(order.Id, 20);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should succeed');
        System.assertEquals(20, result.order.Quantity__c, 'Quantity should be updated to 20');
    }

    /**
     * @description Test updateConditionalOrder with invalid quantity
     */
    @isTest
    static void testUpdateConditionalOrderInvalidQty() {
        Group_Buy_Proposal__c proposal = [
                SELECT Id, Product__c FROM Group_Buy_Proposal__c WHERE Name = 'Test Group Buy' LIMIT 1
        ];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];

        Conditional_Order__c order = new Conditional_Order__c(
                Group_Buy_Proposal__c = proposal.Id,
                Account__c = testAccount.Id,
                Product__c = proposal.Product__c,
                Quantity__c = 10
        );
        insert order;

        Test.startTest();
        try {
            GroupProposalController.updateConditionalOrder(order.Id, -5);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('greater than zero'), 'Should indicate invalid quantity');
        }
        Test.stopTest();
    }

    /**
     * @description Test cancelConditionalOrder success
     */
    @isTest
    static void testCancelConditionalOrderSuccess() {
        Group_Buy_Proposal__c proposal = [
                SELECT Id, Product__c FROM Group_Buy_Proposal__c WHERE Name = 'Test Group Buy' LIMIT 1
        ];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];

        Conditional_Order__c order = new Conditional_Order__c(
                Group_Buy_Proposal__c = proposal.Id,
                Account__c = testAccount.Id,
                Product__c = proposal.Product__c,
                Quantity__c = 10
        );
        insert order;
        Id orderId = order.Id;

        Test.startTest();
        GroupProposalController.ConditionalOrderResult result =
                GroupProposalController.cancelConditionalOrder(orderId);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should succeed');
        System.assert(result.message.contains('cancelled'), 'Should indicate cancelled');

        // Verify order was deleted
        List<Conditional_Order__c> remaining = [SELECT Id FROM Conditional_Order__c WHERE Id = :orderId];
        System.assertEquals(0, remaining.size(), 'Order should be deleted');
    }

    /**
     * @description Test cancelConditionalOrder with null ID
     */
    @isTest
    static void testCancelConditionalOrderNullId() {
        Test.startTest();
        try {
            GroupProposalController.cancelConditionalOrder(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should indicate ID required');
        }
        Test.stopTest();
    }

    /**
     * @description Test wrapper classes
     */
    @isTest
    static void testWrapperClasses() {
        Test.startTest();

        // ProposalDetails
        GroupProposalController.ProposalDetails details = new GroupProposalController.ProposalDetails();
        details.availableQuota = 100;
        details.progressPercentage = 50;
        details.isMinQuotaReached = true;
        details.isActive = true;
        details.isExpired = false;
        details.hasAvailableQuota = true;
        details.canOrder = true;

        // ProposalSummary
        GroupProposalController.ProposalSummary summary = new GroupProposalController.ProposalSummary();
        summary.proposalId = null;
        summary.name = 'Test';
        summary.productName = 'Product';
        summary.productCode = 'P001';
        summary.minQuota = 10;
        summary.maxQuota = 100;
        summary.bookedQuota = 25;
        summary.availableQuota = 75;
        summary.progressPercentage = 25;
        summary.maxDiscount = 15;

        // ConditionalOrderResult
        GroupProposalController.ConditionalOrderResult result = new GroupProposalController.ConditionalOrderResult();
        System.assertEquals(false, result.success, 'Default success should be false');

        // ProposalWithDiscounts
        GroupProposalController.ProposalWithDiscounts pwd = new GroupProposalController.ProposalWithDiscounts();
        pwd.availableQuota = 50;
        pwd.progressPercentage = 75;
        pwd.isMinQuotaReached = true;
        pwd.currentDiscount = 10;
        pwd.maxDiscount = 15;

        Test.stopTest();

        System.assertEquals(100, details.availableQuota, 'Available quota should match');
        System.assertEquals('Test', summary.name, 'Name should match');
        System.assertEquals(50, pwd.availableQuota, 'ProposalWithDiscounts availableQuota should match');
    }

    /**
     * @description Test getProposalsByProduct with valid product
     */
    @isTest
    static void testGetProposalsByProduct() {
        Product2 testProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'GBP-001' LIMIT 1];

        Test.startTest();
        List<GroupProposalController.ProposalWithDiscounts> results =
                GroupProposalController.getProposalsByProduct(testProduct.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should have 1 active proposal for this product');
        System.assertEquals('Test Group Buy', results[0].proposal.Name, 'Proposal name should match');
        System.assertEquals(3, results[0].discountTiers.size(), 'Should have 3 discount tiers');
        System.assertEquals(500, results[0].availableQuota, 'Available quota should be 500');
    }

    /**
     * @description Test getProposalsByProduct with null product ID
     */
    @isTest
    static void testGetProposalsByProductNull() {
        Test.startTest();
        List<GroupProposalController.ProposalWithDiscounts> results =
                GroupProposalController.getProposalsByProduct(null);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should have 0 proposals for null product');
    }

    /**
     * @description Test getProposalsByProduct with product that has no proposals
     */
    @isTest
    static void testGetProposalsByProductNoProposals() {
        // Create product with no proposals
        Product2 newProduct = new Product2(
                Name = 'Product Without Proposals',
                ProductCode = 'NO-PROPOSALS',
                IsActive = true
        );
        insert newProduct;

        Test.startTest();
        List<GroupProposalController.ProposalWithDiscounts> results =
                GroupProposalController.getProposalsByProduct(newProduct.Id);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should have 0 proposals');
    }

    /**
     * @description Test getExistingOrdersForProduct with no orders
     */
    @isTest
    static void testGetExistingOrdersForProductNone() {
        Product2 testProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'GBP-001' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];

        Test.startTest();
        Map<Id, Conditional_Order__c> orders =
                GroupProposalController.getExistingOrdersForProduct(testProduct.Id, testAccount.Id);
        Test.stopTest();

        System.assertNotEquals(null, orders, 'Map should not be null');
        System.assertEquals(0, orders.size(), 'Should have 0 orders');
    }

    /**
     * @description Test getExistingOrdersForProduct with existing order
     */
    @isTest
    static void testGetExistingOrdersForProductWithOrder() {
        Product2 testProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'GBP-001' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];
        Group_Buy_Proposal__c proposal = [SELECT Id FROM Group_Buy_Proposal__c WHERE Name = 'Test Group Buy' LIMIT 1];

        // Create order
        Conditional_Order__c order = new Conditional_Order__c(
                Group_Buy_Proposal__c = proposal.Id,
                Account__c = testAccount.Id,
                Product__c = testProduct.Id,
                Quantity__c = 15
        );
        insert order;

        Test.startTest();
        Map<Id, Conditional_Order__c> orders =
                GroupProposalController.getExistingOrdersForProduct(testProduct.Id, testAccount.Id);
        Test.stopTest();

        System.assertEquals(1, orders.size(), 'Should have 1 order');
        System.assertEquals(15, orders.get(proposal.Id).Quantity__c, 'Quantity should match');
    }

    /**
     * @description Test getExistingOrdersForProduct with null parameters
     */
    @isTest
    static void testGetExistingOrdersForProductNullParams() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Group Buy' LIMIT 1];
        Product2 testProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'GBP-001' LIMIT 1];

        Test.startTest();
        Map<Id, Conditional_Order__c> orders1 =
                GroupProposalController.getExistingOrdersForProduct(null, testAccount.Id);
        Map<Id, Conditional_Order__c> orders2 =
                GroupProposalController.getExistingOrdersForProduct(testProduct.Id, null);
        Test.stopTest();

        System.assertEquals(0, orders1.size(), 'Should have 0 orders with null product');
        System.assertEquals(0, orders2.size(), 'Should have 0 orders with null account');
    }
}