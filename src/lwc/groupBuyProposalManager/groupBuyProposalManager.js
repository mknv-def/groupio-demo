import { LightningElement, api, track } from 'lwc';
import { getSessionContext } from 'commerce/contextApi';

// Apex methods
import searchProducts from '@salesforce/apex/GroupBuyProposalController.searchProducts';
import createProduct from '@salesforce/apex/GroupBuyProposalController.createProduct';
import createGroupBuyProposal from '@salesforce/apex/GroupBuyProposalController.createGroupBuyProposal';
import getProposalPicklistValues from '@salesforce/apex/GroupBuyProposalController.getProposalPicklistValues';
import getProductPicklistValues from '@salesforce/apex/GroupBuyProposalController.getProductPicklistValues';
import getAccountById from '@salesforce/apex/GroupBuyProposalController.getAccountById';
import getMyProposals from '@salesforce/apex/GroupBuyProposalController.getMyProposals';
import updateProposal from '@salesforce/apex/GroupBuyProposalController.updateProposal';
import deleteProposal from '@salesforce/apex/GroupBuyProposalController.deleteProposal';

export default class GroupBuyProposalManager extends LightningElement {
    @api title;

    // ===============================
    // LOADING AND UI STATE
    // ===============================
    @track isLoading = false;
    @track showSuccess = false;
    @track mainActiveTab = 'create'; // 'create' or 'manage'
    @track createActiveTab = 'proposal';

    // Notification state
    @track notification = null;
    notificationTimeout = null;

    // Validation
    @track showValidationMessage = false;
    @track validationMessage = '';

    // Product selection mode
    @track productMode = 'search'; // 'search' or 'create'

    // ===============================
    // USER AND ACCOUNT CONTEXT
    // ===============================
    userId = null;
    @track accountId = null;
    @track accountName = '';
    @track accountNumber = '';
    @track isPreview = false;

