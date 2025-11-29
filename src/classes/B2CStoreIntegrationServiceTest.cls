@IsTest
public with sharing class B2CStoreIntegrationServiceTest {
    @IsTest
    private static void test(){
        Account testAccount = new Account(Name='TestAccount');
        insert testAccount;
        WebStore testWebStore = new WebStore(Name='d2cstore', Type = 'B2C', DefaultLanguage='en_US', SupportedLanguages = 'en_US;de;fr' );
        insert testWebStore;

        // WebStore query values
        String webstoreName = 'd2cstore';

        // ApexClass query values
        String apexClassname = 'B2BTaxSample';
        String status = 'Active';
        Double apiVersion = 55.0;

        // RegisteredExternalService insert values
        String registeredProviderType = 'Tax';
        String registeredDevName = 'COMPUTE_Taxes';

        B2CStoreIntegrationService.registerApexClass(webstoreName, apexClassname, status, apiVersion, registeredProviderType, registeredDevName);
        B2CStoreIntegrationService.setStoreIntegration(webstoreName, apexClassname, status, apiVersion, registeredProviderType, registeredDevName);
    }

    @IsTest
    private static void testNonExistingStore(){
        // WebStore query values
        String webstoreName = 'TestStore';

        // ApexClass query values
        String apexClassname = 'B2BTaxSample';
        String status = 'Active';
        Double apiVersion = 55.0;

        // RegisteredExternalService insert values
        String registeredProviderType = 'Tax';
        String registeredDevName = 'COMPUTE_Taxes';

        B2CStoreIntegrationService.registerApexClass(webstoreName, apexClassname, status, apiVersion, registeredProviderType, registeredDevName);
        B2CStoreIntegrationService.setStoreIntegration(webstoreName, apexClassname, status, apiVersion, registeredProviderType, registeredDevName);
    }

    @IsTest
    private static void testNonExistingClass(){
        Account testAccount = new Account(Name='TestAccount');
        insert testAccount;
        WebStore testWebStore = new WebStore(Name='d2cstore', Type = 'B2C', DefaultLanguage='en_US', SupportedLanguages = 'en_US;de;fr' );
        insert testWebStore;

        // WebStore query values
        String webstoreName = 'd2cstore';

        // ApexClass query values
        String apexClassname = 'TestClass';
        String status = 'Active';
        Double apiVersion = 50.0;

        // RegisteredExternalService insert values
        String registeredProviderType = 'Shipment';
        String registeredDevName = 'COMPUTE_Shipping';

        B2CStoreIntegrationService.registerApexClass(webstoreName, apexClassname, status, apiVersion, registeredProviderType, registeredDevName);
        B2CStoreIntegrationService.setStoreIntegration(webstoreName, apexClassname, status, apiVersion, registeredProviderType, registeredDevName);
    }

    @IsTest
    private static void testNonExistingProviderType(){
        Account testAccount = new Account(Name='TestAccount');
        insert testAccount;
        WebStore testWebStore = new WebStore(Name='d2cstore', Type = 'B2C', DefaultLanguage='en_US', SupportedLanguages = 'en_US;de;fr' );
        insert testWebStore;

        // WebStore query values
        String webstoreName = 'd2cstore';

        // ApexClass query values
        String apexClassname = 'B2BTaxSample';
        String status = 'Active';
        Double apiVersion = 55.0;

        // RegisteredExternalService insert values
        String registeredProviderType = 'TestTax';
        String registeredDevName = 'COMPUTE_Taxes';

        B2CStoreIntegrationService.registerApexClass(webstoreName, apexClassname, status, apiVersion, registeredProviderType, registeredDevName);
        B2CStoreIntegrationService.setStoreIntegration(webstoreName, apexClassname, status, apiVersion, registeredProviderType, registeredDevName);
    }

}