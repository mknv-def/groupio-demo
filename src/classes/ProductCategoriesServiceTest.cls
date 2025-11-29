@IsTest
public with sharing class ProductCategoriesServiceTest {
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

    private static final String PRODUCT_QUERY = 'SELECT Id, Name, Description, Product_Type__c, Primary_Category_Static__c FROM Product2';

    @TestSetup
    private static void makeData(){
        ProductCatalog productCatalog = new ProductCatalog();
        productCatalog.Name = 'Test Catalog';
        insert productCatalog;

        Product2 p1 = new Product2();
        p1.Name = 'Test 1';
        p1.Description = 'Test 1';
        p1.Family = 'None';
        p1.IsActive = true;
        insert p1;

        Product2 p2 = new Product2();
        p2.Name = 'Test 2';
        p2.Description = 'Test 2';
        p2.Family = 'None';
        p2.IsActive = true;
        insert p2;

        Product2 p3 = new Product2();
        p3.Name = 'Test 3';
        p3.Description = 'Test 3';
        p3.Family = 'None';
        p3.IsActive = true;
        insert p3;

        Product2 p4 = new Product2();
        p4.Name = 'Test 4';
        p4.Description = '';
        p4.Family = 'None';
        p4.IsActive = true;
        insert p4;

        Product2 p5 = new Product2();
        p5.Name = 'Test 5';
        p5.Description = 'Event Product';
        p5.Family = 'None';
        p5.IsActive = true;
        insert p5;

        Product2 p6 = new Product2();
        p6.Name = 'Test 6';
        p6.Description = 'Test 6';
        p6.Family = 'None';
        p6.IsActive = true;
        insert p6;

        ProductCategory pc1 = new ProductCategory();
        pc1.Name = 'Test Category 1';
        pc1.CatalogId = productCatalog.Id;
        insert pc1;

        ProductCategory pc2 = new ProductCategory();
        pc2.Name = 'Test Category 2';
        pc2.CatalogId = productCatalog.Id;
        insert pc2;

        ProductCategory pc3 = new ProductCategory();
        pc3.Name = 'Test Category 3';
        pc3.CatalogId = productCatalog.Id;
        insert pc3;

        ProductCategory pc4 = new ProductCategory();
        pc4.Name = 'Test Category 4';
        pc4.CatalogId = productCatalog.Id;
        insert pc4;

        ProductCategory pc5 = new ProductCategory();
        pc5.Name = 'Test Category 5';
        pc5.CatalogId = productCatalog.Id;
        insert pc5;

        ProductCategory pc6 = new ProductCategory();
        pc6.Name = 'Test Category 6';
        pc6.CatalogId = productCatalog.Id;
        insert pc6;

        ProductCategory pc7 = new ProductCategory();
        pc7.Name = 'Test Category 7';
        pc7.CatalogId = productCatalog.Id;
        insert pc7;

        Product_Category_Condition__c pcc1 = new Product_Category_Condition__c();
        pcc1.Operation__c = OPERATION_INCLUDED;
        pcc1.Product_Field_Name__c = 'Product_Type__c';
        pcc1.Values__c = 'Online Tickets;Events';
        pcc1.Category__c = pc1.Id;
        pcc1.Field_Type__c = FIELD_TYPE_PICKLIST;
        insert pcc1;

        Product_Category_Condition__c pcc2 = new Product_Category_Condition__c();
        pcc2.Operation__c = OPERATION_INCLUDED;
        pcc2.Product_Field_Name__c = 'Description';
        pcc2.Values__c = '3';
        pcc2.Category__c = pc2.Id;
        pcc2.Field_Type__c = FIELD_TYPE_STRING;
        insert pcc2;

        Product_Category_Condition__c pcc3 = new Product_Category_Condition__c();
        pcc3.Operation__c = OPERATION_EQUALS;
        pcc3.Product_Field_Name__c = 'Description';
        pcc3.Values__c = 'Test 2';
        pcc3.Category__c = pc3.Id;
        pcc3.Field_Type__c = FIELD_TYPE_STRING;
        insert pcc3;

        Product_Category_Condition__c pcc4 = new Product_Category_Condition__c();
        pcc4.Operation__c = OPERATION_DOES_NOT_EQUALS;
        pcc4.Product_Field_Name__c = 'Description';
        pcc4.Values__c = 'Test 1';
        pcc4.Category__c = pc4.Id;
        pcc4.Field_Type__c = FIELD_TYPE_STRING;
        insert pcc4;

        Product_Category_Condition__c pcc5 = new Product_Category_Condition__c();
        pcc5.Operation__c = OPERATION_INCLUDED;
        pcc5.Product_Field_Name__c = 'Description';
        pcc5.Values__c = ';';
        pcc5.Category__c = pc4.Id;
        pcc5.Field_Type__c = FIELD_TYPE_STRING;
        insert pcc5;

        Product_Category_Condition__c pcc6 = new Product_Category_Condition__c();
        pcc6.Operation__c = OPERATION_INCLUDED;
        pcc6.Product_Field_Name__c = 'Description';
        pcc6.Values__c = 'Test';
        pcc6.Category__c = pc5.Id;
        pcc6.Field_Type__c = FIELD_TYPE_STRING;
        insert pcc6;

        Product_Category_Condition__c pcc7 = new Product_Category_Condition__c();
        pcc7.Operation__c = OPERATION_EQUALS;
        pcc7.Product_Field_Name__c = 'Name';
        pcc7.Values__c = 'Test 2';
        pcc7.Category__c = pc7.Id;
        pcc7.Field_Type__c = FIELD_TYPE_STRING;
        insert pcc7;

        Product_Category_Condition__c pcc8 = new Product_Category_Condition__c();
        pcc8.Operation__c = OPERATION_EQUALS;
        pcc8.Product_Field_Name__c = 'Name';
        pcc8.Values__c = 'Test 3';
        pcc8.Category__c = pc7.Id;
        pcc8.Field_Type__c = FIELD_TYPE_STRING;
        insert pcc8;

        ProductCategoryProduct pcp1 = new ProductCategoryProduct();
        pcp1.ProductId = p1.Id;
        pcp1.ProductCategoryId = pc4.Id;
        insert pcp1;

        ProductCategoryProduct pcp2 = new ProductCategoryProduct();
        pcp2.ProductId = p5.Id;
        pcp2.ProductCategoryId = pc5.Id;
        insert pcp2;
    }
    @IsTest
    private static void testAllCategoriesPccLogicAndValueIncludeLogicOr(){
        ProductCategoriesService.testCategoryConditionProcessingLogic = CATEGORY_CONDITION_PROCESSING_LOGIC_AND;
        ProductCategoriesService.testCategoryIncludeLogic = CATEGORY_INCLUDE_LOGIC_OR;
        List<Product2> products = Database.query(PRODUCT_QUERY);

        Test.startTest();
        ProductCategoriesService.handleProductCategories(products);
        Test.stopTest();

        List<ProductCategoryProduct> productCategoryProducts = [SELECT Id, ProductCategory.Name, Product.Name FROM ProductCategoryProduct];

        for(ProductCategoryProduct pcp: productCategoryProducts){
            if(pcp.Product.Name.equalsIgnoreCase('Test 1')){
                Assert.isTrue(pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 1') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 5'),
                        'Product "' + pcp.Product.Name + '" must be assigned to "Test Category 1" and "Test Category 5"');
            }
            else if(pcp.Product.Name.equalsIgnoreCase('Test 2')){
                Assert.isTrue(pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 1') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 3')
                        || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 4') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 5'),
                        'Product "' + pcp.Product.Name + '" must be assigned to "Test Category 1", "Test Category 3", "Test Category 4" and "Test Category 5"');
            }
            else if(pcp.Product.Name.equalsIgnoreCase('Test 3')){
                Assert.isTrue(pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 1') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 2')
                        || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 4') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 5'),
                        'Product "' + pcp.Product.Name + '" must be assigned to "Test Category 1", "Test Category 2", "Test Category 4" and "Test Category 5"');
            }
        }
    }

    @IsTest
    private static void testAllCategoriesPccLogicAndValueIncludeLogicAnd(){
        ProductCategoriesService.testCategoryConditionProcessingLogic = CATEGORY_CONDITION_PROCESSING_LOGIC_AND;
        ProductCategoriesService.testCategoryIncludeLogic = CATEGORY_INCLUDE_LOGIC_AND;
        List<Product2> products = Database.query(PRODUCT_QUERY);

        Test.startTest();
        ProductCategoriesService.handleProductCategories(products);
        Test.stopTest();

        List<ProductCategoryProduct> productCategoryProducts = [SELECT Id, ProductCategory.Name, Product.Name FROM ProductCategoryProduct];

        for(ProductCategoryProduct pcp: productCategoryProducts){
            if(pcp.Product.Name.equalsIgnoreCase('Test 1')){
                Assert.isTrue(pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 5'),
                        'Product "' + pcp.Product.Name + '" must be assigned to "Test Category 5"');
            }
            else if(pcp.Product.Name.equalsIgnoreCase('Test 2')){
                Assert.isTrue(pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 1') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 3')
                        || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 4') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 5'),
                        'Product "' + pcp.Product.Name + '" must be assigned to "Test Category 1", "Test Category 3", "Test Category 4" and "Test Category 5"');
            }
            else if(pcp.Product.Name.equalsIgnoreCase('Test 3')){
                Assert.isTrue(pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 1') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 2')
                        || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 4') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 5'),
                        'Product "' + pcp.Product.Name + '" must be assigned to "Test Category 1", "Test Category 2", "Test Category 4" and "Test Category 5"');
            }
            else if(pcp.Product.Name.equalsIgnoreCase('Test 6')){
                Assert.isTrue(pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 1') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 5'),
                        'Product "' + pcp.Product.Name + '" must be assigned to "Test Category 1" and "Test Category 5"');
            }
        }
    }

    @IsTest
    private static void testAllCategoriesPccLogicOrValueIncludeLogicOr(){
        ProductCategoriesService.testCategoryConditionProcessingLogic = CATEGORY_CONDITION_PROCESSING_LOGIC_OR;
        ProductCategoriesService.testCategoryIncludeLogic = CATEGORY_INCLUDE_LOGIC_OR;
        List<Product2> products = Database.query(PRODUCT_QUERY);

        Test.startTest();
        ProductCategoriesService.handleProductCategories(products);
        Test.stopTest();

        List<ProductCategoryProduct> productCategoryProducts = [SELECT Id, ProductCategory.Name, Product.Name FROM ProductCategoryProduct];

        for(ProductCategoryProduct pcp: productCategoryProducts){
            if(pcp.Product.Name.equalsIgnoreCase('Test 2')){
                Assert.isTrue(pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 1') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 3')
                        || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 4') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 5') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 7'),
                        'Product "' + pcp.Product.Name + '" must be assigned to "Test Category 1", "Test Category 3", "Test Category 4", "Test Category 5" and "Test Category 7"');
            }
            else if(pcp.Product.Name.equalsIgnoreCase('Test 3')){
                Assert.isTrue(pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 1') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 2')
                        || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 4') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 5') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 7'),
                        'Product "' + pcp.Product.Name + '" must be assigned to "Test Category 1", "Test Category 2", "Test Category 4" "Test Category 5" and "Test Category 7"');
            }
        }
    }
    @IsTest
    private static void testSingleCategory(){
        ProductCategoriesService.testCategoryConditionProcessingLogic = CATEGORY_CONDITION_PROCESSING_LOGIC_AND;
        ProductCategoriesService.testCategoryIncludeLogic = CATEGORY_INCLUDE_LOGIC_OR;

        List<Product2> products = Database.query(PRODUCT_QUERY);
        ProductCategory productCategory = [SELECT Id, Name FROM ProductCategory WHERE Name='Test Category 5'];

        Test.startTest();
        ProductCategoriesService.handleProductCategories(products, productCategory);
        Test.stopTest();

        List<ProductCategoryProduct> productCategoryProducts = [SELECT Id, ProductCategory.Name, Product.Name FROM ProductCategoryProduct WHERE ProductCategory.Name='Test Category 5'];
        for(Product2 product: products){
            for(ProductCategoryProduct pcp: productCategoryProducts){
                if(pcp.ProductId == product.Id){
                    Assert.isTrue(pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 5'),
                            'Product "' + pcp.Product.Name + '" must be assigned to "Test Category 5"');
                }
                break;
            }
        }
    }

    @IsTest
    private static void testEmptyConditionsSingleCategory(){
        ProductCategoriesService.testCategoryConditionProcessingLogic = CATEGORY_CONDITION_PROCESSING_LOGIC_AND;
        ProductCategoriesService.testCategoryIncludeLogic = CATEGORY_INCLUDE_LOGIC_OR;

        List<Product2> products = Database.query(PRODUCT_QUERY);
        ProductCategory productCategory = [SELECT Id, Name FROM ProductCategory WHERE Name='Test Category 6'];

        Test.startTest();
        ProductCategoriesService.handleProductCategories(products, productCategory);
        Test.stopTest();
    }

    @IsTest
    private static void testException(){
        List<Product2> products = Database.query(PRODUCT_QUERY);

        ProductCategoriesService.testException = true;
        ProductCategoriesService.testCategoryConditionProcessingLogic = CATEGORY_CONDITION_PROCESSING_LOGIC_AND;
        ProductCategoriesService.testCategoryIncludeLogic = CATEGORY_INCLUDE_LOGIC_OR;

        Test.startTest();
        ProductCategoriesService.handleProductCategories(products);
        Test.stopTest();
    }
    @IsTest
    private static void testAllCategoriesBatchLogic(){
        ProductCategoriesService.testCategoryConditionProcessingLogic = CATEGORY_CONDITION_PROCESSING_LOGIC_AND;
        ProductCategoriesService.testCategoryIncludeLogic = CATEGORY_INCLUDE_LOGIC_OR;

        Test.startTest();
        Database.executeBatch(new ProductCategoryAssignerBatch(PRODUCT_QUERY));
        Test.stopTest();

        List<ProductCategoryProduct> productCategoryProducts = [SELECT Id, ProductCategory.Name, Product.Name FROM ProductCategoryProduct];

        for(ProductCategoryProduct pcp: productCategoryProducts){
            if(pcp.Product.Name.equalsIgnoreCase('Test 1')){
                Assert.isTrue(pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 1') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 5'),
                        'Product "' + pcp.Product.Name + '" must be assigned to "Test Category 1" and "Test Category 5"');
            }
            else if(pcp.Product.Name.equalsIgnoreCase('Test 2')){
                Assert.isTrue(pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 1') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 3')
                        || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 4') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 5'),
                        'Product "' + pcp.Product.Name + '" must be assigned to "Test Category 1", "Test Category 3", "Test Category 4" and "Test Category 5"');
            }
            else if(pcp.Product.Name.equalsIgnoreCase('Test 3')){
                Assert.isTrue(pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 1') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 2')
                        || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 4') || pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 5'),
                        'Product "' + pcp.Product.Name + '" must be assigned to "Test Category 1", "Test Category 2", "Test Category 4" and "Test Category 5"');
            }
        }
    }

    @IsTest
    private static void testSingleCategoryBatchLogic(){
        ProductCategoriesService.testCategoryConditionProcessingLogic = CATEGORY_CONDITION_PROCESSING_LOGIC_AND;
        ProductCategoriesService.testCategoryIncludeLogic = CATEGORY_INCLUDE_LOGIC_OR;

        ProductCategory productCategory = [SELECT Id, Name FROM ProductCategory WHERE Name='Test Category 5'];

        Test.startTest();
        Database.executeBatch(new ProductCategoryAssignerBatch(PRODUCT_QUERY, productCategory));
        Test.stopTest();

        List<Product2> products = Database.query(PRODUCT_QUERY);
        List<ProductCategoryProduct> productCategoryProducts = [SELECT Id, ProductCategory.Name, Product.Name FROM ProductCategoryProduct WHERE ProductCategory.Name='Test Category 5'];
        for(Product2 product: products){
            for(ProductCategoryProduct pcp: productCategoryProducts){
                if(pcp.ProductId == product.Id){
                    Assert.isTrue(pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 5'),
                            'Product "' + pcp.Product.Name + '" must be assigned to "Test Category 5"');
                }
                break;
            }
        }
    }
    @IsTest
    private static void testSingleCategoryInvocable(){
        ProductCategoriesService.testCategoryConditionProcessingLogic = CATEGORY_CONDITION_PROCESSING_LOGIC_AND;
        ProductCategoriesService.testCategoryIncludeLogic = CATEGORY_INCLUDE_LOGIC_OR;

        ProductCategory productCategory = [SELECT Id, Name FROM ProductCategory WHERE Name='Test Category 5'];

        Test.startTest();
        ProductCategorySingleCategoryInvocable.assignProductsToSingleCategory(new List<ProductCategory>{productCategory});
        Test.stopTest();

        List<Product2> products = Database.query(PRODUCT_QUERY);
        List<ProductCategoryProduct> productCategoryProducts = [SELECT Id, ProductCategory.Name, Product.Name FROM ProductCategoryProduct WHERE ProductCategory.Name='Test Category 5'];
        for(Product2 product: products){
            for(ProductCategoryProduct pcp: productCategoryProducts){
                if(pcp.ProductId == product.Id){
                    Assert.isTrue(pcp.ProductCategory.Name.equalsIgnoreCase('Test Category 5'),
                            'Product "' + pcp.Product.Name + '" must be assigned to "Test Category 5"');
                }
                break;
            }
        }
    }

    @IsTest
    private static void testEmptySingleCategoryInvocable(){
        ProductCategoriesService.testCategoryConditionProcessingLogic = CATEGORY_CONDITION_PROCESSING_LOGIC_AND;
        ProductCategoriesService.testCategoryIncludeLogic = CATEGORY_INCLUDE_LOGIC_OR;

        Test.startTest();
        ProductCategorySingleCategoryInvocable.assignProductsToSingleCategory(new List<ProductCategory>());
        Test.stopTest();
    }
}