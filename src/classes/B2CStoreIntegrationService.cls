// Sample of this class was provided at https://developer.salesforce.com/docs/atlas.en-us.b2b_b2c_comm_dev.meta/b2b_b2c_comm_dev/b2b_b2c_comm_integration_setup.htm
public with sharing class B2CStoreIntegrationService {
    public static void registerApexClass(String webstoreName, String apexClassname, String status, Double apiVersion, String registeredProviderType, String registeredDevName){
        try{
            String registeredLabel = registeredDevName;

            // locate webstore
            List<WebStore> webStores = [SELECT Id FROM WebStore WHERE Name = :webstoreName LIMIT 1];
            if(webStores.isEmpty()){
                return;
            }

            // locate apex class Id
            List<ApexClass> apexClasses = [SELECT Id FROM ApexClass WHERE Status=:status AND ApiVersion=:apiVersion AND Name=:apexClassname LIMIT 1];
            if(apexClasses.isEmpty()){
                return;
            }
            String apexClassId = apexClasses.get(0).Id;
            System.debug(LoggingLevel.DEBUG, 'apexClassId:' + apexClassId);


            // locate apex in RegisteredExternalService
            List<RegisteredExternalService> registeredExternalServices = [SELECT Id FROM RegisteredExternalService WHERE ExternalServiceProviderId=:apexClassId AND DeveloperName=:registeredDevName AND ExternalServiceProviderType=:registeredProviderType LIMIT 1];
            if(!registeredExternalServices.isEmpty()){
                String registeredIntegrationId = String.valueOf(registeredExternalServices.get(0).Id);
                System.debug(LoggingLevel.DEBUG, 'apex class registration: FOUND ' + registeredIntegrationId);
                delete registeredExternalServices; // optionally remove if needed
            }

            insert new RegisteredExternalService(DeveloperName = registeredDevName, MasterLabel = registeredLabel, ExternalServiceProviderId = apexClassId, ExternalServiceProviderType = registeredProviderType);
            RegisteredExternalService registeredExternalService =[SELECT Id FROM RegisteredExternalService WHERE ExternalServiceProviderId = :apexClassId  LIMIT 1];
            String registeredIntegrationId = registeredExternalService.Id;
            System.debug(LoggingLevel.DEBUG, 'apex class registration: INSERTED ' + registeredIntegrationId);
        }
        catch(Exception e){
            System.debug(LoggingLevel.ERROR, 'An error occurred. ' + e.getMessage() + '. ' + e.getStackTraceString());
        }
    }
    public static void setStoreIntegration(String webstoreName, String apexClassname, String status, Double apiVersion, String registeredProviderType, String registeredDevName){
        try{
            // StoreIntegratedService insert values
            String devname = registeredDevName;
            String prefix = registeredProviderType;
            String prefixedName = prefix + '__' + devname;

            // locate webstore
            List<WebStore> webStores = [SELECT Id FROM WebStore WHERE Name = :webstoreName LIMIT 1];
            if(webStores.isEmpty()){
                return;
            }
            String webStoreId = webStores.get(0).Id;
            System.debug(LoggingLevel.DEBUG, 'webStoreId:' + webStoreId);

            // locate apex class Id
            List<ApexClass> apexClasses = [SELECT Id FROM ApexClass WHERE Status=:status AND ApiVersion=:apiVersion AND Name=:apexClassname LIMIT 1];
            if(apexClasses.isEmpty()){
                return;
            }
            String apexClassId = apexClasses.get(0).Id;
            System.debug(LoggingLevel.DEBUG, 'apexClassId:' + apexClassId);

            // locate apex in RegisteredExternalService
            List<RegisteredExternalService> registeredExternalServices = [SELECT Id FROM RegisteredExternalService WHERE ExternalServiceProviderId=:apexClassId AND DeveloperName=:registeredDevName AND ExternalServiceProviderType=:registeredProviderType LIMIT 1];
            if(registeredExternalServices.isEmpty()){
                return;
            }
            String registeredIntegrationId = registeredExternalServices.get(0).Id;
            System.debug(LoggingLevel.DEBUG, 'apex registration:' + registeredIntegrationId);

            // locate and map in StoreIntegratedService
            List<StoreIntegratedService> registeredMappingObjs = [SELECT Id FROM StoreIntegratedService WHERE Integration=:prefixedName AND ServiceProviderType=:prefix AND StoreId=:webStoreId LIMIT 1];
            System.debug(LoggingLevel.DEBUG, 'registered class mapping: FOUND ' + registeredMappingObjs);

            if(!registeredMappingObjs.isEmpty()){
                delete registeredMappingObjs; // optionally remove if needed
            }
            else{
                System.debug(LoggingLevel.DEBUG, 'registered class mapping: MISSING ' + prefixedName);
                insert new StoreIntegratedService(Integration = prefixedName, ServiceProviderType = prefix, StoreId = webStoreId);
                registeredMappingObjs = [SELECT Id FROM StoreIntegratedService WHERE Integration=:prefixedName AND ServiceProviderType=:prefix AND StoreId=:webStoreId LIMIT 1];
                System.debug(LoggingLevel.DEBUG, 'registered class mapping: INSERTED ' + registeredMappingObjs);
            }
        }
        catch(Exception e){
            System.debug(LoggingLevel.ERROR, 'An error occurred. ' + e.getMessage() + '. ' + e.getStackTraceString());
        }
    }
}