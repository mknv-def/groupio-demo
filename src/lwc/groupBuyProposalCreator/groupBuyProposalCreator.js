import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getSessionContext } from 'commerce/contextApi';


// Apex methods
import searchProducts from '@salesforce/apex/GroupBuyProposalController.searchProducts';
import createProduct from '@salesforce/apex/GroupBuyProposalController.createProduct';
import createGroupBuyProposal from '@salesforce/apex/GroupBuyProposalController.createGroupBuyProposal';
import getProposalPicklistValues from '@salesforce/apex/GroupBuyProposalController.getProposalPicklistValues';
import getProductPicklistValues from '@salesforce/apex/GroupBuyProposalController.getProductPicklistValues';
import searchAccounts from '@salesforce/apex/GroupBuyProposalController.searchAccounts';

export default class GroupBuyProposalCreator extends NavigationMixin(LightningElement) {
    // Loading and UI state
    @track isLoading = false;
    @track showSuccess = false;
    
    // Product selection mode
    @track productMode = 'search'; // 'search' or 'create'
    
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
    
    // Account search
    @track accountSearchTerm = '';
    @track accountResults = [];
    @track selectedAccount = null;
    accountSearchTimeout;
    
    // Picklist options
    @track statusOptions = [];
    @track typeOptions = [];
    @track brandOptions = [];
    @track characterOptions = [];
    
    // Created proposal reference
    createdProposalId = null;

    // ===============================
    // LIFECYCLE HOOKS
    // ===============================

    async connectedCallback() {
        this.loadPicklistValues();
        try {
            const sessionContext = await getSessionContext();
            this.userId = sessionContext.userId;
            this.proposal.Account__c = sessionContext.effectiveAccountId;
            console.log('User ID:', this.userId);
            console.log('Effective Account ID:', sessionContext.effectiveAccountId);
        } catch (error) {
            console.error('Error fetching session context:', error);
        }
    }
    // ===============================
    // WIRE METHODS
    // ===============================
    
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
    
    get showAccountResults() {
        return this.accountSearchTerm.length >= 2 && !this.selectedAccount;
    }
    
    get hasAccountResults() {
        return this.accountResults && this.accountResults.length > 0;
    }
    
    get isCreateProductDisabled() {
        return !this.newProduct.Name || this.newProduct.Name.trim() === '';
    }
    
    get isCreateProposalDisabled() {
        return !this.proposal.Name || this.proposal.Name.trim() === '';
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
    }
    
    async handleCreateProposal() {
        // Validate required fields
        if (!this.proposal.Name || this.proposal.Name.trim() === '') {
            this.showToast('Error', 'Please enter a proposal name', 'error');
            return;
        }
        
        this.isLoading = true;
        
        try {
            // Prepare proposal data
            const proposalData = {
                ...this.proposal,
                Product__c: this.selectedProduct ? this.selectedProduct.Id : null,
                Account__c: this.selectedAccount ? this.selectedAccount.Id : null
            };
            
            const result = await createGroupBuyProposal({
                proposalData: JSON.stringify(proposalData)
            });
            
            this.createdProposalId = result.Id;
            this.showSuccess = true;
            
            this.showToast('Success', 'Group Buy Proposal created successfully!', 'success');
            
            // Reset form after short delay
            setTimeout(() => {
                this.resetForm();
            }, 2000);
            
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
    
    handleCloseSuccess() {
        this.showSuccess = false;
    }

    // ===============================
    // PRODUCT MODE HANDLERS
    // ===============================
    
    handleSearchMode() {
        this.productMode = 'search';
        // Don't clear selected product when switching modes
    }
    
    handleCreateMode() {
        this.productMode = 'create';
        // Don't clear selected product when switching modes
    }

    // ===============================
    // PRODUCT SEARCH HANDLERS
    // ===============================
    
    handleSearchTermChange(event) {
        const searchValue = event.target.value;
        this.searchTerm = searchValue;
        
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
            this.searchResults = [];
        }
    }
    
    handleRemoveProduct() {
        this.selectedProduct = null;
        this.proposal.Product__c = null;
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
            
            this.showToast('Success', 'Product created successfully!', 'success');
            
        } catch (error) {
            this.showToast('Error', 'Failed to create product: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ===============================
    // ACCOUNT HANDLERS
    // ===============================
    
    handleAccountSearchChange(event) {
        const searchValue = event.target.value;
        this.accountSearchTerm = searchValue;
        
        // Clear previous timeout
        if (this.accountSearchTimeout) {
            clearTimeout(this.accountSearchTimeout);
        }
        
        // Debounce search
        if (searchValue.length >= 2) {
            this.accountSearchTimeout = setTimeout(() => {
                this.performAccountSearch(searchValue);
            }, 300);
        } else {
            this.accountResults = [];
        }
    }
    
    async performAccountSearch(searchTerm) {
        try {
            this.accountResults = await searchAccounts({ searchTerm });
        } catch (error) {
            this.showToast('Error', 'Account search failed: ' + this.reduceErrors(error), 'error');
            this.accountResults = [];
        }
    }
    
    handleAccountSelect(event) {
        const accountId = event.currentTarget.dataset.id;
        const account = this.accountResults.find(a => a.Id === accountId);
        
        if (account) {
            this.selectedAccount = account;
            this.proposal.Account__c = account.Id;
            this.accountSearchTerm = '';
            this.accountResults = [];
        }
    }
    
    handleRemoveAccount() {
        this.selectedAccount = null;
        this.proposal.Account__c = null;
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
            Account__c: null
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
        
        this.accountSearchTerm = '';
        this.accountResults = [];
        this.selectedAccount = null;
        
        this.productMode = 'search';
        this.showSuccess = false;
        this.createdProposalId = null;
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