    // ===============================
    // PROPOSAL DATA (CREATE)
    // ===============================
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
        Base_Price__c: null,
        Product__c: null,
        Account__c: null
    };

    // ===============================
    // PRODUCT SEARCH
    // ===============================
    @track searchTerm = '';
    @track searchResults = [];
    @track selectedProduct = null;
    searchTimeout;

    // ===============================
    // NEW PRODUCT DATA
    // ===============================
    @track newProduct = {
        Name: '',
        ProductCode: '',
        Description: '',
        IsActive: true,
        Brand__c: '',
        Character__c: '',
        Family: ''
    };

    // ===============================
    // PICKLIST OPTIONS
    // ===============================
    @track statusOptions = [];
    @track typeOptions = [];
    @track brandOptions = [];
    @track characterOptions = [];

    // ===============================
    // CREATED PROPOSAL DATA
    // ===============================
    @track createdProposal = null;
    createdProposalId = null;

    // ===============================
    // MY PROPOSALS (MANAGE TAB)
    // ===============================
    @track myProposals = [];
    @track isLoadingProposals = false;
    @track selectedProposalForEdit = null;
    @track showEditModal = false;
    @track showDeleteModal = false;
    @track proposalToDelete = null;
    @track editProposal = {};
    @track isProcessing = false;

    // ===============================
    // LIFECYCLE HOOKS
    // ===============================

    async connectedCallback() {
        await this.loadPicklistValues();
        try {
            const sessionContext = await getSessionContext();
            console.log('Session Context:', JSON.stringify(sessionContext));
            this.userId = sessionContext.userId;
            this.accountId = sessionContext.effectiveAccountId;
            this.isPreview = sessionContext.isPreview || false;
            this.proposal.Account__c = sessionContext.effectiveAccountId;

            if (this.accountId) {
                await this.loadAccountDetails();
            }

            console.log('User ID:', this.userId);
            console.log('Effective Account ID:', this.accountId);
        } catch (error) {
            console.error('Error fetching session context:', error);
        }
    }

    disconnectedCallback() {
        if (this.notificationTimeout) {
            clearTimeout(this.notificationTimeout);
        }
    }

    // ===============================
    // NOTIFICATION SYSTEM
    // ===============================

    showNotification(message, variant = 'success') {
        if (this.notificationTimeout) {
            clearTimeout(this.notificationTimeout);
        }

        this.notification = {
            message,
            variant,
            isSuccess: variant === 'success',
            isError: variant === 'error',
            isInfo: variant === 'info'
        };

        this.notificationTimeout = setTimeout(() => {
            this.notification = null;
        }, 5000);
    }

    handleCloseNotification() {
        this.notification = null;
        if (this.notificationTimeout) {
            clearTimeout(this.notificationTimeout);
        }
    }

    get hasNotification() {
        return !!this.notification;
    }

    get notificationClass() {
        if (!this.notification) return '';
        const base = 'notification';
        if (this.notification.isSuccess) return `${base} notification-success`;
        if (this.notification.isError) return `${base} notification-error`;
        return `${base} notification-info`;
    }

    get notificationIcon() {
        if (!this.notification) return 'utility:info';
        if (this.notification.isSuccess) return 'utility:success';
        if (this.notification.isError) return 'utility:error';
        return 'utility:info';
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
            this.showNotification('Failed to load picklist values: ' + this.reduceErrors(error), 'error');
        }
    }

    async loadMyProposals() {
        this.isLoadingProposals = true;
        try {
            this.myProposals = await getMyProposals({
                accountId: this.accountId
            });
            console.log( 'Loaded My Proposals:', this.myProposals );
        } catch (error) {
            console.error('Error loading proposals:', error);
            this.showNotification('Failed to load proposals: ' + this.reduceErrors(error), 'error');
            this.myProposals = [];
        } finally {
            this.isLoadingProposals = false;
        }
    }

    // ===============================
    // MAIN TAB HANDLING
    // ===============================

    handleMainTabActive(event) {
        console.log('Loading My Proposals for Manage Tab');
        this.mainActiveTab = event.target.value;
        console.log('Active Main Tab:', this.mainActiveTab);
        if (this.mainActiveTab === 'manage') {
            console.log('Loading My Proposals for Manage Tab');
            this.loadMyProposals();
        }
    }

    // ===============================
    // GETTERS - GENERAL
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

    get formattedBasePrice() {
        if (this.createdProposal?.Base_Price__c != null) {
            return new Intl.NumberFormat('en-US', {
                style: 'currency',
                currency: 'USD'
            }).format(this.createdProposal.Base_Price__c);
        }
        return 'N/A';
    }

    get isNoProductSelected() {
        return !this.selectedProduct;
    }

    // ===============================
    // GETTERS - MY PROPOSALS
    // ===============================

    get hasMyProposals() {
        return this.myProposals && this.myProposals.length > 0;
    }

    get myProposalsDisplay() {
        if (!this.myProposals) return [];

        return this.myProposals.map(p => {
            const progress = p.Progress_Percentage__c || 0;
            return {
                ...p,
                productName: p.Product__r?.Name || 'N/A',
                startDateFormatted: p.Start_Date__c ? new Date(p.Start_Date__c).toLocaleDateString() : 'N/A',
                endDateFormatted: p.End_Date__c ? new Date(p.End_Date__c).toLocaleDateString() : 'N/A',
                progressStyle: `width: ${Math.min(100, progress * 100)}%`,
                progressText: `${Math.round(progress * 100)}%`,
                progressClass: progress >= 1 ? 'progress-text goal-reached' : 'progress-text',
                basePriceFormatted: p.Base_Price__c != null
                    ? new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(p.Base_Price__c)
                    : 'N/A',
                statusClass: this.getStatusClass(p.Status__c),
                canEdit: ['Created', 'Pending Approval', 'Rejected'].includes(p.Status__c),
                canDelete: ['Created', 'Rejected'].includes(p.Status__c),
                canActivate: p.Status__c === 'Approved',
                canClose: ['Active', 'Expired'].includes(p.Status__c),
                isCreated: p.Status__c === 'Created'
            };
        });
    }

    getStatusClass(status) {
        const statusClasses = {
            'Created': 'status-badge status-created',
            'Pending Approval': 'status-badge status-pending',
            'Approved': 'status-badge status-approved',
            'Active': 'status-badge status-active',
            'Rejected': 'status-badge status-rejected',
            'Expired': 'status-badge status-expired',
            'Closed': 'status-badge status-closed'
        };
        return statusClasses[status] || 'status-badge';
    }

    // ===============================
    // PROPOSAL HANDLERS (CREATE)
    // ===============================

    handleProposalChange(event) {
        const field = event.target.name;
        this.proposal = {
            ...this.proposal,
            [field]: event.target.value
        };
        this.showValidationMessage = false;
    }

    validateForm() {
        const requiredFields = [
            { field: 'Name', label: 'Proposal Name' },
            { field: 'Status__c', label: 'Status' },
            { field: 'Type__c', label: 'Type' },
            { field: 'Min_Quota__c', label: 'Min Quota' },
            { field: 'Max_Quota__c', label: 'Max Quota' },
            { field: 'Start_Date__c', label: 'Start Date' },
            { field: 'End_Date__c', label: 'End Date' },
            { field: 'Approximate_Deliver_Start_Date__c', label: 'Delivery Start Date' },
            { field: 'Base_Price__c', label: 'Base Price' }
        ];

        const missingFields = [];

        for (const { field, label } of requiredFields) {
            if (!this.proposal[field] || this.proposal[field] === '') {
                missingFields.push(label);
            }
        }

        if (!this.selectedProduct) {
            missingFields.push('Product');
        }

        if (missingFields.length > 0) {
            this.showValidationMessage = true;
            this.validationMessage = `Please fill in the following required fields: ${missingFields.join(', ')}`;
            return false;
        }

        // Validate Min <= Max
        if (Number(this.proposal.Min_Quota__c) > Number(this.proposal.Max_Quota__c)) {
            this.showValidationMessage = true;
            this.validationMessage = 'Min Quota cannot be greater than Max Quota';
            return false;
        }

        // Validate dates
        const startDate = new Date(this.proposal.Start_Date__c);
        const endDate = new Date(this.proposal.End_Date__c);
        if (startDate >= endDate) {
            this.showValidationMessage = true;
            this.validationMessage = 'End Date must be after Start Date';
            return false;
        }

        return true;
    }

    async handleCreateProposal() {
        if (!this.validateForm()) {
            this.showNotification('Please fill in all required fields', 'error');
            return;
        }

        this.isLoading = true;
        this.showValidationMessage = false;

        try {
            const proposalData = {
                ...this.proposal,
                Product__c: this.selectedProduct.Id,
                Account__c: this.accountId
            };

            const result = await createGroupBuyProposal({
                proposalData: JSON.stringify(proposalData)
            });

            this.createdProposalId = result.Id;
            this.createdProposal = result;
            this.showSuccess = true;
            this.showNotification('Group Buy Proposal created successfully!', 'success');

        } catch (error) {
            this.showNotification('Failed to create proposal: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.resetForm();
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

        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }

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
            this.showNotification('Search failed: ' + this.reduceErrors(error), 'error');
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
            this.showNotification('Please enter a product name', 'error');
            return;
        }

        this.isLoading = true;

        try {
            const result = await createProduct({
                productData: JSON.stringify(this.newProduct)
            });

            this.selectedProduct = result;
            this.proposal.Product__c = result.Id;

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
            this.showNotification('Product created successfully!', 'success');
            this.productMode = '';
        } catch (error) {
            this.showNotification('Failed to create product: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ===============================
    // MY PROPOSALS HANDLERS (MANAGE)
    // ===============================

    handleEditProposal(event) {
        const proposalId = event.currentTarget.dataset.id;
        const proposal = this.myProposals.find(p => p.Id === proposalId);

        if (proposal) {
            this.selectedProposalForEdit = proposal;
            this.editProposal = { ...proposal };
            this.showEditModal = true;
        }
    }

    handleCloseEditModal() {
        this.showEditModal = false;
        this.selectedProposalForEdit = null;
        this.editProposal = {};
    }

    handleEditProposalChange(event) {
        const field = event.target.name;
        this.editProposal = {
            ...this.editProposal,
            [field]: event.target.value
        };
    }

    async handleSaveProposal() {
        this.isProcessing = true;

        try {
            await updateProposal({
                proposalData: JSON.stringify(this.editProposal)
            });

            this.showNotification('Proposal updated successfully!', 'success');
            this.showEditModal = false;
            await this.loadMyProposals();
        } catch (error) {
            this.showNotification('Failed to update proposal: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    handleDeleteProposal(event) {
        const proposalId = event.currentTarget.dataset.id;
        const proposal = this.myProposals.find(p => p.Id === proposalId);

        if (proposal) {
            this.proposalToDelete = proposal;
            this.showDeleteModal = true;
        }
    }

    handleCloseDeleteModal() {
        this.showDeleteModal = false;
        this.proposalToDelete = null;
    }

    async handleConfirmDelete() {
        if (!this.proposalToDelete) return;

        this.isProcessing = true;

        try {
            await deleteProposal({ proposalId: this.proposalToDelete.Id });
            this.showNotification('Proposal deleted successfully!', 'success');
            this.showDeleteModal = false;
            this.proposalToDelete = null;
            await this.loadMyProposals();
        } catch (error) {
            this.showNotification('Failed to delete proposal: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    async handleSubmitForApproval(event) {
        const proposalId = event.currentTarget.dataset.id;
        this.isProcessing = true;

        try {
            await updateProposal({
                proposalData: JSON.stringify({
                    Id: proposalId,
                    Status__c: 'Pending Approval'
                })
            });

            this.showNotification('Proposal submitted for approval!', 'success');
            await this.loadMyProposals();
        } catch (error) {
            this.showNotification('Failed to submit proposal: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    handleManageDiscounts(event) {
        const proposalId = event.currentTarget.dataset.id;
        // Navigate to discount manager or show modal
        // For now, we'll dispatch an event
        this.dispatchEvent(new CustomEvent('managediscounts', {
            detail: { proposalId }
        }));
    }

    handleViewProposal(event) {
        const proposalId = event.currentTarget.dataset.id;
        const proposal = this.myProposals.find(p => p.Id === proposalId);

        if (proposal) {
            this.createdProposal = proposal;
            this.showSuccess = true;
            this.mainActiveTab = 'create'; // Switch to create tab to show details
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
            Base_Price__c: null,
            Product__c: null,
            Account__c: this.accountId
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
        this.createActiveTab = 'proposal';
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

    @api
    refresh() {
        if (this.mainActiveTab === 'manage') {
            return this.loadMyProposals();
        }
    }
}