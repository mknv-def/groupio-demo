public with sharing class ProductCategoriesService {

    private static final String OPERATION_INCLUDED = 'Included';
    private static final String OPERATION_EQUALS = 'Equals';
    private static final String OPERATION_DOES_NOT_EQUALS = 'Does not Equal';

    private static final String FIELD_TYPE_STRING = 'String';
    private static final String FIELD_TYPE_BOOLEAN = 'Boolean';
    private static final String FIELD_TYPE_PICKLIST = 'Picklist-Multiselect';

    private static final String CATEGORY_CONDITION_PROCESSING_LOGIC_AND = 'AND';
    private static final String CATEGORY_CONDITION_PROCESSING_LOGIC_OR = 'OR';

    private static final String CATEGORY_INCLUDE_LOGIC_AND = 'AND';
    private static final String CATEGORY_INCLUDE_LOGIC_OR = 'OR';

    public static Boolean testException = false;
    public static String testCategoryConditionProcessingLogic = CATEGORY_CONDITION_PROCESSING_LOGIC_AND;
    public static String testCategoryIncludeLogic = CATEGORY_INCLUDE_LOGIC_OR;



    public static void handleProductCategories( List<Product2> products ) {
        handleProductCategories(products, null);
    }

    public static void handleProductCategories(List<Product2> products, ProductCategory productCategory){
        try{
            if(testException){
                throw new CalloutException();
            }
            List<ProductCategoryProduct> outdatedCategoriesList = new List<ProductCategoryProduct>();
            List<ProductCategoryProduct> newCategoriesToAssignList = new List<ProductCategoryProduct>();
            List<ProductCategoryTuple> productCategoryTuplesToRemove = new List<ProductCategoryTuple>();

            Map<Id, Product2> productMap = new Map<Id, Product2>( products );
            Map<Id, ProductCategoryProduct> productCategoryProducts = new Map<Id, ProductCategoryProduct>([SELECT Id, ProductCategoryId, ProductId, IsPrimaryCategory FROM ProductCategoryProduct WHERE ProductId IN :productMap.keySet()]);
            Map<Id, ProductCategory> categoriesWithConditionsMap = new Map<Id, ProductCategory>();
            if(productCategory != null){
                categoriesWithConditionsMap = getCategoriesWithConditions(productCategory);
            }
            else{
                categoriesWithConditionsMap = getCategoriesWithConditions();
            }

            if(categoriesWithConditionsMap.isEmpty()){
                System.debug(LoggingLevel.INFO, 'Input categories have no conditions.');
                return;
            }

            Map<Id, Set<Id>> productIdsToExistingCategoryIdsMap = getProductIdToExistingCategoryIdsMap( productCategoryProducts.values() );
            String categoryConditionProcessingLogic = testCategoryConditionProcessingLogic;
            String categoryIncludeProcessingLogic = testCategoryIncludeLogic;
            List<ProductCategoryProduct> junctionsToSetAsPrimary = new List<ProductCategoryProduct>();

            for( Product2 curProduct : products ) {
                Set<Id> validCategoryIdsForProduct = getValidCategoryIdsForProduct( curProduct, categoriesWithConditionsMap.values(), testCategoryConditionProcessingLogic, categoryIncludeProcessingLogic );
                Set<Id> existingProductCategoryIds = productIdsToExistingCategoryIdsMap.get( curProduct.Id ) != null ? productIdsToExistingCategoryIdsMap.get( curProduct.Id ) : new Set<Id>();

                productCategoryTuplesToRemove.addAll( getProductCategoryTuplesToRemove( curProduct, validCategoryIdsForProduct, existingProductCategoryIds ) );

                Set<Id> newCategoriesToAssignIds = getNewCategoryIdsToAssign( validCategoryIdsForProduct, existingProductCategoryIds );

                newCategoriesToAssignList.addAll( getProductCategoryProductToCreate( curProduct.Id, newCategoriesToAssignIds ) );
            }

            outdatedCategoriesList.addAll( getOutdatedCategoryJunctions( productCategoryTuplesToRemove, productCategoryProducts.values(), productCategory ) );

            if( !outdatedCategoriesList.isEmpty() ) {
                delete outdatedCategoriesList;
            }

            if( !newCategoriesToAssignList.isEmpty() ) {
                Database.SaveResult[] results = Database.insert( newCategoriesToAssignList, false );
                String errorMessage = '';
                for( Integer i = 0; i < results.size(); i++ ) {
                    if( !results[i].isSuccess() ) {
                        for( Database.Error error : results[i].getErrors() ) {
                            System.debug( error.getMessage() );
                            errorMessage += 'Error inserting record: ' + error.getMessage() + '\n';
                        }
                    }
                }

                if( !String.isBlank( errorMessage ) ) {
                    System.debug('ProductCategoriesService: \n' + errorMessage );
                }
            }

            if( !junctionsToSetAsPrimary.isEmpty() ) {
                Database.SaveResult[] results = Database.update( junctionsToSetAsPrimary, false );
            }
        }
        catch ( Exception e ) {
            String errorMessage = 'An error occurred while assigning products to categories. ' + e.getMessage() + '. ' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, errorMessage);
        }
    }

    private static Map<Id, ProductCategory> getCategoriesWithConditions() {
        return getCategoriesWithConditions(null);
    }

    private static Map<Id, ProductCategory> getCategoriesWithConditions(ProductCategory productCategory){
        List<ProductCategory> result = new List<ProductCategory>();
        List<ProductCategory> categories = new List<ProductCategory>();
        if(productCategory != null){
            categories = [SELECT Id, Name, ( SELECT Category__c, Field_Type__c, Operation__c, Product_Field_Name__c, Values__c FROM Product_Category_Conditions__r ) FROM ProductCategory WHERE Id=:productCategory.Id ORDER BY SortOrder];
        }
        else{
            categories = [SELECT Id, Name, ( SELECT Category__c, Field_Type__c, Operation__c, Product_Field_Name__c, Values__c FROM Product_Category_Conditions__r ) FROM ProductCategory ORDER BY SortOrder];
        }

        for( ProductCategory curCategory : categories ) {
            List<Product_Category_Condition__c> categoryConditions = curCategory.Product_Category_Conditions__r;
            if( categoryConditions != null && !categoryConditions.isEmpty() ) {
                result.add( curCategory );
            }
        }
        return new Map<Id, ProductCategory> ( result );
    }

    private static Map<Id, Set<Id>> getProductIdToExistingCategoryIdsMap( List<ProductCategoryProduct> junctionList ) {
        Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();
        for( ProductCategoryProduct curRecord : junctionList ) {
            if( !result.containsKey( curRecord.ProductId ) ) {
                result.put( curRecord.ProductId, new Set<Id>() );
            }
            result.get( curRecord.ProductId ).add( curRecord.ProductCategoryId );
        }
        return result;
    }

    private static Map<Id, List<ProductCategoryProduct>> getProductIdToExistingCategoryJunctionsMap( List<ProductCategoryProduct> junctionList ) {
        Map<Id, List<ProductCategoryProduct>> result = new Map<Id, List<ProductCategoryProduct>>();
        for( ProductCategoryProduct curRecord : junctionList ) {
            if( !result.containsKey( curRecord.ProductId ) ) {
                result.put( curRecord.ProductId, new List<ProductCategoryProduct>() );
            }
            result.get( curRecord.ProductId ).add( curRecord );
        }
        return result;
    }


    private static Set<Id> getValidCategoryIdsForProduct( Product2 targetProduct, List<ProductCategory> categoriesWithConditions, String categoryConditionProcessingLogic, String categoryIncludeProcessingLogic) {
        Set<Id> validCategoryIds = new Set<Id>();
        for( ProductCategory curCategory : categoriesWithConditions ) {
            if(CATEGORY_CONDITION_PROCESSING_LOGIC_AND.equalsIgnoreCase(categoryConditionProcessingLogic)){
                if( isAllConditionsValid( curCategory.Product_Category_Conditions__r, targetProduct, categoryIncludeProcessingLogic ) ) {
                    validCategoryIds.add( curCategory.Id );
                }
            }
            else if(CATEGORY_CONDITION_PROCESSING_LOGIC_OR.equalsIgnoreCase(categoryConditionProcessingLogic)){
                if( isAnyConditionValid( curCategory.Product_Category_Conditions__r, targetProduct, categoryIncludeProcessingLogic ) ) {
                    validCategoryIds.add( curCategory.Id );
                }
            }
        }
        return validCategoryIds;
    }

    private static List<ProductCategoryTuple> getProductCategoryTuplesToRemove( Product2 currentProduct, Set<Id> validCategoryIds, Set<Id> existingProductCategoryIds ){
        List<ProductCategoryTuple> result = new List<ProductCategoryTuple>();
        Set<Id> categoriesToRemove = new Set<Id>();
        categoriesToRemove.addAll( existingProductCategoryIds );
        categoriesToRemove.removeAll( validCategoryIds );

        for(Id categoryId: categoriesToRemove){
            ProductCategoryTuple tuple = new ProductCategoryTuple(currentProduct.Id, categoryId);
            result.add(tuple);
        }
        return result;
    }

    //Method returns Ids of categories that are valid for product but not exist in system. This is categories to add
    private static Set<Id> getNewCategoryIdsToAssign( Set<Id> validCategoryIds, Set<Id> existingProductCategoryIds ) {
        Set<Id> result = new Set<Id>();
        result.addAll( validCategoryIds );
        result.removeAll( existingProductCategoryIds );
        return result;
    }

    private static List<ProductCategoryProduct> getProductCategoryProductToCreate( Id productId, Set<Id> categoryToAssignIds ) {
        List<ProductCategoryProduct> result = new List<ProductCategoryProduct>();
        for( Id curCategoryId : categoryToAssignIds ) {
            ProductCategoryProduct newJunction = new ProductCategoryProduct(
                ProductId = productId,
                ProductCategoryId = curCategoryId
            );

            result.add( newJunction );
        }
        return result;
    }

    private static List<ProductCategoryProduct> getOutdatedCategoryJunctions( List<ProductCategoryTuple> productCategoryTuplesToRemove, List<ProductCategoryProduct> allProductToCategoryJunctions, ProductCategory productCategory ) {
        List<ProductCategoryProduct> result = new List<ProductCategoryProduct>();
        for( ProductCategoryProduct curJunction : allProductToCategoryJunctions ) {
            for(ProductCategoryTuple productCategoryTuple: productCategoryTuplesToRemove){
                if(productCategory == null && curJunction.ProductCategoryId == productCategoryTuple.categoryId && curJunction.ProductId == productCategoryTuple.productId){
                    result.add( curJunction );
                }
                else if(productCategory != null && productCategory.Id == curJunction.ProductCategoryId && curJunction.ProductCategoryId == productCategoryTuple.categoryId && curJunction.ProductId == productCategoryTuple.productId){
                    result.add( curJunction );
                }
            }
        }
        return result;
    }
    private static Boolean isAnyConditionValid( List<Product_Category_Condition__c> conditions, Product2 productRecord, String categoryIncludeProcessingLogic ) {
        for( Product_Category_Condition__c curCondition : conditions ) {
            if( isConditionValid( curCondition, productRecord, categoryIncludeProcessingLogic ) ) {
                return true;
            }
        }

        return false;
    }

    private static Boolean isAllConditionsValid( List<Product_Category_Condition__c> conditions, Product2 productRecord, String categoryIncludeProcessingLogic ) {
        Boolean isAllConditionsValid = true;
        for( Product_Category_Condition__c curCondition : conditions ) {
            if( !isConditionValid( curCondition, productRecord, categoryIncludeProcessingLogic ) ) {
                isAllConditionsValid = false;
            }
        }
        return isAllConditionsValid;
    }

    private static Boolean isConditionValid( Product_Category_Condition__c condition, Product2 productRecord, String categoryIncludeProcessingLogic ) {
        String fieldApiName = String.escapeSingleQuotes( condition.Product_Field_Name__c );
        if( condition.Operation__c == OPERATION_INCLUDED ) {
            Set<String> values = String.isNotBlank( condition.Values__c ) ? new Set<String>(condition.Values__c.replaceAll('\\s*;\\s*', ';').split(';')) : new Set<String>();
            if( values.isEmpty() ) {
                return false;
            }

            Set<String> newOptionsSet = String.isNotBlank( String.valueOf( productRecord?.get( condition.Product_Field_Name__c ) ) ) ? new Set<String>( ( String.valueOf( productRecord?.get( condition.Product_Field_Name__c ) ) ).split(';') ) : new Set<String>();
            if( newOptionsSet.isEmpty() ) {
                return false;
            }
            return isValueIncluded( condition.Field_Type__c, values, newOptionsSet, categoryIncludeProcessingLogic );
        } else if( condition.Operation__c == OPERATION_EQUALS ) {
            return isValuesEquals( condition.Values__c, productRecord.get( fieldApiName ) );
        } else if( condition.Operation__c == OPERATION_DOES_NOT_EQUALS ) {
            return isValuesDoesNotEqual( condition.Values__c, productRecord.get( condition.Product_Field_Name__c ) );
        } else {
            System.debug(LoggingLevel.WARN, 'Invalid Operation__c type "' + condition.Operation__c + '"!');
            return false;
        }
    }

    private static Boolean isValueIncluded( String fieldType, Set<String> values, Set<String> newOptionsSet, String categoryIncludeProcessingLogic ) {
        if(FIELD_TYPE_STRING.equalsIgnoreCase(fieldType) || CATEGORY_INCLUDE_LOGIC_OR.equalsIgnoreCase(categoryIncludeProcessingLogic) ){
            Boolean containsOptionSet = false;
            /*
                For String fields newOptionsSet will have a single value which is the value of the field itself. The loop
                is here to make sure the logic works if for some reason we decide to add ";" in a String field to
                separate values.
             */
            for(String newOption: newOptionsSet){
                for(String value: values){
                    if(newOption.equals(value)){
                        containsOptionSet = true;
                        break;
                    }
                }
            }

            return containsOptionSet;
        }

        /* This logic only for cases when we have multiple values in the field and we need to check if all of them are included in the values. Currently, we don't have such cases.
        if it will be required, remove setting of CATEGORY_INCLUDE_LOGIC
        if(CATEGORY_INCLUDE_LOGIC_OR.equalsIgnoreCase(categoryIncludeProcessingLogic)){
            return values.containsAll(newOptionsSet);
        }
        else */if(CATEGORY_INCLUDE_LOGIC_AND.equalsIgnoreCase(categoryIncludeProcessingLogic)){
            return newOptionsSet.containsAll(values);
        }
        else{
            // Default logic should be OR
            return values.containsAll(newOptionsSet);
        }
    }

    private static Boolean isValuesEquals( Object requiredValue, Object recordValue ) {
        if(String.valueOf(requiredValue).equalsIgnoreCase('NULL')){
            return null == recordValue;
        }
        else if(String.valueOf(requiredValue).equalsIgnoreCase('true') || String.valueOf(requiredValue).equalsIgnoreCase('false')){
            return Boolean.valueOf(requiredValue) == Boolean.valueOf(recordValue);
        }
        else{
            return requiredValue == recordValue;
        }
    }

    private static Boolean isValuesDoesNotEqual( Object requiredValue, Object recordValue ) {
        if(String.valueOf(requiredValue).equalsIgnoreCase('NULL')){
            return null != recordValue;
        }
        else if(String.valueOf(requiredValue).equalsIgnoreCase('true') || String.valueOf(requiredValue).equalsIgnoreCase('false')){
            return Boolean.valueOf(requiredValue) != Boolean.valueOf(recordValue);
        }
        else{
            return requiredValue != recordValue;
        }
    }

    private class ProductCategoryTuple {
        private Id productId;
        private Id categoryId;

        public ProductCategoryTuple(Id productId, Id categoryId){
            this.productId = productId;
            this.categoryId = categoryId;
        }
    }
}