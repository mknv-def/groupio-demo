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
        if (productId == null) return null;
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

            // Note: Hardcoded ID from original code preserved
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
            Group_Buy_Proposal__c proposal = mapJsonToProposal(proposalMap, new Group_Buy_Proposal__c());

            insert proposal;

            return getProposalById(proposal.Id);
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
        picklistMap.put('Status__c', getPicklistValues(Group_Buy_Proposal__c.Status__c.getDescribe()));
        picklistMap.put('Type__c', getPicklistValues(Group_Buy_Proposal__c.Type__c.getDescribe()));
        return picklistMap;
    }

    /**
     * @description Get picklist values for Product2 fields
     * @return Map of field names to their picklist values
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<PicklistOption>> getProductPicklistValues() {
        Map<String, List<PicklistOption>> picklistMap = new Map<String, List<PicklistOption>>();
        picklistMap.put('Brand__c', getPicklistValues(Product2.Brand__c.getDescribe()));
        picklistMap.put('Character__c', getPicklistValues(Product2.Character__c.getDescribe()));
        return picklistMap;
    }

    // ==========================================
    // ACCOUNT METHODS
    // ==========================================

    @AuraEnabled(cacheable=true)
    public static List<Account> searchAccounts(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) return new List<Account>();
        String searchKey = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        return [SELECT Id, Name, AccountNumber FROM Account WHERE Name LIKE :searchKey ORDER BY Name ASC LIMIT 20];
    }

    @AuraEnabled(cacheable=true)
    public static Account getAccountById(Id accountId) {
        if (accountId == null) return null;
        List<Account> accounts = [SELECT Id, Name, AccountNumber, BillingCity, BillingCountry FROM Account WHERE Id = :accountId LIMIT 1];
        return accounts.isEmpty() ? null : accounts[0];
    }

    // ==========================================
    // *** MISSING METHODS ADDED BELOW ***
    // ==========================================

    /**
     * @description Fetch proposals for the "My Proposals" tab
     * @param accountId The effective account ID of the user
     * @return List of Group_Buy_Proposal__c
     */
    @AuraEnabled
    public static List<Group_Buy_Proposal__c> getMyProposals(Id accountId) {
        try {
            // Note: Added Progress_Percentage__c based on your LWC usage.
            // Ensure this field exists on your object.
            return [
                    SELECT Id, Name, Description__c, Status__c, Type__c,
                            Min_Quota__c, Max_Quota__c, Start_Date__c, End_Date__c,
                            Base_Price__c, Approximate_Deliver_Start_Date__c,
                            Progress_Percentage__c,
                            Product__c, Product__r.Name
                    FROM Group_Buy_Proposal__c
                    WHERE Account__c = :accountId OR CreatedById = :UserInfo.getUserId()
                    ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching proposals: ' + e.getMessage());
        }
    }

    /**
     * @description Update an existing proposal
     * @param proposalData JSON string containing fields to update
     * @return Updated Group_Buy_Proposal__c record
     */
    @AuraEnabled
    public static Group_Buy_Proposal__c updateProposal(String proposalData) {
        try {
            Map<String, Object> proposalMap = (Map<String, Object>) JSON.deserializeUntyped(proposalData);

            String proposalId = (String) proposalMap.get('Id');
            if (String.isBlank(proposalId)) {
                throw new AuraHandledException('Proposal ID is missing for update.');
            }

            Group_Buy_Proposal__c proposalToUpdate = new Group_Buy_Proposal__c(Id = proposalId);
            proposalToUpdate = mapJsonToProposal(proposalMap, proposalToUpdate);

            update proposalToUpdate;

            return getProposalById(proposalToUpdate.Id);
        } catch (Exception e) {
            throw new AuraHandledException('Error updating proposal: ' + e.getMessage());
        }
    }

    /**
     * @description Delete a proposal
     * @param proposalId The ID of the proposal to delete
     */
    @AuraEnabled
    public static void deleteProposal(Id proposalId) {
        try {
            if (proposalId != null) {
                delete new Group_Buy_Proposal__c(Id = proposalId);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting proposal: ' + e.getMessage());
        }
    }

    // ==========================================
    // HELPER METHODS
    // ==========================================

    /**
     * @description Helper to map JSON map to Proposal SObject (Reused for Create and Update)
     */
    private static Group_Buy_Proposal__c mapJsonToProposal(Map<String, Object> mapData, Group_Buy_Proposal__c proposal) {

        if (mapData.containsKey('Name')) proposal.Name = (String) mapData.get('Name');
        if (mapData.containsKey('Description__c')) proposal.Description__c = (String) mapData.get('Description__c');
        if (mapData.containsKey('Status__c')) proposal.Status__c = (String) mapData.get('Status__c');
        if (mapData.containsKey('Type__c')) proposal.Type__c = (String) mapData.get('Type__c');

        if (mapData.containsKey('Min_Quota__c') && mapData.get('Min_Quota__c') != null)
            proposal.Min_Quota__c = Decimal.valueOf(String.valueOf(mapData.get('Min_Quota__c')));

        if (mapData.containsKey('Max_Quota__c') && mapData.get('Max_Quota__c') != null)
            proposal.Max_Quota__c = Decimal.valueOf(String.valueOf(mapData.get('Max_Quota__c')));

        // Handle dates
        if (mapData.get('Start_Date__c') != null) {
            String dateStr = String.valueOf(mapData.get('Start_Date__c')).replace('T', ' ').replace('Z', '');
            proposal.Start_Date__c = DateTime.valueOf(dateStr);
        }
        if (mapData.get('End_Date__c') != null) {
            String dateStr = String.valueOf(mapData.get('End_Date__c')).replace('T', ' ').replace('Z', '');
            proposal.End_Date__c = DateTime.valueOf(dateStr);
        }
        if (mapData.get('Approximate_Deliver_Start_Date__c') != null) {
            proposal.Approximate_Deliver_Start_Date__c = Date.valueOf(String.valueOf(mapData.get('Approximate_Deliver_Start_Date__c')));
        }

        // Handle lookups (Only set if present to avoid overwriting on update)
        if (mapData.get('Product__c') != null) proposal.Product__c = (Id) mapData.get('Product__c');
        if (mapData.get('Account__c') != null) proposal.Account__c = (Id) mapData.get('Account__c');

        return proposal;
    }

    /**
     * @description Helper to get single proposal with lookups
     */
    private static Group_Buy_Proposal__c getProposalById(Id proposalId) {
        return [
                SELECT Id, Name, Description__c, Status__c, Type__c,
                        Min_Quota__c, Max_Quota__c, Start_Date__c, End_Date__c,
                        Approximate_Deliver_Start_Date__c, Product__c, Product__r.Name,
                        Account__c, Account__r.Name
                FROM Group_Buy_Proposal__c
                WHERE Id = :proposalId
                LIMIT 1
        ];
    }

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