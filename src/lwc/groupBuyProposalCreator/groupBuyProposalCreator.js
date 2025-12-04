import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getSessionContext } from 'commerce/contextApi';

// Apex methods
import searchProducts from '@salesforce/apex/GroupBuyProposalController.searchProducts';
import createProduct from '@salesforce/apex/GroupBuyProposalController.createProduct';
import createGroupBuyProposal from '@salesforce/apex/GroupBuyProposalController.createGroupBuyProposal';
import getProposalPicklistValues from '@salesforce/apex/GroupBuyProposalController.getProposalPicklistValues';
import getProductPicklistValues from '@salesforce/apex/GroupBuyProposalController.getProductPicklistValues';
import getAccountById from '@salesforce/apex/GroupBuyProposalController.getAccountById';

export default class GroupBuyProposalCreator extends NavigationMixin(LightningElement) {
    // Loading and UI state
    @track isLoading = false;
    @track showSuccess = false;
    @track activeTab = 'proposal';

    // Validation
    @track showValidationMessage = false;
    @track validationMessage = '';

    // Product selection mode
    @track productMode = 'search'; // 'search' or 'create'

    // User and Account context
    userId = null;
    @track accountId = null;
    @track accountName = '';
    @track accountNumber = '';

    // Proposal data
    @track proposal = {
        Name: '',
        Description__c: '',
        Status__c: 'Created',
        Type__c: '',
        Min_Quota__c: null,
        Max_Quota__c: null,
        Start_Date__c: null,
        End_Date__c: null,
        Approximate_Deliver_Start_Date__c: null,
        Product__c: null,
        Account__c: null
    };

    // Product search
    @track searchTerm = '';
    @track searchResults = [];
    @track selectedProduct = null;
    searchTimeout;

    // New product data
    @track newProduct = {
        Name: '',
        ProductCode: '',
        Description: '',
        IsActive: true,
        Brand__c: '',
        Character__c: '',
        Family: ''
    };

    // Picklist options
    @track statusOptions = [];
    @track typeOptions = [];
    @track brandOptions = [];
    @track characterOptions = [];

    // Created proposal data
    @track createdProposal = null;
    createdProposalId = null;

    // ===============================
    // LIFECYCLE HOOKS
    // ===============================

    async connectedCallback() {
        this.loadPicklistValues();
        try {
            const sessionContext = await getSessionContext();
            console.log( 'Session Context:', JSON.stringify(sessionContext) );
            this.userId = sessionContext.userId;
            this.accountId = sessionContext.effectiveAccountId;
            this.proposal.Account__c = sessionContext.effectiveAccountId;

            // Load account details for display
            if (this.accountId) {
                await this.loadAccountDetails();
            }

            console.log('User ID:', this.userId);
            console.log('Effective Account ID:', this.accountId);
        } catch (error) {
            console.error('Error fetching session context:', error);
        }
    }

    // ===============================
    // DATA LOADING METHODS
    // ===============================

    async loadAccountDetails() {
        try {
            const account = await getAccountById({ accountId: this.accountId });
            if (account) {
                this.accountName = account.Name;
                this.accountNumber = account.AccountNumber || '';
            }
        } catch (error) {
            console.error('Error loading account details:', error);
            this.accountName = 'Your Account';
        }
    }

    async loadPicklistValues() {
        try {
            // Load proposal picklist values
            const proposalPicklists = await getProposalPicklistValues();
            if (proposalPicklists.Status__c) {
                this.statusOptions = proposalPicklists.Status__c.map(item => ({
                    label: item.label,
                    value: item.value
                }));
            }
            if (proposalPicklists.Type__c) {
                this.typeOptions = proposalPicklists.Type__c.map(item => ({
                    label: item.label,
                    value: item.value
                }));
            }

            // Load product picklist values
            const productPicklists = await getProductPicklistValues();
            if (productPicklists.Brand__c) {
                this.brandOptions = [
                    { label: '-- None --', value: '' },
                    ...productPicklists.Brand__c.map(item => ({
                        label: item.label,
                        value: item.value
                    }))
                ];
            }
            if (productPicklists.Character__c) {
                this.characterOptions = [
                    { label: '-- None --', value: '' },
                    ...productPicklists.Character__c.map(item => ({
                        label: item.label,
                        value: item.value
                    }))
                ];
            }
        } catch (error) {
            this.showToast('Error', 'Failed to load picklist values: ' + this.reduceErrors(error), 'error');
        }
    }

    // ===============================
    // GETTERS
    // ===============================

    get isSearchMode() {
        return this.productMode === 'search';
    }

    get isCreateMode() {
        return this.productMode === 'create';
    }

    get searchButtonVariant() {
        return this.productMode === 'search' ? 'brand' : 'neutral';
    }

