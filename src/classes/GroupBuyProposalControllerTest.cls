/**
 * @description Test class for GroupBuyProposalController
 */
@isTest
private class GroupBuyProposalControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account',
            AccountNumber = 'ACC-001'
        );
        insert testAccount;
        
        // Create test Products
        List<Product2> products = new List<Product2>();
        for (Integer i = 0; i < 5; i++) {
            products.add(new Product2(
                Name = 'Test Product ' + i,
                ProductCode = 'TP-00' + i,
                Description = 'Test product description ' + i,
                IsActive = true,
                Brand__c = 'Sony',
                Character__c = 'Group Purchase'
            ));
        }
        insert products;
    }
    
    @isTest
    static void testSearchProducts() {
        // Test searching for products
        Test.startTest();
        List<Product2> results = GroupBuyProposalController.searchProducts('Test Product');
        Test.stopTest();
        
        System.assertEquals(5, results.size(), 'Should find 5 test products');
    }
    
    @isTest
    static void testSearchProductsMinLength() {
        // Test search with term too short
        Test.startTest();
        List<Product2> results = GroupBuyProposalController.searchProducts('T');
        Test.stopTest();
        
        System.assertEquals(0, results.size(), 'Should return empty list for short search term');
    }
    
    @isTest
    static void testSearchProductsEmpty() {
        // Test search with empty term
        Test.startTest();
        List<Product2> results = GroupBuyProposalController.searchProducts('');
        Test.stopTest();
        
        System.assertEquals(0, results.size(), 'Should return empty list for empty search term');
    }
    
    @isTest
    static void testGetProductById() {
        Product2 testProduct = [SELECT Id FROM Product2 LIMIT 1];
        
        Test.startTest();
        Product2 result = GroupBuyProposalController.getProductById(testProduct.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return a product');
        System.assertEquals(testProduct.Id, result.Id, 'Should return correct product');
    }
    
    @isTest
    static void testGetProductByIdNull() {
        Test.startTest();
        Product2 result = GroupBuyProposalController.getProductById(null);
        Test.stopTest();
        
        System.assertEquals(null, result, 'Should return null for null ID');
    }
    
    @isTest
    static void testCreateProduct() {
        Map<String, Object> productData = new Map<String, Object>{
            'Name' => 'New Test Product',
            'ProductCode' => 'NTP-001',
            'Description' => 'A new test product',
            'IsActive' => true,
            'Brand__c' => 'Samsung',
            'Character__c' => 'Standard'
        };
        
        Test.startTest();
        Product2 result = GroupBuyProposalController.createProduct(JSON.serialize(productData));
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should create a product');
        System.assertEquals('New Test Product', result.Name, 'Product name should match');
        System.assertEquals('NTP-001', result.ProductCode, 'Product code should match');
    }
    
    @isTest
    static void testCreateGroupBuyProposal() {
        Product2 testProduct = [SELECT Id FROM Product2 LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Map<String, Object> proposalData = new Map<String, Object>{
            'Name' => 'Test Proposal',
            'Description__c' => '<p>Test description</p>',
            'Status__c' => 'Created',
            'Type__c' => 'Immediate Payment',
            'Min_Quota__c' => 10,
            'Max_Quota__c' => 100,
            'Start_Date__c' => String.valueOf(DateTime.now()),
            'End_Date__c' => String.valueOf(DateTime.now().addDays(30)),
            'Approximate_Deliver_Start_Date__c' => String.valueOf(Date.today().addDays(45)),
            'Product__c' => testProduct.Id,
            'Account__c' => testAccount.Id
        };
        
        Test.startTest();
        Group_Buy_Proposal__c result = GroupBuyProposalController.createGroupBuyProposal(
            JSON.serialize(proposalData)
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should create a proposal');
        System.assertEquals('Test Proposal', result.Name, 'Proposal name should match');
        System.assertEquals(testProduct.Id, result.Product__c, 'Product should be linked');
        System.assertEquals(testAccount.Id, result.Account__c, 'Account should be linked');
    }
    
    @isTest
    static void testCreateGroupBuyProposalMinimal() {
        Map<String, Object> proposalData = new Map<String, Object>{
            'Name' => 'Minimal Proposal',
            'Status__c' => 'Created'
        };
        
        Test.startTest();
        Group_Buy_Proposal__c result = GroupBuyProposalController.createGroupBuyProposal(
            JSON.serialize(proposalData)
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should create a minimal proposal');
        System.assertEquals('Minimal Proposal', result.Name, 'Proposal name should match');
    }
    
    @isTest
    static void testGetProposalPicklistValues() {
        Test.startTest();
        Map<String, List<GroupBuyProposalController.PicklistOption>> result = 
            GroupBuyProposalController.getProposalPicklistValues();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return picklist values');
        System.assert(result.containsKey('Status__c'), 'Should contain Status__c picklist');
        System.assert(result.containsKey('Type__c'), 'Should contain Type__c picklist');
        System.assert(result.get('Status__c').size() > 0, 'Status__c should have options');
    }
    
    @isTest
    static void testGetProductPicklistValues() {
        Test.startTest();
        Map<String, List<GroupBuyProposalController.PicklistOption>> result = 
            GroupBuyProposalController.getProductPicklistValues();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return picklist values');
        System.assert(result.containsKey('Brand__c'), 'Should contain Brand__c picklist');
        System.assert(result.containsKey('Character__c'), 'Should contain Character__c picklist');
    }
    
    @isTest
    static void testSearchAccounts() {
        Test.startTest();
        List<Account> results = GroupBuyProposalController.searchAccounts('Test');
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should find 1 test account');
        System.assertEquals('Test Account', results[0].Name, 'Account name should match');
    }
    
    @isTest
    static void testSearchAccountsMinLength() {
        Test.startTest();
        List<Account> results = GroupBuyProposalController.searchAccounts('T');
        Test.stopTest();
        
        System.assertEquals(0, results.size(), 'Should return empty list for short search term');
    }
    
    @isTest
    static void testCreateProductError() {
        // Test with invalid data to trigger error handling
        String invalidJson = '{"Name": ""}';
        
        Test.startTest();
        try {
            // This might throw an error depending on validation rules
            Product2 result = GroupBuyProposalController.createProduct(invalidJson);
            // If no error, product was created (minimal validation)
            System.assertNotEquals(null, result.Id, 'Product should be created');
        } catch (AuraHandledException e) {
            // Expected behavior if validation fails
            System.assert(e.getMessage().contains('Error'), 'Should contain error message');
        }
        Test.stopTest();
    }
}
