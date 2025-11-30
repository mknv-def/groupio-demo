import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProduct from '@salesforce/apex/B2BGetInfo.getProduct';
import uploadProductImageToCms from '@salesforce/apex/ProductMediaController.uploadProductImageToCms';
import linkCmsContentToProduct from '@salesforce/apex/ProductMediaController.linkCmsContentToProduct';
import getMediaGroups from '@salesforce/apex/ProductMediaController.getMediaGroups';
import getAvailableCmsImages from '@salesforce/apex/ProductMediaController.getAvailableCmsImages';
import communityId from '@salesforce/community/Id';
import { resolve } from 'c/cmsResourceResolver';

/**
 * Component to display product details with image upload capability
 * Supports:
 * 1. Uploading images directly to Salesforce CMS via REST API
 * 2. Linking existing CMS content to product
 */
export default class SelectedProductDetails extends LightningElement {
    @api recordId; // Product2.Id
    @api effectiveAccountId;
    @api existingProductData; // Optional pre-fetched product data

    @track product = {};
    @track isLoading = true;
    @track isUploading = false;
    @track error;

    // Upload modal state
    @track showUploadModal = false;
    @track uploadMode = 'upload'; // 'upload' or 'link'
    @track selectedFileName = '';
    @track selectedFileData = null;
    @track selectedFileType = '';
    @track mediaGroupOptions = [];
    @track selectedMediaGroup = 'Product List Image';

    // Link existing CMS content
    @track availableCmsImages = [];
    @track selectedCmsContentId = '';
    @track isLoadingCmsImages = false;


    @track categories = [];
    @track hasCategories = false;

    // Accepted file types
    acceptedFormats = '.jpg,.jpeg,.png,.gif,.webp';

    connectedCallback() {
        console.log('SelectedProductDetails connectedCallback, recordId:', this.recordId);
        console.log('SelectedProductDetails connectedCallback, effectiveAccountId:', this.effectiveAccountId);
        this.loadProductData();
        this.loadMediaGroups();
    }

    // ===============================
    // DATA LOADING
    // ===============================

    loadProductData() {
        this.isLoading = true;
        const params = {
            communityId: communityId,
            productId: this.recordId,
            effectiveAccountId: this.effectiveAccountId
        };

        getProduct(params)
            .then(data => {
                if (data) {
                    this.product = {
                        name: data.fields?.Name || 'Unknown Product',
                        description: data.fields?.Description || '',
                        imageUrl: this.resolveImageUrl(data.defaultImage?.url),
                        // Store the full response to pass to child component
                        rawData: data
                    };
                    this.error = undefined;
                } else {
                    if( this.existingProductData ) {
                        console.log('Using existing product data passed in:', this.existingProductData);
                        this.product = {
                            name: this.existingProductData.Name || 'Unknown Product',
                            description: this.existingProductData.Description || '',
                            rawData: this.existingProductData
                        };
                        this.isLoading = false;
                    } else {
                        this.error = 'Product not found or access denied for this account.';
                        this.product = {};
                    }
                }
            })
            .catch(error => {
                if( this.existingProductData ) {
                    console.log('Using existing product data passed in:', JSON.stringify( this.existingProductData ));
                    this.product = {
                        name: this.existingProductData.Name || 'Unknown Product',
                        description: this.existingProductData.Description || '',
                        rawData: JSON.parse(JSON.stringify( this.existingProductData ) )
                    };
                    this.isLoading = false;
                } else {
                    this.error = 'Error loading product: ' + this.reduceErrors(error);
                    this.product = {};
                    console.error('Error loading product data:', this.error);
                }

            })
            .finally(() => {
                this.isLoading = false;
            });

    }

    resolveImageUrl(url) {
        if (!url) return null;
        if (url.includes('default-product-image')) return null;
        return resolve(url);
    }