    get createButtonVariant() {
        return this.productMode === 'create' ? 'brand' : 'neutral';
    }

    get showSearchResults() {
        return this.searchTerm.length >= 2 && !this.selectedProduct;
    }

    get hasSearchResults() {
        return this.searchResults && this.searchResults.length > 0;
    }

    get isCreateProductDisabled() {
        return !this.newProduct.Name || this.newProduct.Name.trim() === '';
    }

    get isCreateProposalDisabled() {
        // Disabled if no name OR no product selected
        return !this.proposal.Name || this.proposal.Name.trim() === '' || !this.selectedProduct;
    }

    get hasAccountId() {
        return this.accountId != null;
    }

    get accountDisplayName() {
        if (this.accountName && this.accountNumber) {
            return `${this.accountName} (${this.accountNumber})`;
        }
        return this.accountName || 'Loading...';
    }

    get productTabLabel() {
        if (this.selectedProduct) {
            return `Product ✓`;
        }
        return 'Product *';
    }

    get createdProposalProductName() {
        return this.createdProposal?.Product__r?.Name || this.selectedProduct?.Name || 'N/A';
    }

    get formattedStartDate() {
        if (this.createdProposal?.Start_Date__c) {
            return new Date(this.createdProposal.Start_Date__c).toLocaleString();
        }
        return 'N/A';
    }

    get formattedEndDate() {
        if (this.createdProposal?.End_Date__c) {
            return new Date(this.createdProposal.End_Date__c).toLocaleString();
        }
        return 'N/A';
    }

    // ===============================
    // PROPOSAL HANDLERS
    // ===============================

    handleProposalChange(event) {
        const field = event.target.name;
        this.proposal = {
            ...this.proposal,
            [field]: event.target.value
        };
        // Clear validation message when user makes changes
        this.showValidationMessage = false;
    }

    validateForm() {
        // Check all required fields
        const requiredFields = [
            { field: 'Name', label: 'Proposal Name' },
            { field: 'Status__c', label: 'Status' },
            { field: 'Type__c', label: 'Type' },
            { field: 'Min_Quota__c', label: 'Min Quota' },
            { field: 'Max_Quota__c', label: 'Max Quota' },
            { field: 'Start_Date__c', label: 'Start Date' },
            { field: 'End_Date__c', label: 'End Date' },
            { field: 'Approximate_Deliver_Start_Date__c', label: 'Delivery Start Date' },
            { field: 'Description__c', label: 'Description' }
        ];

        const missingFields = [];

        for (const { field, label } of requiredFields) {
            const value = this.proposal[field];
            if (value === null || value === undefined || value === '' ||
                (typeof value === 'string' && value.trim() === '')) {
                missingFields.push(label);
            }
        }

        // Check product selection
        if (!this.selectedProduct) {
            missingFields.push('Product (select or create a product)');
        }

        // Check Min/Max quota logic
        if (this.proposal.Min_Quota__c && this.proposal.Max_Quota__c) {
            if (Number(this.proposal.Min_Quota__c) > Number(this.proposal.Max_Quota__c)) {
                this.validationMessage = 'Min Quota cannot be greater than Max Quota';
                this.showValidationMessage = true;
                return false;
            }
        }

        // Check dates
        if (this.proposal.Start_Date__c && this.proposal.End_Date__c) {
            const startDate = new Date(this.proposal.Start_Date__c);
            const endDate = new Date(this.proposal.End_Date__c);
            if (startDate >= endDate) {
                this.validationMessage = 'End Date must be after Start Date';
                this.showValidationMessage = true;
                return false;
            }
        }

        if (missingFields.length > 0) {
            this.validationMessage = `Please fill in all required fields: ${missingFields.join(', ')}`;
            this.showValidationMessage = true;
            return false;
        }

        // Run standard Lightning input validation
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')]
            .reduce((validSoFar, inputField) => {
                inputField.reportValidity();
                return validSoFar && inputField.checkValidity();
            }, true);

        return allValid;
    }

