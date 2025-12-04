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

    @AuraEnabled(cacheable=true)
    public static List<Group_Buy_Proposal__c> getMyProposals(Id accountId) {
        if (accountId != null) {
            return [
                    SELECT Id, Name, Status__c, Type__c, Base_Price__c,
                            Min_Quota__c, Max_Quota__c, Booked_Quota__c,
                            Available_Quota__c, Progress_Percentage__c,
                            Start_Date__c, End_Date__c, Approximate_Deliver_Start_Date__c,
                            Description__c, Is_Min_Quota_Reached__c,
                            Product__c, Product__r.Name, Product__r.ProductCode,
                            Account__c, Account__r.Name,
                            CreatedDate, LastModifiedDate
                    FROM Group_Buy_Proposal__c
                    WHERE Account__c = :accountId
                    ORDER BY CreatedDate DESC
                    LIMIT 100
            ];
        } else {
            // For preview mode - get proposals created by current user without account
            return [
                    SELECT Id, Name, Status__c, Type__c, Base_Price__c,
                            Min_Quota__c, Max_Quota__c, Booked_Quota__c,
                            Available_Quota__c, Progress_Percentage__c,
                            Start_Date__c, End_Date__c, Approximate_Deliver_Start_Date__c,
                            Description__c, Is_Min_Quota_Reached__c,
                            Product__c, Product__r.Name, Product__r.ProductCode,
                            Account__c, Account__r.Name,
                            CreatedDate, LastModifiedDate
                    FROM Group_Buy_Proposal__c
                    WHERE CreatedById = :UserInfo.getUserId()
                    ORDER BY CreatedDate DESC
                    LIMIT 100
            ];
        }
    }

    /**
     * Get single proposal by Id
     */
    @AuraEnabled(cacheable=true)
    public static Group_Buy_Proposal__c getProposalById(Id proposalId) {
        return [
                SELECT Id, Name, Status__c, Type__c, Base_Price__c,
                        Min_Quota__c, Max_Quota__c, Booked_Quota__c,
                        Available_Quota__c, Progress_Percentage__c,
                        Start_Date__c, End_Date__c, Approximate_Deliver_Start_Date__c,
                        Description__c, Is_Min_Quota_Reached__c,
                        Product__c, Product__r.Name, Product__r.ProductCode,
                        Account__c, Account__r.Name,
                        CreatedDate, LastModifiedDate
                FROM Group_Buy_Proposal__c
                WHERE Id = :proposalId
                LIMIT 1
        ];
    }

    /**
     * Update an existing proposal
     */
    @AuraEnabled
    public static Group_Buy_Proposal__c updateProposal(String proposalData) {
        try {
            Map<String, Object> proposalMap = (Map<String, Object>) JSON.deserializeUntyped(proposalData);

            Id proposalId = (Id) proposalMap.get('Id');
            if (proposalId == null) {
                throw new AuraHandledException('Proposal ID is required for update');
            }

            // Build update record
            Group_Buy_Proposal__c proposalToUpdate = new Group_Buy_Proposal__c(Id = proposalId);

            if (proposalMap.containsKey('Name')) {
                proposalToUpdate.Name = (String) proposalMap.get('Name');
            }
            if (proposalMap.containsKey('Status__c')) {
                proposalToUpdate.Status__c = (String) proposalMap.get('Status__c');
            }
            if (proposalMap.containsKey('Type__c')) {
                proposalToUpdate.Type__c = (String) proposalMap.get('Type__c');
            }
            if (proposalMap.containsKey('Description__c')) {
                proposalToUpdate.Description__c = (String) proposalMap.get('Description__c');
            }
            if (proposalMap.containsKey('Min_Quota__c')) {
                Object minQuota = proposalMap.get('Min_Quota__c');
                proposalToUpdate.Min_Quota__c = minQuota != null ? Decimal.valueOf(String.valueOf(minQuota)) : null;
            }
            if (proposalMap.containsKey('Max_Quota__c')) {
                Object maxQuota = proposalMap.get('Max_Quota__c');
                proposalToUpdate.Max_Quota__c = maxQuota != null ? Decimal.valueOf(String.valueOf(maxQuota)) : null;
            }
            if (proposalMap.containsKey('Base_Price__c')) {
                Object basePrice = proposalMap.get('Base_Price__c');
                proposalToUpdate.Base_Price__c = basePrice != null ? Decimal.valueOf(String.valueOf(basePrice)) : null;
            }
            if (proposalMap.containsKey('Start_Date__c')) {
                String startDateStr = (String) proposalMap.get('Start_Date__c');
                if (String.isNotBlank(startDateStr)) {
                    proposalToUpdate.Start_Date__c = DateTime.valueOf(startDateStr.replace('T', ' ').replace('Z', ''));
                }
            }
            if (proposalMap.containsKey('End_Date__c')) {
                String endDateStr = (String) proposalMap.get('End_Date__c');
                if (String.isNotBlank(endDateStr)) {
                    proposalToUpdate.End_Date__c = DateTime.valueOf(endDateStr.replace('T', ' ').replace('Z', ''));
                }
            }
            if (proposalMap.containsKey('Approximate_Deliver_Start_Date__c')) {
                String deliveryDateStr = (String) proposalMap.get('Approximate_Deliver_Start_Date__c');
                if (String.isNotBlank(deliveryDateStr)) {
                    proposalToUpdate.Approximate_Deliver_Start_Date__c = Date.valueOf(deliveryDateStr);
                }
            }

            update proposalToUpdate;

            // Return updated record
            return getProposalById(proposalId);

        } catch (Exception e) {
            throw new AuraHandledException('Error updating proposal: ' + e.getMessage());
        }
    }

    /**
     * Delete a proposal
     */
    @AuraEnabled
    public static void deleteProposal(Id proposalId) {
        try {
            if (proposalId == null) {
                throw new AuraHandledException('Proposal ID is required');
            }

            // Fetch proposal to verify it can be deleted
            Group_Buy_Proposal__c proposal = [
                    SELECT Id, Status__c, Booked_Quota__c
                    FROM Group_Buy_Proposal__c
                    WHERE Id = :proposalId
                    LIMIT 1
            ];

            // Only allow deletion of proposals in certain statuses
            Set<String> deletableStatuses = new Set<String>{'Created', 'Rejected'};
            if (!deletableStatuses.contains(proposal.Status__c)) {
                throw new AuraHandledException('Cannot delete proposal with status: ' + proposal.Status__c);
            }

            // Check if there are any conditional orders
            if (proposal.Booked_Quota__c != null && proposal.Booked_Quota__c > 0) {
                throw new AuraHandledException('Cannot delete proposal with existing orders');
            }

            // Delete related discount tiers first
            List<Group_Proposal_Discount__c> discounts = [
                    SELECT Id
                    FROM Group_Proposal_Discount__c
                    WHERE Group_Buy_Proposal__c = :proposalId
            ];
            if (!discounts.isEmpty()) {
                delete discounts;
            }

            // Delete the proposal
            delete proposal;

        } catch (AuraHandledException e) {
            throw e;
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