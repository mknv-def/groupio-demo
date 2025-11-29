@IsTest
public with sharing class B2BTaxSampleTest {
    @IsTest
    private static void test(){
        B2BTaxSample b2BTaxSample = new B2BTaxSample();

        Test.startTest();
        sfdc_checkout.IntegrationStatus integrationResult = b2BTaxSample.startCartProcessAsync(null, null);
        Test.stopTest();

        System.assertEquals(sfdc_checkout.IntegrationStatus.Status.SUCCESS, integrationResult.status);
    }
}