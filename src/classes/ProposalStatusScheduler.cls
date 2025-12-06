/**
 * ProposalStatusScheduler
 * Scheduled job to manage Group Buy Proposal status transitions
 * 
 * Schedule daily at midnight:
 * System.schedule('Daily Proposal Status Update', '0 0 0 * * ?', new ProposalStatusScheduler());
 * 
 * Or schedule every hour:
 * System.schedule('Hourly Proposal Status Update', '0 0 * * * ?', new ProposalStatusScheduler());
 */
public class ProposalStatusScheduler implements Schedulable {
    
    public void execute(SchedulableContext ctx) {
        // Execute the batch job
        Database.executeBatch(new ProposalStatusBatch(), 200);
    }
    
    /**
     * Helper method to schedule the job
     * Call from Anonymous Apex: ProposalStatusScheduler.scheduleDaily();
     */
    public static void scheduleDaily() {
        // Run daily at 12:05 AM
        String cronExp = '0 5 0 * * ?';
        System.schedule('Daily Proposal Status Update', cronExp, new ProposalStatusScheduler());
    }
    
    /**
     * Schedule hourly for more frequent updates
     */
    public static void scheduleHourly() {
        String cronExp = '0 0 * * * ?';
        System.schedule('Hourly Proposal Status Update', cronExp, new ProposalStatusScheduler());
    }
    
    /**
     * Remove scheduled job
     */
    public static void unschedule() {
        for (CronTrigger ct : [SELECT Id, CronJobDetail.Name 
                               FROM CronTrigger 
                               WHERE CronJobDetail.Name LIKE '%Proposal Status Update%']) {
            System.abortJob(ct.Id);
        }
    }
}
