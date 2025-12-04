import { LightningElement, api, track } from 'lwc';
import searchProducts from '@salesforce/apex/GroupBuyProposalController.searchProducts';
import createProduct from '@salesforce/apex/GroupBuyProposalController.createProduct';
import getProductPicklistValues from '@salesforce/apex/GroupBuyProposalController.getProductPicklistValues';

export default class GroupBuyProductSelector extends LightningElement {
    @api selectedProduct = null;

    @track mode = 'search'; // 'search' or 'create'
    @track searchTerm = '';
    @track searchResults = [];
    @track isSearching = false;
    @track isCreating = false;

    // New product
    @track newProduct = {
        Name: '',
        ProductCode: '',
        Description: '',
        IsActive: true,
        Brand__c: '',
        Character__c: ''
    };

    // Picklists
    @track brandOptions = [];
    @track characterOptions = [];

    searchTimeout;

    connectedCallback() {
        this.loadPicklistValues();
    }

    async loadPicklistValues() {
        try {
            const picklists = await getProductPicklistValues();
            if (picklists.Brand__c) {
                this.brandOptions = [
                    { label: '-- None --', value: '' },
                    ...picklists.Brand__c.map(item => ({ label: item.label, value: item.value }))
                ];
            }
            if (picklists.Character__c) {
                this.characterOptions = [
                    { label: '-- None --', value: '' },
                    ...picklists.Character__c.map(item => ({ label: item.label, value: item.value }))
                ];
            }
        } catch (error) {
            console.error('Error loading picklists:', error);
        }
    }

    // ===============================
    // GETTERS
    // ===============================

    get hasSelectedProduct() {
        return !!this.selectedProduct;
    }

    get isSearchMode() {
        return this.mode === 'search' && !this.hasSelectedProduct;
    }

    get isCreateMode() {
        return this.mode === 'create' && !this.hasSelectedProduct;
    }

    get showSearchResults() {
        return this.searchTerm.length >= 2 && this.searchResults.length > 0;
    }

    get showNoResults() {
        return this.searchTerm.length >= 2 && this.searchResults.length === 0 && !this.isSearching;
    }

    get searchButtonVariant() {
        return this.mode === 'search' ? 'brand' : 'neutral';
    }

    get createButtonVariant() {
        return this.mode === 'create' ? 'brand' : 'neutral';
    }

    get isCreateDisabled() {
        return !this.newProduct.Name || this.newProduct.Name.trim() === '';
    }

    // ===============================
    // MODE HANDLERS
    // ===============================

    handleSearchMode() {
        this.mode = 'search';
    }

    handleCreateMode() {
        this.mode = 'create';
    }

    // ===============================
    // SEARCH HANDLERS
    // ===============================

    handleSearchChange(event) {
        this.searchTerm = event.target.value;

        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }

        if (this.searchTerm.length >= 2) {
            this.isSearching = true;
            this.searchTimeout = setTimeout(() => {
                this.performSearch();
            }, 300);
        } else {
            this.searchResults = [];
        }
    }

    async performSearch() {
        try {
            this.searchResults = await searchProducts({ searchTerm: this.searchTerm });
        } catch (error) {
            console.error('Search error:', error);
            this.searchResults = [];
        } finally {
            this.isSearching = false;
        }
    }

    handleProductClick(event) {
        const productId = event.currentTarget.dataset.id;
        const product = this.searchResults.find(p => p.Id === productId);

        if (product) {
            this.dispatchEvent(new CustomEvent('select', {
                detail: { product }
            }));
            this.searchTerm = '';
            this.searchResults = [];
        }
    }

    // ===============================
    // CREATE HANDLERS
    // ===============================

    handleNewProductChange(event) {
        const field = event.target.name;
        this.newProduct = {
            ...this.newProduct,
            [field]: event.target.type === 'checkbox' ? event.target.checked : event.target.value
        };
    }

    async handleCreateProduct() {
        if (this.isCreateDisabled) return;

        this.isCreating = true;

        try {
            const result = await createProduct({
                productData: JSON.stringify(this.newProduct)
            });

            this.dispatchEvent(new CustomEvent('select', {
                detail: { product: result }
            }));

            this.resetNewProduct();
            this.mode = 'search';

        } catch (error) {
            console.error('Create product error:', error);
        } finally {
            this.isCreating = false;
        }
    }

    resetNewProduct() {
        this.newProduct = {
            Name: '',
            ProductCode: '',
            Description: '',
            IsActive: true,
            Brand__c: '',
            Character__c: ''
        };
    }

    // ===============================
    // REMOVE HANDLER
    // ===============================

    handleRemoveProduct() {
        this.dispatchEvent(new CustomEvent('remove'));
    }
}