    async handleCreateProposal() {
        console.log( 'Creating proposal with data:', this.proposal, 'and selected product:', this.selectedProduct );
        // Validate form
        if (!this.validateForm()) {
            this.showToast('Validation Error', 'Please fill in all required fields', 'error');
            return;
        }

        this.isLoading = true;
        this.showValidationMessage = false;

        try {
            // Prepare proposal data
            const proposalData = {
                ...this.proposal,
                Product__c: this.selectedProduct.Id,
                Account__c: this.accountId
            };
console.log( 'Submitting proposal data:', proposalData );
            const result = await createGroupBuyProposal({
                proposalData: JSON.stringify(proposalData)
            });

            this.createdProposalId = result.Id;
            this.createdProposal = result;
            this.showSuccess = true;
console.log( 'Proposal created successfully:', result );
            this.showToast('Success', 'Group Buy Proposal created successfully!', 'success');

        } catch (error) {
            this.showToast('Error', 'Failed to create proposal: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.resetForm();

        // Dispatch cancel event for parent components
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleCreateAnother() {
        this.resetForm();
        this.showSuccess = false;
        this.createdProposal = null;
        this.createdProposalId = null;
    }

    // ===============================
    // PRODUCT MODE HANDLERS
    // ===============================

    handleSearchMode() {
        this.productMode = 'search';
    }

    handleCreateMode() {
        this.productMode = 'create';
    }

    // ===============================
    // PRODUCT SEARCH HANDLERS
    // ===============================

    handleSearchTermChange(event) {
        const searchValue = event.target.value;
        this.searchTerm = searchValue;
console.log( 'Search term changed to:', searchValue );
        // Clear previous timeout
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }

        // Debounce search
        if (searchValue.length >= 2) {
            this.searchTimeout = setTimeout(() => {
                this.performProductSearch(searchValue);
            }, 300);
        } else {
            this.searchResults = [];
        }
    }

    async performProductSearch(searchTerm) {
        console.log( 'Searching products for term:', searchTerm );
        try {
            this.searchResults = await searchProducts({ searchTerm });
        } catch (error) {
            this.showToast('Error', 'Search failed: ' + this.reduceErrors(error), 'error');
            this.searchResults = [];
        }
    }

    handleProductSelect(event) {
        const productId = event.currentTarget.dataset.id;
        const product = this.searchResults.find(p => p.Id === productId);

        if (product) {
            this.selectedProduct = product;
            this.proposal.Product__c = product.Id;
            this.searchTerm = '';
            this.productMode = '';
            this.searchResults = [];
            this.showValidationMessage = false;
        }
    }

    handleRemoveProduct() {
        this.selectedProduct = null;
        this.proposal.Product__c = null;
        this.productMode = 'search';
    }

    // ===============================
    // NEW PRODUCT HANDLERS
    // ===============================

    handleNewProductChange(event) {
        const field = event.target.name;
        this.newProduct = {
            ...this.newProduct,
            [field]: event.target.value
        };
    }

    handleNewProductCheckbox(event) {
        this.newProduct = {
            ...this.newProduct,
            IsActive: event.target.checked
        };
    }

    async handleCreateProduct() {
        if (!this.newProduct.Name || this.newProduct.Name.trim() === '') {
            this.showToast('Error', 'Please enter a product name', 'error');
            return;
        }

        this.isLoading = true;

        try {
            const result = await createProduct({
                productData: JSON.stringify(this.newProduct)
            });

            // Set the created product as selected
            this.selectedProduct = result;
            this.proposal.Product__c = result.Id;

            // Reset new product form
            this.newProduct = {
                Name: '',
                ProductCode: '',
                Description: '',
                IsActive: true,
                Brand__c: '',
                Character__c: '',
                Family: ''
            };

            this.showValidationMessage = false;
            this.showToast('Success', 'Product created successfully!', 'success');
            this.productMode = '';
        } catch (error) {
            this.showToast('Error', 'Failed to create product: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ===============================
    // UTILITY METHODS
    // ===============================

    resetForm() {
        this.proposal = {
            Name: '',
            Description__c: '',
            Status__c: 'Created',
            Type__c: '',
            Min_Quota__c: null,
            Max_Quota__c: null,
            Start_Date__c: null,
            End_Date__c: null,
            Approximate_Deliver_Start_Date__c: null,
            Product__c: null,
            Account__c: this.accountId // Keep the account ID
        };

        this.searchTerm = '';
        this.searchResults = [];
        this.selectedProduct = null;

        this.newProduct = {
            Name: '',
            ProductCode: '',
            Description: '',
            IsActive: true,
            Brand__c: '',
            Character__c: '',
            Family: ''
        };

        this.productMode = 'search';
        this.showValidationMessage = false;
        this.validationMessage = '';
        this.activeTab = 'proposal';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    reduceErrors(error) {
        if (typeof error === 'string') {
            return error;
        }

        if (error.body) {
            if (typeof error.body.message === 'string') {
                return error.body.message;
            }
            if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                return error.body.pageErrors.map(e => e.message).join(', ');
            }
            if (error.body.fieldErrors) {
                const fieldErrors = Object.values(error.body.fieldErrors);
                return fieldErrors.flat().map(e => e.message).join(', ');
            }
        }

        if (error.message) {
            return error.message;
        }

        return 'Unknown error';
    }

    // ===============================
    // NAVIGATION (Optional)
    // ===============================

    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }
}