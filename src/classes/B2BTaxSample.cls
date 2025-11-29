// This is a dummy class handles the "Tax Integration" of the D2C store
// This class is provided by Salesforce at https://github.com/forcedotcom/b2b-commerce-on-lightning-quickstart/tree/master/examples/checkout/integrations/classes
global with sharing class B2BTaxSample implements sfdc_checkout.CartTaxCalculations {
    global sfdc_checkout.IntegrationStatus startCartProcessAsync(sfdc_checkout.IntegrationInfo jobInfo, Id cartId) {
        sfdc_checkout.IntegrationStatus integStatus = new sfdc_checkout.IntegrationStatus();
        integStatus.status = sfdc_checkout.IntegrationStatus.Status.SUCCESS;
        return integStatus;
    }
}