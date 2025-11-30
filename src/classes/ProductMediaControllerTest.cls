/**
 * @description Test class for ProductMediaController
 * Tests CMS content linking and ProductMedia management functionality
 */
@isTest
private class ProductMediaControllerTest {

    /**
     * @description Setup test data
     */
    @TestSetup
    static void setupTestData() {
        // Create test product
        Product2 testProduct = new Product2(
                Name = 'Test Product for Media',
                ProductCode = 'TEST-MEDIA-001',
                IsActive = true
        );
        insert testProduct;

        // Create test ElectronicMediaGroup
        ElectronicMediaGroup testGroup = new ElectronicMediaGroup(
                Name = 'Product List Image',
                DeveloperName = 'Product_List_Image'
        );
        insert testGroup;
    }

    /**
     * @description Test getCmsWorkspaces method
     */
    @isTest
    static void testGetCmsWorkspaces() {
        Test.startTest();
        List<ProductMediaController.PicklistOption> options =
                ProductMediaController.getCmsWorkspaces();
        Test.stopTest();

        // Results depend on org configuration
        System.assertNotEquals(null, options, 'Options list should not be null');
    }

    /**
     * @description Test getMediaGroups method
     */
    @isTest
    static void testGetMediaGroups() {
        Test.startTest();
        List<ProductMediaController.PicklistOption> options =
                ProductMediaController.getMediaGroups();
        Test.stopTest();

        System.assertNotEquals(null, options, 'Options list should not be null');
        System.assert(options.size() > 0, 'Should have at least one media group from test setup');
    }

    /**
     * @description Test getProductMedia method with no media
     */
    @isTest
    static void testGetProductMediaEmpty() {
        Product2 testProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'TEST-MEDIA-001' LIMIT 1];

        Test.startTest();
        List<ProductMediaController.ProductMediaInfo> mediaList =
                ProductMediaController.getProductMedia(testProduct.Id);
        Test.stopTest();

