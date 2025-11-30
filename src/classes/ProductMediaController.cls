/**
 * @description Controller for managing CMS content and Product Media in B2B Commerce
 * Uses REST API callouts to create CMS content since ConnectApi doesn't support content creation
 *
 * Architecture:
 * - ProductMedia.ElectronicMediaId = ManagedContent Id (Content Key)
 * - ElectronicMediaGroup defines the media type (Product List Image, Product Detail Images)
 * - CMS content is created via REST API callout to /connect/cms/spaces/{spaceId}/content
 * - Uses Queueable for callouts to avoid Savepoint conflicts
 */
public with sharing class ProductMediaController {

    /**
     * @description Upload image as CMS content via REST API and link to product
     * This method validates inputs and enqueues the actual upload job
     *
     * @param productId The Product2 Id to link the image to
     * @param fileName The name of the file (e.g., 'product-image.jpg')
     * @param base64Data The base64 encoded image data
     * @param contentType The MIME type (e.g., 'image/jpeg', 'image/png')
     * @param mediaGroupName The ElectronicMediaGroup name (default: 'Product List Image')
     * @return ProductMediaResult with success status (async job enqueued)
     */
    @AuraEnabled
    public static ProductMediaResult uploadProductImageToCms(
            Id productId,
            String fileName,
            String base64Data,
            String contentType,
            String mediaGroupName
    ) {
        ProductMediaResult result = new ProductMediaResult();

        // Validate inputs
        if (productId == null) {
            throw new AuraHandledException('Product ID is required');
        }
        if (String.isBlank(fileName)) {
            throw new AuraHandledException('File name is required');
        }
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException('Image data is required');
        }

        // Default media group if not specified
        if (String.isBlank(mediaGroupName)) {
            mediaGroupName = 'Product List Image';
        }

        // Get the product
        List<Product2> products = [
                SELECT Id, Name, ProductCode, StockKeepingUnit
                FROM Product2
                WHERE Id = :productId
                LIMIT 1
        ];

        if (products.isEmpty()) {
            throw new AuraHandledException('Product not found');
        }

        Product2 product = products[0];

        // Get CMS Workspace Id
        String spaceId = getDefaultCmsSpaceId();
        if (String.isBlank(spaceId)) {
            throw new AuraHandledException('No CMS Workspace found. Please ensure you have a CMS Workspace configured.');
        }

        // Get or create ElectronicMediaGroup (do this in main transaction)
        Id mediaGroupId = getOrCreateMediaGroup(mediaGroupName);

        // Get next sort order
        Integer nextSortOrder = getNextSortOrder(productId);

        // Enqueue the callout job
        CmsImageUploadQueueable job = new CmsImageUploadQueueable(
                productId,
                product.Name,
                fileName,
                base64Data,
                contentType,
                spaceId,
                mediaGroupId,
                nextSortOrder
        );

        Id jobId = System.enqueueJob(job);

        result.success = true;
        result.message = 'Image upload started. It will be linked to the product shortly.';
        result.electronicMediaGroupId = mediaGroupId;

        return result;
    }

    /**
     * @description Synchronous version - uploads directly without queueable
     * Use this if you need immediate results and are sure no Savepoints are active
     *
     * @param productId The Product2 Id to link the image to
     * @param fileName The name of the file
     * @param base64Data The base64 encoded image data
     * @param contentType The MIME type
     * @param mediaGroupName The ElectronicMediaGroup name
     * @return ProductMediaResult with success status and created record info
     */
    @AuraEnabled
    public static ProductMediaResult uploadProductImageToCmsSync(
            Id productId,
            String fileName,
            String base64Data,
            String contentType,
            String mediaGroupName
    ) {
        ProductMediaResult result = new ProductMediaResult();

        // Validate inputs
        if (productId == null) {
            throw new AuraHandledException('Product ID is required');
        }
        if (String.isBlank(fileName)) {
            throw new AuraHandledException('File name is required');
        }
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException('Image data is required');
        }

        // Default media group if not specified
        if (String.isBlank(mediaGroupName)) {
            mediaGroupName = 'Product List Image';
        }

        // Get the product
        List<Product2> products = [
                SELECT Id, Name, ProductCode, StockKeepingUnit
                FROM Product2
                WHERE Id = :productId
                LIMIT 1
        ];

        if (products.isEmpty()) {
            throw new AuraHandledException('Product not found');
        }

        Product2 product = products[0];

        // Get CMS Workspace Id
        String spaceId = getDefaultCmsSpaceId();
        if (String.isBlank(spaceId)) {
            throw new AuraHandledException('No CMS Workspace found. Please ensure you have a CMS Workspace configured.');
        }

        // Get or create ElectronicMediaGroup
        Id mediaGroupId = getOrCreateMediaGroup(mediaGroupName);

        // Get next sort order
        Integer nextSortOrder = getNextSortOrder(productId);

        // Make the HTTP callout
        String managedContentId;
        try {
            managedContentId = createCmsImageViaRestApi(
                    spaceId,
                    fileName,
                    base64Data,
                    contentType,
                    product.Name
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CMS API Error: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Failed to upload image to CMS: ' + e.getMessage());
        }

        if (String.isBlank(managedContentId)) {
            throw new AuraHandledException('Failed to create CMS content - no content ID returned');
        }

        // Create ProductMedia record
        try {
            ProductMedia pm = new ProductMedia();
            pm.ProductId = productId;
            pm.ElectronicMediaId = managedContentId;
            pm.ElectronicMediaGroupId = mediaGroupId;
            pm.SortOrder = nextSortOrder;
            insert pm;

            result.success = true;
            result.productMediaId = pm.Id;
            result.managedContentId = managedContentId;
            result.electronicMediaGroupId = mediaGroupId;
            result.message = 'Image uploaded to CMS and linked to product successfully';

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ProductMedia creation failed. ManagedContentId: ' + managedContentId + ', Error: ' + e.getMessage());
            throw new AuraHandledException('Image uploaded to CMS but failed to link to product: ' + e.getMessage());
        }

        return result;
    }

    /**
     * @description Queueable class for CMS image upload
     * Handles the HTTP callout in a separate transaction to avoid Savepoint issues
     */
    public class CmsImageUploadQueueable implements Queueable, Database.AllowsCallouts {
        private Id productId;
        private String productName;
        private String fileName;
        private String base64Data;
        private String contentType;
        private String spaceId;
        private Id mediaGroupId;
        private Integer sortOrder;

        public CmsImageUploadQueueable(
                Id productId,
                String productName,
                String fileName,
                String base64Data,
                String contentType,
                String spaceId,
                Id mediaGroupId,
                Integer sortOrder
        ) {
            this.productId = productId;
            this.productName = productName;
            this.fileName = fileName;
            this.base64Data = base64Data;
            this.contentType = contentType;
            this.spaceId = spaceId;
            this.mediaGroupId = mediaGroupId;
            this.sortOrder = sortOrder;
        }

        public void execute(QueueableContext context) {
            try {
                // Make the HTTP callout to create CMS content
                String managedContentId = ProductMediaController.createCmsImageViaRestApi(
                        spaceId,
                        fileName,
                        base64Data,
                        contentType,
                        productName
                );

                if (String.isNotBlank(managedContentId)) {
                    // Create ProductMedia record
                    ProductMedia pm = new ProductMedia();
                    pm.ProductId = productId;
                    pm.ElectronicMediaId = managedContentId;
                    pm.ElectronicMediaGroupId = mediaGroupId;
                    pm.SortOrder = sortOrder;
                    insert pm;

                    System.debug('Successfully created ProductMedia: ' + pm.Id + ' with CMS content: ' + managedContentId);
                } else {
                    System.debug(LoggingLevel.ERROR, 'CMS content creation returned no ID');
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'CmsImageUploadQueueable failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
                // In production, you might want to create a custom object to track failures
                // or send a notification to the user
            }
        }
    }

    /**
     * @description Create CMS Image content using REST API callout with Binary Blob construction
     * This avoids "Buffer size exceeded" errors by sending true binary data instead of a text string.
     */
    public static String createCmsImageViaRestApi(
            String spaceId,
            String fileName,
            String base64Data,
            String contentType,
            String altText
    ) {
        // 1. Prepare Data
        // Clean the base64 string
        String cleanBase64 = base64Data;
        if (cleanBase64.contains(',')) {
            cleanBase64 = cleanBase64.substringAfterLast(',');
        }

        // Clean filename
        String cleanFileName = fileName.replaceAll('"', '').replaceAll('\\s+', '_');

        // Generate URL safe names
        String urlName = generateUrlName(cleanFileName);
        String title = cleanFileName.substringBeforeLast('.');

        // 2. Prepare Metadata JSON
        Map<String, Object> contentInput = new Map<String, Object>();
        contentInput.put('title', title);
        contentInput.put('urlName', urlName);
        contentInput.put('contentType', 'cms_image');

        Map<String, Object> contentBody = new Map<String, Object>();

        Map<String, Object> titleNode = new Map<String, Object>();
        titleNode.put('nodeType', 'NameField');
        titleNode.put('value', title);
        contentBody.put('title', titleNode);

        Map<String, Object> altTextNode = new Map<String, Object>();
        altTextNode.put('nodeType', 'Text');
        altTextNode.put('value', String.isNotBlank(altText) ? altText : title);
        contentBody.put('altText', altTextNode);

        Map<String, Object> sourceNode = new Map<String, Object>();
        sourceNode.put('nodeType', 'Media');
        sourceNode.put('referenceId', 'source');
        contentBody.put('source', sourceNode);

        contentInput.put('contentBody', contentBody);
        String jsonMetadata = JSON.serialize(contentInput);

        // 3. Construct the Multipart Body using Hex/Blob technique
        // We use a specific boundary that doesn't conflict with hex characters
        String boundary = '----------------------------741e90d31eff';

        // Header for Part 1 (JSON)
        String headerJson = '--' + boundary + '\r\n' +
                'Content-Disposition: form-data; name="contentInput"\r\n' +
                'Content-Type: application/json\r\n\r\n' +
                jsonMetadata + '\r\n';

        // Header for Part 2 (Binary File)
        // Note: We DO NOT use Content-Transfer-Encoding here because we are sending raw binary bytes
        String headerFile = '--' + boundary + '\r\n' +
                'Content-Disposition: form-data; name="source"; filename="' + cleanFileName + '"\r\n' +
                'Content-Type: ' + contentType + '\r\n\r\n';

        // Footer
        String footer = '\r\n--' + boundary + '--';

        // 4. Combine parts into a single HEX string
        // This is the only way to combine Strings and Blobs in Apex
        String bodyHex = EncodingUtil.convertToHex(Blob.valueOf(headerJson));
        bodyHex += EncodingUtil.convertToHex(Blob.valueOf(headerFile));

        // Convert Base64 Image -> Binary -> Hex
        try {
            Blob imageBlob = EncodingUtil.base64Decode(cleanBase64);
            bodyHex += EncodingUtil.convertToHex(imageBlob);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid Base64 Image Data');
        }

        bodyHex += EncodingUtil.convertToHex(Blob.valueOf(footer));

        // 5. Convert Hex back to a single binary Blob
        Blob bodyBlob = EncodingUtil.convertFromHex(bodyHex);

        // 6. Send Request
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String apiVersion = 'v59.0';
        String endpoint = baseUrl + '/services/data/' + apiVersion + '/connect/cms/spaces/' + spaceId + '/content';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setBodyAsBlob(bodyBlob); // Send as Blob, not String
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        // 7. Handle Response
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String managedContentId = (String) responseMap.get('managedContentId');

            // Attempt to publish
            publishCmsContent(spaceId, managedContentId);

            return managedContentId;
        } else {
            System.debug(LoggingLevel.ERROR, 'CMS API Error: ' + res.getStatusCode() + ' - ' + res.getBody());
            throw new AuraHandledException('CMS Upload Failed: ' + res.getStatus() + ' ' + res.getBody());
        }
    }

    /**
     * @description Publish CMS content via REST API
     * @param spaceId The CMS workspace Id
     * @param managedContentId The content Id to publish
     */
    private static void publishCmsContent(String spaceId, String managedContentId) {
        try {
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();
            String apiVersion = 'v59.0';
            String endpoint = baseUrl + '/services/data/' + apiVersion + '/connect/cms/spaces/' + spaceId + '/content/publish';

            Map<String, Object> publishInput = new Map<String, Object>();
            publishInput.put('contentIds', new List<String>{ managedContentId });

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(publishInput));

            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('Publish Response: ' + res.getStatusCode() + ' - ' + res.getBody());
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not auto-publish content: ' + e.getMessage());
            // Content created but not published - admin may need to publish manually
        }
    }

    /**
     * @description Link existing CMS content to a product
     * Use this method when CMS content already exists (e.g., uploaded via UI)
     *
     * @param productId The Product2 Id
     * @param managedContentId The CMS content Id (Content Key)
     * @param mediaGroupName The media group name
     * @return ProductMediaResult
     */
    @AuraEnabled
    public static ProductMediaResult linkCmsContentToProduct(
            Id productId,
            String managedContentId,
            String mediaGroupName
    ) {
        ProductMediaResult result = new ProductMediaResult();

        try {
            if (productId == null) {
                throw new AuraHandledException('Product ID is required');
            }
            if (String.isBlank(managedContentId)) {
                throw new AuraHandledException('Content ID is required');
            }
            if (String.isBlank(mediaGroupName)) {
                mediaGroupName = 'Product List Image';
            }

            // Verify product exists
            List<Product2> products = [SELECT Id FROM Product2 WHERE Id = :productId LIMIT 1];
            if (products.isEmpty()) {
                throw new AuraHandledException('Product not found');
            }

            // Get or create ElectronicMediaGroup
            Id mediaGroupId = getOrCreateMediaGroup(mediaGroupName);

            // Check if this media is already linked
            List<ProductMedia> existingLinks = [
                    SELECT Id FROM ProductMedia
                    WHERE ProductId = :productId
                    AND ElectronicMediaId = :managedContentId
                    LIMIT 1
            ];

            if (!existingLinks.isEmpty()) {
                throw new AuraHandledException('This content is already linked to the product');
            }

            // Create ProductMedia
            ProductMedia pm = new ProductMedia();
            pm.ProductId = productId;
            pm.ElectronicMediaId = managedContentId;
            pm.ElectronicMediaGroupId = mediaGroupId;
            pm.SortOrder = getNextSortOrder(productId);
            insert pm;

            result.success = true;
            result.productMediaId = pm.Id;
            result.managedContentId = managedContentId;
            result.electronicMediaGroupId = mediaGroupId;
            result.message = 'Content linked to product successfully';

            return result;

        } catch (Exception e) {
            result.success = false;
            result.message = 'Error: ' + e.getMessage();
            throw new AuraHandledException(result.message);
        }
    }

    /**
     * @description Get default CMS Workspace (Space) Id
     * @return The first active CMS Space Id
     */
    private static String getDefaultCmsSpaceId() {
        try {
            List<ManagedContentSpace> spaces = [
                    SELECT Id, Name
                    FROM ManagedContentSpace
                    ORDER BY CreatedDate ASC
                    LIMIT 1
            ];

            if (!spaces.isEmpty()) {
                return spaces[0].Id;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting CMS space: ' + e.getMessage());
        }

        return null;
    }

    /**
     * @description Get or create ElectronicMediaGroup
     * @param groupName The name of the media group
     * @return The ElectronicMediaGroup Id
     */
    private static Id getOrCreateMediaGroup(String groupName) {
        // Try to find existing group
        List<ElectronicMediaGroup> existingGroups = [
                SELECT Id, Name
                FROM ElectronicMediaGroup
                WHERE Name = :groupName
                LIMIT 1
        ];

        if (!existingGroups.isEmpty()) {
            return existingGroups[0].Id;
        }

        // Create new group
        ElectronicMediaGroup newGroup = new ElectronicMediaGroup();
        newGroup.Name = groupName;
        newGroup.DeveloperName = generateDeveloperName(groupName);
        insert newGroup;

        return newGroup.Id;
    }

    /**
     * @description Get next sort order for product media
     * @param productId The Product2 Id
     * @return Next available sort order
     */
    private static Integer getNextSortOrder(Id productId) {
        List<ProductMedia> existingMedia = [
                SELECT SortOrder
                FROM ProductMedia
                WHERE ProductId = :productId
                ORDER BY SortOrder DESC NULLS LAST
                LIMIT 1
        ];

        if (existingMedia.isEmpty() || existingMedia[0].SortOrder == null) {
            return 1;
        }

        return (Integer)existingMedia[0].SortOrder + 1;
    }

    /**
     * @description Generate URL-safe name for CMS content
     */
    private static String generateUrlName(String fileName) {
        String baseName = fileName.substringBeforeLast('.');
        String urlName = baseName.toLowerCase()
                .replaceAll('[^a-z0-9\\-]', '-')
                .replaceAll('-+', '-')
                .removeStart('-')
                .removeEnd('-');

        // Add timestamp for uniqueness
        urlName += '-' + DateTime.now().getTime();

        if (urlName.length() > 100) {
            urlName = urlName.substring(0, 100);
        }

        return urlName;
    }

    /**
     * @description Generate developer name from display name
     */
    private static String generateDeveloperName(String displayName) {
        String devName = displayName
                .replaceAll('[^a-zA-Z0-9]', '_')
                .replaceAll('_+', '_')
                .removeStart('_')
                .removeEnd('_');

        if (String.isBlank(devName) || !devName.substring(0, 1).isAlpha()) {
            devName = 'EMG_' + devName;
        }

        if (devName.length() > 40) {
            devName = devName.substring(0, 40);
        }

        return devName;
    }

    /**
     * @description Get available CMS Workspaces
     * @return List of workspace options for UI
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getCmsWorkspaces() {
        List<PicklistOption> options = new List<PicklistOption>();

        try {
            List<ManagedContentSpace> spaces = [
                    SELECT Id, Name
                    FROM ManagedContentSpace
                    ORDER BY Name
                    LIMIT 100
            ];

            for (ManagedContentSpace space : spaces) {
                options.add(new PicklistOption(space.Id, space.Name));
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting CMS workspaces: ' + e.getMessage());
        }

        return options;
    }

    /**
     * @description Get available Electronic Media Groups
     * @return List of media group options for UI
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getMediaGroups() {
        List<PicklistOption> options = new List<PicklistOption>();

        try {
            List<ElectronicMediaGroup> groups = [
                    SELECT Id, Name
                    FROM ElectronicMediaGroup
                    ORDER BY Name
                    LIMIT 100
            ];

            for (ElectronicMediaGroup grp : groups) {
                options.add(new PicklistOption(grp.Id, grp.Name));
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting media groups: ' + e.getMessage());
        }

        return options;
    }

    /**
     * @description Get available CMS content for linking
     * @param channelId The CMS channel Id (optional - uses first available)
     * @return List of available CMS images
     */
    @AuraEnabled
    public static List<CmsContentOption> getAvailableCmsImages(String channelId) {
        List<CmsContentOption> options = new List<CmsContentOption>();

        try {
            // Get delivery channels
            ConnectApi.ManagedContentChannelCollection channels =
                    ConnectApi.ManagedContent.getAllDeliveryChannels(0, 25);

            if (channels == null || channels.channels == null || channels.channels.isEmpty()) {
                return options;
            }

            // Use provided channel or first available
            String targetChannelId = channelId;
            if (String.isBlank(targetChannelId)) {
                targetChannelId = channels.channels[0].channelId;
            }

            // Get all cms_image content from the channel
            ConnectApi.ManagedContentVersionCollection content =
                    ConnectApi.ManagedContent.getAllContent(
                            targetChannelId,
                            0,
                            50,
                            UserInfo.getLanguage(),
                            'cms_image',
                            false,
                            null,
                            null
                    );

            if (content != null && content.items != null) {
                for (ConnectApi.ManagedContentVersion item : content.items) {
                    CmsContentOption opt = new CmsContentOption();
                    opt.managedContentId = item.managedContentId;
                    opt.title = item.title;
                    opt.contentKey = item.contentKey;

                    // Try to get image URL
                    if (item.contentNodes != null && item.contentNodes.containsKey('source')) {
                        Object sourceNode = item.contentNodes.get('source');
                        if (sourceNode instanceof ConnectApi.ManagedContentMediaSourceNodeValue) {
                            ConnectApi.ManagedContentMediaSourceNodeValue mediaNode =
                                    (ConnectApi.ManagedContentMediaSourceNodeValue)sourceNode;
                            opt.imageUrl = mediaNode.url;
                        }
                    }

                    options.add(opt);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting CMS images: ' + e.getMessage());
        }

        return options;
    }

    /**
     * @description Get product media for a product
     * @param productId The Product2 Id
     * @return List of ProductMedia records with related data
     */
    @AuraEnabled(cacheable=true)
    public static List<ProductMediaInfo> getProductMedia(Id productId) {
        List<ProductMediaInfo> mediaList = new List<ProductMediaInfo>();

        try {
            List<ProductMedia> productMediaRecords = [
                    SELECT Id, ElectronicMediaId, ElectronicMediaGroupId,
                            ElectronicMediaGroup.Name, SortOrder
                    FROM ProductMedia
                    WHERE ProductId = :productId
                    ORDER BY SortOrder ASC
            ];

            for (ProductMedia pm : productMediaRecords) {
                ProductMediaInfo info = new ProductMediaInfo();
                info.id = pm.Id;
                info.electronicMediaId = pm.ElectronicMediaId;
                info.mediaGroupName = pm.ElectronicMediaGroup?.Name;
                info.sortOrder = pm.SortOrder != null ? (Integer)pm.SortOrder : 0;
                mediaList.add(info);
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting product media: ' + e.getMessage());
            throw new AuraHandledException('Error getting product media: ' + e.getMessage());
        }

        return mediaList;
    }

    /**
     * @description Delete product media
     * @param productMediaId The ProductMedia Id to delete
     */
    @AuraEnabled
    public static void deleteProductMedia(Id productMediaId) {
        try {
            List<ProductMedia> mediaToDelete = [
                    SELECT Id
                    FROM ProductMedia
                    WHERE Id = :productMediaId
                    LIMIT 1
            ];

            if (mediaToDelete.isEmpty()) {
                throw new AuraHandledException('Product media record not found');
            }

            delete mediaToDelete;

        } catch (Exception e) {
            throw new AuraHandledException('Error deleting product media: ' + e.getMessage());
        }
    }

    // ===============================
    // WRAPPER CLASSES
    // ===============================

    public class ProductMediaResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id productMediaId { get; set; }
        @AuraEnabled public String managedContentId { get; set; }
        @AuraEnabled public Id electronicMediaGroupId { get; set; }

        public ProductMediaResult() {
            this.success = false;
            this.message = '';
        }
    }

    public class PicklistOption {
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String label { get; set; }

        public PicklistOption(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }

    public class ProductMediaInfo {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String electronicMediaId { get; set; }
        @AuraEnabled public String mediaGroupName { get; set; }
        @AuraEnabled public Integer sortOrder { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String imageUrl { get; set; }
    }

    public class CmsContentOption {
        @AuraEnabled public String managedContentId { get; set; }
        @AuraEnabled public String contentKey { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String imageUrl { get; set; }
    }
}