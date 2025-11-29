public with sharing class ProductCategorySingleCategoryInvocable {
    private static final String PRODUCT_API_NAME = 'Product2';
    private static String productQuery;
    @InvocableMethod(Label = 'ZERMP Assign Products to Single Category' Description = 'ZERMP Assign Products to Single Category')
    public static List<ProductCategorySingleCategoryInvocableOutput> assignProductsToSingleCategory(List<ProductCategory> productCategory){
        List<ProductCategorySingleCategoryInvocableOutput> result = new List<ProductCategorySingleCategoryInvocableOutput>();

        if(productCategory == null || productCategory.isEmpty()){
            System.debug(LoggingLevel.ERROR, 'productCategory is null!');
            return result;
        }

        productQuery = 'SELECT Primary_Category_Static__c, ';

        List<Product_Category_Condition__c> productCategoryConditions = [SELECT Product_Field_Name__c FROM Product_Category_Condition__c LIMIT 50000];
        Set<String> distinctFields = new Set<String>();
        for(Product_Category_Condition__c productCategoryCondition: productCategoryConditions){
            distinctFields.add(productCategoryCondition.Product_Field_Name__c);
        }

        for(String distinctField: distinctFields){
            productQuery += distinctField + ',';
        }

        productQuery = productQuery.removeEnd(',');

        productQuery += ' FROM ' + PRODUCT_API_NAME + ' WHERE Primary_Category_Static__c = false';
        System.debug(LoggingLevel.DEBUG, 'productQuery: ' + productQuery);

        String jobId = Database.executeBatch(new ProductCategoryAssignerBatch(productQuery, productCategory.get(0)));

        result.add(new ProductCategorySingleCategoryInvocableOutput(jobId, Url.getSalesforceBaseUrl().toExternalForm()));
        return result;
    }

    public class ProductCategorySingleCategoryInvocableOutput {
        @InvocableVariable
        public String jobId;
        @InvocableVariable
        public String sfdcBaseUrl;

        public ProductCategorySingleCategoryInvocableOutput(String jobId, String sfdcBaseUrl){
            this.jobId = jobId;
            this.sfdcBaseUrl = sfdcBaseUrl;
        }
    }
}