    async loadMediaGroups() {
        try {
            const groups = await getMediaGroups();
            this.mediaGroupOptions = groups.map(g => ({
                label: g.label,
                value: g.label // Use label as value since we pass name to apex
            }));

            // Add default options if empty
            if (this.mediaGroupOptions.length === 0) {
                this.mediaGroupOptions = [
                    { label: 'Product List Image', value: 'Product List Image' },
                    { label: 'Product Detail Images', value: 'Product Detail Images' }
                ];
            }
        } catch (error) {
            console.error('Error loading media groups:', error);
            this.mediaGroupOptions = [
                { label: 'Product List Image', value: 'Product List Image' },
                { label: 'Product Detail Images', value: 'Product Detail Images' }
            ];
        }
    }

    async loadAvailableCmsImages() {
        this.isLoadingCmsImages = true;
        try {
            this.availableCmsImages = await getAvailableCmsImages({ channelId: null });
        } catch (error) {
            console.error('Error loading CMS images:', error);
            this.availableCmsImages = [];
        } finally {
            this.isLoadingCmsImages = false;
        }
    }

    // ===============================
    // GETTERS
    // ===============================

    get hasProduct() {
        return this.product && this.product.name;
    }

    get hasImage() {
        return !!this.product.imageUrl;
    }

    get productImageURL() {
        return this.product.imageUrl || '';
    }

    get hasSelectedFile() {
        return !!this.selectedFileData;
    }

    get uploadButtonDisabled() {
        if (this.uploadMode === 'upload') {
            return !this.selectedFileData || this.isUploading;
        } else {
            return !this.selectedCmsContentId || this.isUploading;
        }
    }

    get uploadButtonLabel() {
        if (this.isUploading) {
            return 'Processing...';
        }
        return this.uploadMode === 'upload' ? 'Upload to CMS' : 'Link to Product';
    }

    get isUploadMode() {
        return this.uploadMode === 'upload';
    }

    get isLinkMode() {
        return this.uploadMode === 'link';
    }

    get uploadModeVariant() {
        return this.uploadMode === 'upload' ? 'brand' : 'neutral';
    }

    get linkModeVariant() {
        return this.uploadMode === 'link' ? 'brand' : 'neutral';
    }

    get hasCmsImages() {
        return this.availableCmsImages && this.availableCmsImages.length > 0;
    }

    get cmsImageOptions() {
        return this.availableCmsImages.map(img => ({
            label: img.title || img.managedContentId,
            value: img.managedContentId
        }));
    }

    // ===============================
    // UPLOAD MODAL HANDLERS
    // ===============================

    handleOpenUploadModal() {
        this.showUploadModal = true;
        this.resetUploadForm();
        // Load available CMS images for linking
        this.loadAvailableCmsImages();
    }

    handleCloseUploadModal() {
        this.showUploadModal = false;
        this.resetUploadForm();
    }

    resetUploadForm() {
        this.selectedFileName = '';
        this.selectedFileData = null;
        this.selectedFileType = '';
        this.selectedMediaGroup = 'Product List Image';
        this.selectedCmsContentId = '';
        this.uploadMode = 'upload';
    }

    handleUploadModeClick() {
        this.uploadMode = 'upload';
    }

    handleLinkModeClick() {
        this.uploadMode = 'link';
    }

    handleMediaGroupChange(event) {
        this.selectedMediaGroup = event.detail.value;
    }

    handleCmsContentChange(event) {
        this.selectedCmsContentId = event.detail.value;
    }

    // ===============================
    // FILE SELECTION HANDLER
    // ===============================

    handleFileChange(event) {
        const file = event.target.files[0];

        if (!file) {
            this.resetFileSelection();
            return;
        }

        // Validate file type
        const validTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
        if (!validTypes.includes(file.type)) {
            this.showToast('Error', 'Please select a valid image file (JPEG, PNG, GIF, or WebP)', 'error');
            this.resetFileSelection();
            return;
        }

        // Validate file size (max 5MB)
        const maxSize = 5 * 1024 * 1024; // 5MB
        if (file.size > maxSize) {
            this.showToast('Error', 'File size must be less than 5MB', 'error');
            this.resetFileSelection();
            return;
        }

        this.selectedFileName = file.name;
        this.selectedFileType = file.type;

        // Read file as base64
        const reader = new FileReader();
        reader.onload = () => {
            // Remove the data URL prefix (e.g., "data:image/jpeg;base64,")
            const base64 = reader.result.split(',')[1];
            this.selectedFileData = base64;
        };
        reader.onerror = () => {
            this.showToast('Error', 'Failed to read the file', 'error');
            this.resetFileSelection();
        };
        reader.readAsDataURL(file);
    }

