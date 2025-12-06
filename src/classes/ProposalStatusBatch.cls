/**
 * ProposalStatusBatch
 * Batch job to process Group Buy Proposal status transitions
 * 
 * Actions:
 * 1. Activate approved proposals when Start_Date__c <= NOW()
 * 2. Expire active proposals when End_Date__c < NOW() and Min_Quota not reached
 * 3. Close active proposals when End_Date__c < NOW() and Min_Quota reached
 * 4. Confirm pending orders when proposal is closed
 * 5. Send notifications (via Platform Events for Flow processing)
 */
public class ProposalStatusBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    // Track statistics
    private Integer activatedCount = 0;
    private Integer expiredCount = 0;
    private Integer closedCount = 0;
    private Integer ordersConfirmedCount = 0;
    private List<String> errors = new List<String>();
    
    public Database.QueryLocator start(Database.BatchableContext ctx) {
        // Query proposals that need status updates
        return Database.getQueryLocator([
            SELECT Id, Name, Status__c, Start_Date__c, End_Date__c,
                   Min_Quota__c, Max_Quota__c, Booked_Quota__c,
                   Is_Min_Quota_Reached__c, Product__r.Name,
                   Account__c, Account__r.Name,
                   (SELECT Id, Status__c, Quantity__c, Account__c 
                    FROM Conditional_Orders__r 
                    WHERE Status__c = 'Pending')
            FROM Group_Buy_Proposal__c
            WHERE Status__c IN ('Approved', 'Active')
        ]);
    }
    
    public void execute(Database.BatchableContext ctx, List<Group_Buy_Proposal__c> proposals) {
        List<Group_Buy_Proposal__c> proposalsToUpdate = new List<Group_Buy_Proposal__c>();
        List<Conditional_Order__c> ordersToConfirm = new List<Conditional_Order__c>();
        List<Proposal_Status_Event__e> events = new List<Proposal_Status_Event__e>();
        
        DateTime now = DateTime.now();
        
        for (Group_Buy_Proposal__c proposal : proposals) {
            String originalStatus = proposal.Status__c;
            Boolean needsUpdate = false;
            
            // CASE 1: Activate approved proposals when start date is reached
            if (proposal.Status__c == 'Approved' && proposal.Start_Date__c <= now) {
                proposal.Status__c = 'Active';
                proposal.Activated_Date__c = now;
                needsUpdate = true;
                activatedCount++;
                
                // Create event for flow/notification
                events.add(createEvent(proposal.Id, 'ACTIVATED', proposal.Name, 
                    'Proposal is now active and accepting orders.'));
            }
            
            // CASE 2 & 3: Process active proposals past end date
            else if (proposal.Status__c == 'Active' && proposal.End_Date__c < now) {
                
                // Check if minimum quota was reached
                Boolean minQuotaReached = proposal.Booked_Quota__c >= proposal.Min_Quota__c;
                
                if (minQuotaReached) {
                    // CLOSE - Success! Min quota reached
                    proposal.Status__c = 'Closed';
                    proposal.Closed_Date__c = now;
                    needsUpdate = true;
                    closedCount++;
                    
                    // Confirm all pending orders
                    for (Conditional_Order__c order : proposal.Conditional_Orders__r) {
                        if (order.Status__c == 'Pending') {
                            order.Status__c = 'Confirmed';
                            order.Confirmed_Date__c = now;
                            ordersToConfirm.add(order);
                            ordersConfirmedCount++;
                        }
                    }
                    
                    events.add(createEvent(proposal.Id, 'CLOSED', proposal.Name,
                        'Proposal successfully closed. ' + proposal.Booked_Quota__c + ' units ordered.'));
                    
                } else {
                    // EXPIRE - Min quota not reached
                    proposal.Status__c = 'Expired';
                    proposal.Closed_Date__c = now;
                    needsUpdate = true;
                    expiredCount++;
                    
                    // Note: Orders remain as Pending - they should be cancelled
                    // This could be handled by a flow or additional logic
                    
                    events.add(createEvent(proposal.Id, 'EXPIRED', proposal.Name,
                        'Proposal expired without reaching minimum quota. ' + 
                        proposal.Booked_Quota__c + '/' + proposal.Min_Quota__c + ' units.'));
                }
            }
            
            if (needsUpdate) {
                proposalsToUpdate.add(proposal);
            }
        }
        
        // Perform DML operations
        try {
            if (!proposalsToUpdate.isEmpty()) {
                update proposalsToUpdate;
            }
            
            if (!ordersToConfirm.isEmpty()) {
                update ordersToConfirm;
            }
            
            // Publish platform events for flow-based notifications
            if (!events.isEmpty()) {
                EventBus.publish(events);
            }
            
        } catch (Exception e) {
            errors.add('Error in batch execute: ' + e.getMessage());
        }
    }
    
    public void finish(Database.BatchableContext ctx) {
        // Log results
        System.debug('ProposalStatusBatch completed:');
        System.debug('- Proposals Activated: ' + activatedCount);
        System.debug('- Proposals Closed: ' + closedCount);
        System.debug('- Proposals Expired: ' + expiredCount);
        System.debug('- Orders Confirmed: ' + ordersConfirmedCount);
        
        if (!errors.isEmpty()) {
            System.debug('- Errors: ' + String.join(errors, '; '));
        }
        
        // Optionally send summary email to admin
        if (activatedCount > 0 || closedCount > 0 || expiredCount > 0) {
            sendSummaryEmail();
        }
    }
    
    /**
     * Create a platform event for flow processing
     */
    private Proposal_Status_Event__e createEvent(Id proposalId, String eventType, 
                                                   String proposalName, String message) {
        return new Proposal_Status_Event__e(
            Proposal_Id__c = proposalId,
            Event_Type__c = eventType,
            Proposal_Name__c = proposalName,
            Message__c = message,
            Event_Time__c = DateTime.now()
        );
    }
    
    /**
     * Send summary email to system admin
     */
    private void sendSummaryEmail() {
        try {
            // Get admin user email (you might want to use a custom setting/label)
            String adminEmail = [SELECT Email FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1].Email;
            
            if (String.isBlank(adminEmail)) return;
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { adminEmail });
            mail.setSubject('GroupIO Daily Proposal Status Update');
            
            String body = 'Daily Proposal Status Update Summary\n\n';
            body += 'Proposals Activated: ' + activatedCount + '\n';
            body += 'Proposals Closed (Success): ' + closedCount + '\n';
            body += 'Proposals Expired: ' + expiredCount + '\n';
            body += 'Orders Confirmed: ' + ordersConfirmedCount + '\n';
            
            if (!errors.isEmpty()) {
                body += '\nErrors:\n' + String.join(errors, '\n');
            }
            
            body += '\n\nThis is an automated message from GroupIO System.';
            
            mail.setPlainTextBody(body);
            
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
        } catch (Exception e) {
            System.debug('Error sending summary email: ' + e.getMessage());
        }
    }
}
