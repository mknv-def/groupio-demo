public with sharing class ProductCategoryAssignerBatch implements Database.Batchable<SObject>, Database.Stateful{
    private static final String PRODUCT_API_NAME = 'Product2';

    private String query;
    private ProductCategory productCategory;
    private Boolean queueable = false;
    private List<String> picklistFieldApiNames = new List<String>();

    public Map<String, Map<String, Boolean>> fieldValueMap = new Map<String, Map<String, Boolean>>();

    public ProductCategoryAssignerBatch(String query){
        this.query = query;
    }

    public ProductCategoryAssignerBatch(String query, ProductCategory productCategory){
        this.query = query;
        this.productCategory = productCategory;
    }

    public ProductCategoryAssignerBatch(String query, ProductCategory productCategory, Boolean queueable, List<String> picklistFieldApiNames){
        this.query = query;
        this.productCategory = productCategory;
        this.queueable = queueable;
        this.picklistFieldApiNames = picklistFieldApiNames;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(this.query);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope){
        if(this.queueable){
            List<Product2> products = (List<Product2>) scope;

            for(Product2 product: products){
                for(String picklistFieldApiName: this.picklistFieldApiNames){
                    String picklistFieldMetadataApiName = PRODUCT_API_NAME + '.' + picklistFieldApiName;
                    Map<String, Boolean> activation = new Map<String, Boolean>();
                    if(this.fieldValueMap.containsKey(picklistFieldMetadataApiName)) {
                        activation = this.fieldValueMap.get(picklistFieldMetadataApiName);
                    }

                    String picklistValueFromRecord = String.valueOf(product.get(picklistFieldApiName));
                    if(String.isNotBlank(picklistValueFromRecord)){
                        List<String> picklistValues = picklistValueFromRecord.contains(';') ? picklistValueFromRecord.split(';') : new List<String>{picklistValueFromRecord};
                        if(!picklistValues.isEmpty()){
                            for(String picklistValue: picklistValues){
                                activation.put(picklistValue, true);
                            }
                        }
                    }
                    if(!activation.isEmpty()){
                        this.fieldValueMap.put(picklistFieldMetadataApiName, activation);
                    }
                }
            }
        }
        if(this.productCategory != null){
            ProductCategoriesService.handleProductCategories((List<Product2>)scope, this.productCategory);
        }
        else{
            ProductCategoriesService.handleProductCategories((List<Product2>)scope);
        }
    }

    public void finish(Database.BatchableContext bc){
        System.debug(LoggingLevel.INFO, 'ProductCategory assignment batch job is complete!');
    }
}