        System.assertEquals(0, mediaList.size(), 'Should have no media initially');
    }

    /**
     * @description Test getProductMedia method with existing media
     */
    @isTest
    static void testGetProductMediaWithData() {
        Product2 testProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'TEST-MEDIA-001' LIMIT 1];
        ElectronicMediaGroup testGroup = [SELECT Id FROM ElectronicMediaGroup WHERE Name = 'Product List Image' LIMIT 1];

        // Create ProductMedia record
        ProductMedia pm = new ProductMedia(
                ProductId = testProduct.Id,
                ElectronicMediaGroupId = testGroup.Id,
                ElectronicMediaId = 'TESTCONTENTID123', // Mock content ID
                SortOrder = 1
        );
        insert pm;

        Test.startTest();
        List<ProductMediaController.ProductMediaInfo> mediaList =
                ProductMediaController.getProductMedia(testProduct.Id);
        Test.stopTest();

        System.assertEquals(1, mediaList.size(), 'Should have one media record');
        System.assertEquals('Product List Image', mediaList[0].mediaGroupName, 'Media group name should match');
    }

    /**
     * @description Test deleteProductMedia method
     */
    @isTest
    static void testDeleteProductMedia() {
        Product2 testProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'TEST-MEDIA-001' LIMIT 1];
        ElectronicMediaGroup testGroup = [SELECT Id FROM ElectronicMediaGroup WHERE Name = 'Product List Image' LIMIT 1];

        // Create ProductMedia record
        ProductMedia pm = new ProductMedia(
                ProductId = testProduct.Id,
                ElectronicMediaGroupId = testGroup.Id,
                ElectronicMediaId = 'TESTCONTENTID456',
                SortOrder = 1
        );
        insert pm;

        Id mediaId = pm.Id;

        Test.startTest();
        ProductMediaController.deleteProductMedia(mediaId);
        Test.stopTest();

        // Verify deletion
        List<ProductMedia> remaining = [SELECT Id FROM ProductMedia WHERE Id = :mediaId];
        System.assertEquals(0, remaining.size(), 'ProductMedia should be deleted');
    }

    /**
     * @description Test deleteProductMedia with invalid ID
     */
    @isTest
    static void testDeleteProductMediaInvalidId() {
        // Use a fake ID that doesn't exist
        Id fakeId = '0PM000000000001AAA'; // ProductMedia prefix

        Test.startTest();
        try {
            ProductMediaController.deleteProductMedia(fakeId);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not found'), 'Should indicate record not found');
        }
        Test.stopTest();
    }

    /**
     * @description Test linkCmsContentToProduct method
     */
    @isTest
    static void testLinkCmsContentToProduct() {
        Product2 testProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'TEST-MEDIA-001' LIMIT 1];

        Test.startTest();
        ProductMediaController.ProductMediaResult result =
                ProductMediaController.linkCmsContentToProduct(
                        testProduct.Id,
                        'TESTCONTENTID789',
                        'Product List Image'
                );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should succeed');
        System.assertNotEquals(null, result.productMediaId, 'Should have productMediaId');

        // Verify ProductMedia was created
        List<ProductMedia> created = [
                SELECT Id, ElectronicMediaId
                FROM ProductMedia
                WHERE ProductId = :testProduct.Id
        ];
        System.assertEquals(1, created.size(), 'Should have one ProductMedia');
        System.assertEquals('TESTCONTENTID789', created[0].ElectronicMediaId, 'ElectronicMediaId should match');
    }

    /**
     * @description Test linkCmsContentToProduct with missing product ID
     */
    @isTest
    static void testLinkWithMissingProductId() {
        Test.startTest();
        try {
            ProductMediaController.linkCmsContentToProduct(
                    null,
                    'TESTCONTENT',
                    'Product List Image'
            );
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should indicate product ID required');
        }
        Test.stopTest();
    }

    /**
     * @description Test linkCmsContentToProduct with missing content ID
     */
    @isTest
    static void testLinkWithMissingContentId() {
        Product2 testProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'TEST-MEDIA-001' LIMIT 1];

        Test.startTest();
        try {
            ProductMediaController.linkCmsContentToProduct(
                    testProduct.Id,
                    '',
                    'Product List Image'
            );
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should indicate content ID required');
        }
        Test.stopTest();
    }

    /**
     * @description Test linkCmsContentToProduct with duplicate link
     */
    @isTest
    static void testLinkDuplicate() {
        Product2 testProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'TEST-MEDIA-001' LIMIT 1];
        ElectronicMediaGroup testGroup = [SELECT Id FROM ElectronicMediaGroup WHERE Name = 'Product List Image' LIMIT 1];

        // Create existing ProductMedia
        ProductMedia pm = new ProductMedia(
                ProductId = testProduct.Id,
                ElectronicMediaGroupId = testGroup.Id,
                ElectronicMediaId = 'DUPLICATEID',
                SortOrder = 1
        );
        insert pm;

        Test.startTest();
        try {
            ProductMediaController.linkCmsContentToProduct(
                    testProduct.Id,
                    'DUPLICATEID',
                    'Product List Image'
            );
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('already linked'), 'Should indicate already linked');
        }
        Test.stopTest();
    }

    /**
     * @description Test uploadProductImageToCms with missing product ID
     */
    @isTest
    static void testUploadWithMissingProductId() {
        Test.startTest();
        try {
            ProductMediaController.uploadProductImageToCms(
                    null, // Missing product ID
                    'test.jpg',
                    'base64data',
                    'image/jpeg',
                    'Product List Image'
            );
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should indicate product ID required');
        }
        Test.stopTest();
    }

    /**
     * @description Test uploadProductImageToCms with missing file name
     */
    @isTest
    static void testUploadWithMissingFileName() {
        Product2 testProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'TEST-MEDIA-001' LIMIT 1];

        Test.startTest();
        try {
            ProductMediaController.uploadProductImageToCms(
                    testProduct.Id,
                    '', // Missing file name
                    'base64data',
                    'image/jpeg',
                    'Product List Image'
            );
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should indicate file name required');
        }
        Test.stopTest();
    }

    /**
     * @description Test PicklistOption wrapper class
     */
    @isTest
    static void testPicklistOptionWrapper() {
        Test.startTest();
        ProductMediaController.PicklistOption option =
                new ProductMediaController.PicklistOption('testValue', 'Test Label');
        Test.stopTest();

        System.assertEquals('testValue', option.value, 'Value should match');
        System.assertEquals('Test Label', option.label, 'Label should match');
    }

    /**
     * @description Test ProductMediaResult wrapper class
     */
    @isTest
    static void testProductMediaResultWrapper() {
        Test.startTest();
        ProductMediaController.ProductMediaResult result =
                new ProductMediaController.ProductMediaResult();
        Test.stopTest();

        System.assertEquals(false, result.success, 'Default success should be false');
        System.assertEquals('', result.message, 'Default message should be empty');
    }

    /**
     * @description Test ProductMediaInfo wrapper class
     */
    @isTest
    static void testProductMediaInfoWrapper() {
        Test.startTest();
        ProductMediaController.ProductMediaInfo info =
                new ProductMediaController.ProductMediaInfo();
        info.id = null;
        info.electronicMediaId = 'TEST123';
        info.mediaGroupName = 'Product List Image';
        info.sortOrder = 1;
        info.title = 'Test Image';
        info.imageUrl = '/cms/media/test';
        Test.stopTest();

        System.assertEquals('TEST123', info.electronicMediaId, 'ElectronicMediaId should match');
        System.assertEquals('Product List Image', info.mediaGroupName, 'Media group name should match');
        System.assertEquals(1, info.sortOrder, 'Sort order should match');
    }

    /**
     * @description Test CmsContentOption wrapper class
     */
    @isTest
    static void testCmsContentOptionWrapper() {
        Test.startTest();
        ProductMediaController.CmsContentOption opt =
                new ProductMediaController.CmsContentOption();
        opt.managedContentId = 'MCT123';
        opt.contentKey = 'KEY123';
        opt.title = 'Test Image';
        opt.imageUrl = '/cms/media/test';
        Test.stopTest();

        System.assertEquals('MCT123', opt.managedContentId, 'managedContentId should match');
        System.assertEquals('KEY123', opt.contentKey, 'contentKey should match');
        System.assertEquals('Test Image', opt.title, 'title should match');
    }
}