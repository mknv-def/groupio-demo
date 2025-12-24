/**
 * @description Controller for Case operations in Groupio platform
 * Uses 'without sharing' to allow community users to create cases
 * regardless of their sharing rules
 */
public without sharing class CaseController {
    
    /**
     * @description Creates a new Case record
     * @param caseData JSON string containing case field values
     * @return Created Case record with Id
     */
    @AuraEnabled
    public static Case createCase(String caseData) {
        try {
            Map<String, Object> caseMap = (Map<String, Object>) JSON.deserializeUntyped(caseData);
            
            Case newCase = new Case();
            
            // Standard fields
            if (caseMap.containsKey('Subject')) {
                newCase.Subject = String.valueOf(caseMap.get('Subject'));
            }
            if (caseMap.containsKey('Description')) {
                newCase.Description = String.valueOf(caseMap.get('Description'));
            }
            if (caseMap.containsKey('Status')) {
                newCase.Status = String.valueOf(caseMap.get('Status'));
            } else {
                newCase.Status = 'New';
            }
            if (caseMap.containsKey('Priority')) {
                newCase.Priority = String.valueOf(caseMap.get('Priority'));
            } else {
                newCase.Priority = 'Medium';
            }
            if (caseMap.containsKey('Reason')) {
                newCase.Reason = String.valueOf(caseMap.get('Reason'));
            }
            if (caseMap.containsKey('Origin')) {
                newCase.Origin = String.valueOf(caseMap.get('Origin'));
            }
            if (caseMap.containsKey('Type')) {
                newCase.Type = String.valueOf(caseMap.get('Type'));
            }
            
            // Custom Type fields
            if (caseMap.containsKey('Type__c')) {
                newCase.Type__c = String.valueOf(caseMap.get('Type__c'));
            }
            if (caseMap.containsKey('Sub_Type__c')) {
                newCase.Sub_Type__c = String.valueOf(caseMap.get('Sub_Type__c'));
            }
            
            // Supplied fields (for web forms)
            if (caseMap.containsKey('SuppliedName')) {
                newCase.SuppliedName = String.valueOf(caseMap.get('SuppliedName'));
            }
            if (caseMap.containsKey('SuppliedEmail')) {
                newCase.SuppliedEmail = String.valueOf(caseMap.get('SuppliedEmail'));
            }
            if (caseMap.containsKey('SuppliedPhone')) {
                newCase.SuppliedPhone = String.valueOf(caseMap.get('SuppliedPhone'));
            }
            if (caseMap.containsKey('SuppliedCompany')) {
                newCase.SuppliedCompany = String.valueOf(caseMap.get('SuppliedCompany'));
            }
            
            // Lookup fields
            if (caseMap.containsKey('AccountId') && caseMap.get('AccountId') != null) {
                newCase.AccountId = Id.valueOf(String.valueOf(caseMap.get('AccountId')));
            }
            if (caseMap.containsKey('ContactId') && caseMap.get('ContactId') != null) {
                newCase.ContactId = Id.valueOf(String.valueOf(caseMap.get('ContactId')));
            }
            if (caseMap.containsKey('Group_Buy_Proposal__c') && caseMap.get('Group_Buy_Proposal__c') != null) {
                newCase.Group_Buy_Proposal__c = Id.valueOf(String.valueOf(caseMap.get('Group_Buy_Proposal__c')));
            }
            if (caseMap.containsKey('Order__c') && caseMap.get('Order__c') != null) {
                newCase.Order__c = Id.valueOf(String.valueOf(caseMap.get('Order__c')));
            }
            if (caseMap.containsKey('Conditional_Order__c') && caseMap.get('Conditional_Order__c') != null) {
                newCase.Conditional_Order__c = Id.valueOf(String.valueOf(caseMap.get('Conditional_Order__c')));
            }
            
            // Business fields (for Registration types)
            if (caseMap.containsKey('Business_Type__c')) {
                newCase.Business_Type__c = String.valueOf(caseMap.get('Business_Type__c'));
            }
            if (caseMap.containsKey('Tax_Id__c')) {
                newCase.Tax_Id__c = String.valueOf(caseMap.get('Tax_Id__c'));
            }
            if (caseMap.containsKey('Company_Registration_Number__c')) {
                newCase.Company_Registration_Number__c = String.valueOf(caseMap.get('Company_Registration_Number__c'));
            }
            if (caseMap.containsKey('Website__c')) {
                newCase.Website__c = String.valueOf(caseMap.get('Website__c'));
            }
            
            // Product fields (for New Product Approval)
            if (caseMap.containsKey('Product_Name__c')) {
                newCase.Product_Name__c = String.valueOf(caseMap.get('Product_Name__c'));
            }
            if (caseMap.containsKey('Proposed_Category__c')) {
                newCase.Proposed_Category__c = String.valueOf(caseMap.get('Proposed_Category__c'));
            }
            if (caseMap.containsKey('Proposed_Price__c') && caseMap.get('Proposed_Price__c') != null) {
                newCase.Proposed_Price__c = Decimal.valueOf(String.valueOf(caseMap.get('Proposed_Price__c')));
            }
            
            insert newCase;
            
            return [SELECT Id, CaseNumber, Subject, Status, Type__c, CreatedDate 
                    FROM Case WHERE Id = :newCase.Id LIMIT 1];
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating case: ' + e.getMessage());
        }
    }
    
    /**
     * @description Creates a Case for Proposal Approval request
     * @param proposalId Id of the Group_Buy_Proposal__c record
     * @param caseType Type of case: 'Merchandiser' or 'B2B_Buyer'
     * @return Created Case record
     */
    @AuraEnabled
    public static Case createProposalApprovalCase(Id proposalId, String caseType) {
        try {
            // Get proposal details
            Group_Buy_Proposal__c proposal = [
                SELECT Id, Name, Product__c, Product__r.Name, Account__c, Account__r.Name,
                       Account__r.OwnerId, Min_Quota__c, Max_Quota__c, Base_Price__c,
                       Start_Date__c, End_Date__c, Type__c, Status__c
                FROM Group_Buy_Proposal__c 
                WHERE Id = :proposalId 
                LIMIT 1
            ];
            
            // Determine case type and reason based on caseType parameter
            String typeValue;
            String reasonValue;
            String subjectPrefix;
            
            if (caseType == 'Merchandiser') {
                typeValue = 'New Product Approval';
                reasonValue = 'Proposal Approval Request';
                subjectPrefix = '[Merchandiser]';
            } else {
                typeValue = 'B2B Customer Registration';
                reasonValue = 'Business Group Onboarding';
                subjectPrefix = '[B2B Buyer]';
            }
            
            // Build description with proposal details
            String description = 'Proposal Approval Request\n\n' +
                'Proposal: ' + proposal.Name + '\n' +
                'Product: ' + (proposal.Product__r != null ? proposal.Product__r.Name : 'N/A') + '\n' +
                'Account: ' + (proposal.Account__r != null ? proposal.Account__r.Name : 'N/A') + '\n' +
                'Min Quota: ' + proposal.Min_Quota__c + '\n' +
                'Max Quota: ' + proposal.Max_Quota__c + '\n' +
                'Base Price: $' + proposal.Base_Price__c + '\n' +
                'Start Date: ' + (proposal.Start_Date__c != null ? proposal.Start_Date__c.format() : 'N/A') + '\n' +
                'End Date: ' + (proposal.End_Date__c != null ? proposal.End_Date__c.format() : 'N/A') + '\n' +
                'Payment Type: ' + proposal.Type__c;
            
            Case newCase = new Case(
                Subject = subjectPrefix + ' Proposal Approval: ' + proposal.Name,
                Description = description,
                Status = 'New',
                Priority = 'Medium',
                Type__c = typeValue,
                Reason = reasonValue,
                AccountId = proposal.Account__c,
                Group_Buy_Proposal__c = proposalId
            );
            
            insert newCase;
            
            // Update proposal status to Pending Approval
            proposal.Status__c = 'Pending Approval';
            update proposal;
            
            return [SELECT Id, CaseNumber, Subject, Status, Type__c, CreatedDate 
                    FROM Case WHERE Id = :newCase.Id LIMIT 1];
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating approval case: ' + e.getMessage());
        }
    }
    
    /**
     * @description Gets Case Types for picklist
     * @return List of picklist options
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCaseTypeOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        
        Schema.DescribeFieldResult fieldResult = Case.Type__c.getDescribe();
        List<Schema.PicklistEntry> entries = fieldResult.getPicklistValues();
        
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }
        
        return options;
    }
    
    /**
     * @description Gets Cases related to current user's account
     * @param accountId Account Id to filter cases
     * @return List of Case records
     */
    @AuraEnabled
    public static List<Case> getMyCases(Id accountId) {
        try {
            return [
                SELECT Id, CaseNumber, Subject, Status, Priority, Type__c, 
                       CreatedDate, ClosedDate, Description,
                       Group_Buy_Proposal__c, Group_Buy_Proposal__r.Name
                FROM Case 
                WHERE AccountId = :accountId
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching cases: ' + e.getMessage());
        }
    }
}
