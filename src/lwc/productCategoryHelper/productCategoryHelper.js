import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ProductCategoryHelper extends LightningElement {
    @api product; // The full product object from ConnectApi
    @api accountId; // The effective Account ID

    @track showCaseForm = false;
    @track isLoading = false;

    // ===============================
    // GETTERS
    // ===============================

    connectedCallback() {
        console.log('ProductCategoryHelper initialized with product:', JSON.stringify(this.product));
    }

    get hasCategories() {
        return this.categories && this.categories.length > 0;
    }

    get categories() {
        if (this.product &&
            this.product.primaryProductCategoryPath &&
            this.product.primaryProductCategoryPath.path) {

            // FILTER: Exclude "Unavailable Products" from the list
            return this.product.primaryProductCategoryPath.path.filter(
                cat => cat.name !== 'Unavailable Products'
            );
        }
        return [];
    }

    get productName() {
        console.log( 'Retrieving product name for product:', JSON.stringify(this.product) );

        return this.product?.fields?.Name?.value // ConnectApi structure
            || this.product?.fields?.Name        // Alternative ConnectApi/SObject structure
            || this.product?.Name                // SObject structure (Capital N) <--- THIS IS WHAT YOU NEED
            || this.product?.name                // Fallback (Lowercase n)
            || 'Unknown Product';
    }

    // Hardcoded Case Values
    get caseSubject() {
        return `Category Request: ${this.productName}`;
    }

    get caseDescription() {
        const pCode = this.product?.fields?.ProductCode || this.product?.ProductCode || 'N/A';
        const pId = this.product?.id || this.product?.Id || 'N/A';
        return `System Request: Please assign a category to Product '${this.productName}' (Code: ${pCode}, ID: ${pId}).`;
    }

    // ===============================
    // HANDLERS
    // ===============================

    handleRequestClick() {
        this.showCaseForm = true;
    }

    handleCancel() {
        this.showCaseForm = false;
    }

    handleSubmit(event) {
        this.isLoading = true;
        // You can intercept and modify fields here if needed,
        // but since we mapped them in HTML, we just let it submit.
        console.log('Submitting Case Request...');
    }

    handleSuccess(event) {
        this.isLoading = false;
        this.showCaseForm = false;

        const evt = new ShowToastEvent({
            title: 'Request Sent',
            message: 'Case created successfully! ID: ' + event.detail.id,
            variant: 'success',
        });
        this.dispatchEvent(evt);
    }

    handleError(event) {
        this.isLoading = false;
        console.error('Case Creation Error:', event.detail);
        const evt = new ShowToastEvent({
            title: 'Error',
            message: 'Failed to create request. ' + (event.detail.detail || event.detail.message),
            variant: 'error',
        });
        this.dispatchEvent(evt);
    }
}