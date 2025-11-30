/**
 * @description Controller for Group Buy Proposal LWC component
 * Handles CRUD operations for Group_Buy_Proposal__c and Product2 objects
 */
public with sharing class GroupBuyProposalController {

    /**
     * @description Search for products based on search term
     * @param searchTerm The term to search for in product name or code
     * @return List of matching Product2 records
     */
    @AuraEnabled(cacheable=true)
    public static List<Product2> searchProducts(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return new List<Product2>();
        }

        String searchKey = '%' + String.escapeSingleQuotes(searchTerm) + '%';
System.debug( [
        SELECT Id, Name, ProductCode, Description, IsActive,
                Brand__c, Character__c, Family
        FROM Product2
        WHERE Name LIKE :searchKey
        OR ProductCode LIKE :searchKey
        ORDER BY Name ASC
        LIMIT 20
] );
        return [
            SELECT Id, Name, ProductCode, Description, IsActive,
                   Brand__c, Character__c, Family
            FROM Product2
            WHERE Name LIKE :searchKey
               OR ProductCode LIKE :searchKey
            ORDER BY Name ASC
            LIMIT 20
        ];
    }

    /**
     * @description Get a single product by Id
     * @param productId The Id of the product to retrieve
     * @return The Product2 record
     */
    @AuraEnabled(cacheable=true)
    public static Product2 getProductById(Id productId) {
        if (productId == null) {
            return null;
        }

        List<Product2> products = [
            SELECT Id, Name, ProductCode, Description, IsActive,
                   Brand__c, Character__c, Family
            FROM Product2
            WHERE Id = :productId
            LIMIT 1
        ];

        return products.isEmpty() ? null : products[0];
    }

    /**
     * @description Create a new Product2 record
     * @param productData JSON string containing product fields
     * @return The created Product2 record
     */
    @AuraEnabled
    public static Product2 createProduct(String productData) {
        try {
            Map<String, Object> productMap = (Map<String, Object>) JSON.deserializeUntyped(productData);

            Product2 newProduct = new Product2();
            newProduct.Name = (String) productMap.get('Name');
            newProduct.ProductCode = (String) productMap.get('ProductCode');
            newProduct.Description = (String) productMap.get('Description');
            newProduct.IsActive = productMap.get('IsActive') != null ? (Boolean) productMap.get('IsActive') : true;
            newProduct.Brand__c = (String) productMap.get('Brand__c');
            newProduct.Character__c = (String) productMap.get('Character__c');
            newProduct.Family = (String) productMap.get('Family');

            insert newProduct;

            insert new ProductCategoryProduct(
                ProductCategoryId = '0ZGWU000000AgKX4A0', ProductId = newProduct.Id
            );

            return [
                SELECT Id, Name, ProductCode, Description, IsActive,
                       Brand__c, Character__c, Family
                FROM Product2
                WHERE Id = :newProduct.Id
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error creating product: ' + e.getMessage());
        }
    }

    /**
     * @description Create a new Group_Buy_Proposal__c record
     * @param proposalData JSON string containing proposal fields
     * @return The created Group_Buy_Proposal__c record
     */
    @AuraEnabled
    public static Group_Buy_Proposal__c createGroupBuyProposal(String proposalData) {
        try {
            Map<String, Object> proposalMap = (Map<String, Object>) JSON.deserializeUntyped(proposalData);

            Group_Buy_Proposal__c proposal = new Group_Buy_Proposal__c();
            proposal.Name = (String) proposalMap.get('Name');
            proposal.Description__c = (String) proposalMap.get('Description__c');
            proposal.Status__c = (String) proposalMap.get('Status__c');
            proposal.Type__c = (String) proposalMap.get('Type__c');
            proposal.Min_Quota__c = proposalMap.get('Min_Quota__c') != null ?
                Decimal.valueOf(String.valueOf(proposalMap.get('Min_Quota__c'))) : null;
            proposal.Max_Quota__c = proposalMap.get('Max_Quota__c') != null ?
                Decimal.valueOf(String.valueOf(proposalMap.get('Max_Quota__c'))) : null;

            // Handle dates
            if (proposalMap.get('Start_Date__c') != null) {
                proposal.Start_Date__c = DateTime.valueOf(
                    String.valueOf(proposalMap.get('Start_Date__c')).replace('T', ' ').replace('Z', '')
                );
            }
            if (proposalMap.get('End_Date__c') != null) {
                proposal.End_Date__c = DateTime.valueOf(
                    String.valueOf(proposalMap.get('End_Date__c')).replace('T', ' ').replace('Z', '')
                );
            }
            if (proposalMap.get('Approximate_Deliver_Start_Date__c') != null) {
                proposal.Approximate_Deliver_Start_Date__c = Date.valueOf(
                    String.valueOf(proposalMap.get('Approximate_Deliver_Start_Date__c'))
                );
            }

            // Handle lookups
            if (proposalMap.get('Product__c') != null) {
                proposal.Product__c = (Id) proposalMap.get('Product__c');
            }
            if (proposalMap.get('Account__c') != null) {
                proposal.Account__c = (Id) proposalMap.get('Account__c');
            }

            insert proposal;

            return [
                SELECT Id, Name, Description__c, Status__c, Type__c,
                       Min_Quota__c, Max_Quota__c, Start_Date__c, End_Date__c,
                       Approximate_Deliver_Start_Date__c, Product__c, Product__r.Name,
                       Account__c, Account__r.Name
                FROM Group_Buy_Proposal__c
                WHERE Id = :proposal.Id
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error creating proposal: ' + e.getMessage());
        }
    }

    /**
     * @description Get picklist values for Group_Buy_Proposal__c fields
     * @return Map of field names to their picklist values
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<PicklistOption>> getProposalPicklistValues() {
        Map<String, List<PicklistOption>> picklistMap = new Map<String, List<PicklistOption>>();

        // Status picklist
        picklistMap.put('Status__c', getPicklistValues(
            Group_Buy_Proposal__c.Status__c.getDescribe()
        ));

        // Type picklist
        picklistMap.put('Type__c', getPicklistValues(
            Group_Buy_Proposal__c.Type__c.getDescribe()
        ));

        return picklistMap;
    }

    /**
     * @description Get picklist values for Product2 fields
     * @return Map of field names to their picklist values
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<PicklistOption>> getProductPicklistValues() {
        Map<String, List<PicklistOption>> picklistMap = new Map<String, List<PicklistOption>>();

        // Brand picklist
        picklistMap.put('Brand__c', getPicklistValues(
            Product2.Brand__c.getDescribe()
        ));

        // Character picklist
        picklistMap.put('Character__c', getPicklistValues(
            Product2.Character__c.getDescribe()
        ));

        return picklistMap;
    }

    /**
     * @description Helper method to extract picklist values from field describe
     * @param fieldDescribe The field describe result
     * @return List of PicklistOption wrapper objects
     */
    private static List<PicklistOption> getPicklistValues(Schema.DescribeFieldResult fieldDescribe) {
        List<PicklistOption> options = new List<PicklistOption>();

        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getValue(), entry.getLabel()));
            }
        }

        return options;
    }

    /**
     * @description Search for accounts based on search term
     * @param searchTerm The term to search for in account name
     * @return List of matching Account records
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> searchAccounts(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return new List<Account>();
        }

        String searchKey = '%' + String.escapeSingleQuotes(searchTerm) + '%';

        return [
            SELECT Id, Name, AccountNumber
            FROM Account
            WHERE Name LIKE :searchKey
            ORDER BY Name ASC
            LIMIT 20
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Account getAccountById(Id accountId) {
        if (accountId == null) {
            return null;
        }

        List<Account> accounts = [
                SELECT Id, Name, AccountNumber, BillingCity, BillingCountry
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
        ];

        return accounts.isEmpty() ? null : accounts[0];
    }

    /**
     * @description Wrapper class for picklist options
     */
    public class PicklistOption {
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String label { get; set; }

        public PicklistOption(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }
}
