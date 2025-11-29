/**
 * @description Get current community user's Account and Contact
 */
public with sharing class CommunityUserContext {

    /**
     * @description Get current user's contact and account info
     * @return UserContext wrapper with user, contact, and account data
     */
    @AuraEnabled(cacheable=true)
    public static UserContext getCurrentUserContext() {
        UserContext ctx = new UserContext();

        // Get current user with ContactId
        ctx.currentUser = [
                SELECT Id, Name, Email, Username, ContactId, AccountId,
                        Profile.Name, UserType
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
        ];

        // For community users, ContactId is populated
        if (ctx.currentUser.ContactId != null) {
            ctx.contact = [
                    SELECT Id, Name, FirstName, LastName, Email, Phone,
                            AccountId, Account.Name, Account.AccountNumber,
                            Account.BillingCity, Account.BillingCountry
                    FROM Contact
                    WHERE Id = :ctx.currentUser.ContactId
                    LIMIT 1
            ];

            // Get full Account record with more details
            if (ctx.contact.AccountId != null) {
                ctx.account = [
                        SELECT Id, Name, AccountNumber, Type, Industry,
                                BillingStreet, BillingCity, BillingState,
                                BillingPostalCode, BillingCountry,
                                ShippingStreet, ShippingCity, ShippingState,
                                ShippingPostalCode, ShippingCountry
                        FROM Account
                        WHERE Id = :ctx.contact.AccountId
                        LIMIT 1
                ];
            }
        }
        // For portal users, AccountId might be directly on User
        else if (ctx.currentUser.AccountId != null) {
            ctx.account = [
                    SELECT Id, Name, AccountNumber, Type, Industry,
                            BillingStreet, BillingCity, BillingState,
                            BillingPostalCode, BillingCountry
                    FROM Account
                    WHERE Id = :ctx.currentUser.AccountId
                    LIMIT 1
            ];
        }

        return ctx;
    }

    /**
     * @description Quick method to get just the Account ID
     * @return Account ID of current community user
     */
    @AuraEnabled(cacheable=true)
    public static Id getCurrentUserAccountId() {
        User currentUser = [
                SELECT ContactId, AccountId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
        ];

        // Try ContactId first (most common for community users)
        if (currentUser.ContactId != null) {
            Contact c = [SELECT AccountId FROM Contact WHERE Id = :currentUser.ContactId LIMIT 1];
            return c.AccountId;
        }

        // Fall back to direct AccountId
        return currentUser.AccountId;
    }

    /**
     * @description Wrapper class for user context data
     */
    public class UserContext {
        @AuraEnabled public User currentUser { get; set; }
        @AuraEnabled public Contact contact { get; set; }
        @AuraEnabled public Account account { get; set; }
    }
}