    resetFileSelection() {
        this.selectedFileName = '';
        this.selectedFileData = null;
        this.selectedFileType = '';
    }

    // ===============================
    // ACTION HANDLER
    // ===============================

    async handleActionClick() {
        if (this.uploadMode === 'upload') {
            await this.handleUploadToCms();
        } else {
            await this.handleLinkExisting();
        }
    }

    // ===============================
    // CMS UPLOAD HANDLER
    // ===============================

    async handleUploadToCms() {
        if (!this.selectedFileData) {
            this.showToast('Error', 'Please select a file first', 'error');
            return;
        }

        this.isUploading = true;

        try {
            const result = await uploadProductImageToCms({
                productId: this.recordId,
                fileName: this.selectedFileName,
                base64Data: this.selectedFileData,
                contentType: this.selectedFileType,
                mediaGroupName: this.selectedMediaGroup
            });

            if (result.success) {
                this.showToast(
                    'Processing',
                    'Image upload started. The image will appear shortly.',
                    'success'
                );

                this.handleCloseUploadModal();
                this.dispatchImageUploadEvent(result);

                // Auto-refresh after a delay to show the new image
                // The Queueable typically completes within a few seconds
                setTimeout(() => {
                    this.loadProductData();
                }, 3000);

                // Refresh again after a longer delay in case of slower processing
                setTimeout(() => {
                    this.loadProductData();
                }, 8000);
            } else {
                this.showToast('Error', result.message || 'Upload failed', 'error');
            }
        } catch (error) {
            console.error('Upload error:', error);
            this.showToast('Error', 'Upload failed: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isUploading = false;
        }
    }

    // ===============================
    // LINK EXISTING CMS CONTENT
    // ===============================

    async handleLinkExisting() {
        if (!this.selectedCmsContentId) {
            this.showToast('Error', 'Please select a CMS image to link', 'error');
            return;
        }

        this.isUploading = true;

        try {
            const result = await linkCmsContentToProduct({
                productId: this.recordId,
                managedContentId: this.selectedCmsContentId,
                mediaGroupName: this.selectedMediaGroup
            });

            if (result.success) {
                this.showToast(
                    'Success',
                    'CMS content linked to product successfully!',
                    'success'
                );

                this.handleCloseUploadModal();
                this.loadProductData();
                this.dispatchImageUploadEvent(result);
            } else {
                this.showToast('Error', result.message || 'Link failed', 'error');
            }
        } catch (error) {
            console.error('Link error:', error);
            this.showToast('Error', 'Link failed: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isUploading = false;
        }
    }

    dispatchImageUploadEvent(result) {
        this.dispatchEvent(new CustomEvent('imageupload', {
            detail: {
                productId: this.recordId,
                managedContentId: result.managedContentId,
                productMediaId: result.productMediaId
            }
        }));
    }

    // ===============================
    // LEGACY FILE UPLOAD (ContentDocument)
    // ===============================

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.showToast(
                'File Uploaded',
                'File uploaded as ContentDocument. For B2B Commerce, use the modal to upload to CMS or link existing CMS content.',
                'warning',
                'sticky'
            );
        }
    }

    // ===============================
    // UTILITY METHODS
    // ===============================

    showToast(title, message, variant, mode = 'dismissable') {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
                mode
            })
        );
    }

    reduceErrors(error) {
        if (typeof error === 'string') {
            return error;
        }
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Unknown error';
    }
}