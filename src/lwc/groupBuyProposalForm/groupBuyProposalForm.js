import { LightningElement, api, track } from 'lwc';
import getProposalPicklistValues from '@salesforce/apex/GroupBuyProposalController.getProposalPicklistValues';
import createGroupBuyProposal from '@salesforce/apex/GroupBuyProposalController.createGroupBuyProposal';

export default class GroupBuyProposalForm extends LightningElement {
    @api accountId;

    @track isLoading = false;
    @track activeTab = 'details';

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
        Base_Price__c: null,
        Product__c: null
    };

    // Selected product from child component
    @track selectedProduct = null;

    // Picklist options
    @track statusOptions = [];
    @track typeOptions = [];

    // Validation
    @track validationErrors = [];

    connectedCallback() {
        this.loadPicklistValues();
    }

    async loadPicklistValues() {
        try {
            const picklists = await getProposalPicklistValues();
            if (picklists.Status__c) {
                this.statusOptions = picklists.Status__c.map(item => ({
                    label: item.label,
                    value: item.value
                }));
            }
            if (picklists.Type__c) {
                this.typeOptions = picklists.Type__c.map(item => ({
                    label: item.label,
                    value: item.value
                }));
            }
        } catch (error) {
            this.fireError('Failed to load picklist values');
        }
    }

    // ===============================
    // GETTERS
    // ===============================

    get productTabLabel() {
        return this.selectedProduct ? 'Product ✓' : 'Product *';
    }

    get hasValidationErrors() {
        return this.validationErrors.length > 0;
    }

    get isSubmitDisabled() {
        return !this.proposal.Name || !this.selectedProduct;
    }

    // ===============================
    // HANDLERS
    // ===============================

    handleFieldChange(event) {
        const field = event.target.dataset.field || event.target.name;
        this.proposal = {
            ...this.proposal,
            [field]: event.target.value
        };
        this.clearFieldError(field);
    }

    handleProductSelected(event) {
        this.selectedProduct = event.detail.product;
        this.proposal.Product__c = event.detail.product?.Id;
        this.clearFieldError('Product__c');
    }

    handleProductRemoved() {
        this.selectedProduct = null;
        this.proposal.Product__c = null;
    }

    clearFieldError(field) {
        this.validationErrors = this.validationErrors.filter(e => e.field !== field);
    }

    validateForm() {
        this.validationErrors = [];

        const requiredFields = [
            { field: 'Name', label: 'Proposal Name' },
            { field: 'Status__c', label: 'Status' },
            { field: 'Type__c', label: 'Type' },
            { field: 'Base_Price__c', label: 'Base Price' },
            { field: 'Min_Quota__c', label: 'Min Quota' },
            { field: 'Max_Quota__c', label: 'Max Quota' },
            { field: 'Start_Date__c', label: 'Start Date' },
            { field: 'End_Date__c', label: 'End Date' },
            { field: 'Approximate_Deliver_Start_Date__c', label: 'Delivery Date' }
        ];

        for (const { field, label } of requiredFields) {
            if (!this.proposal[field] && this.proposal[field] !== 0) {
                this.validationErrors.push({ field, message: `${label} is required` });
            }
        }

        if (!this.selectedProduct) {
            this.validationErrors.push({ field: 'Product__c', message: 'Product is required' });
        }

        // Business validations
        if (this.proposal.Min_Quota__c && this.proposal.Max_Quota__c) {
            if (Number(this.proposal.Min_Quota__c) > Number(this.proposal.Max_Quota__c)) {
                this.validationErrors.push({ field: 'Min_Quota__c', message: 'Min Quota cannot exceed Max Quota' });
            }
        }

        if (this.proposal.Start_Date__c && this.proposal.End_Date__c) {
            if (new Date(this.proposal.Start_Date__c) >= new Date(this.proposal.End_Date__c)) {
                this.validationErrors.push({ field: 'End_Date__c', message: 'End Date must be after Start Date' });
            }
        }

        return this.validationErrors.length === 0;
    }

    async handleSubmit() {
        if (!this.validateForm()) {
            return;
        }

        this.isLoading = true;

        try {
            const proposalData = {
                ...this.proposal,
                Product__c: this.selectedProduct.Id,
                Account__c: this.accountId
            };

            const result = await createGroupBuyProposal({
                proposalData: JSON.stringify(proposalData)
            });

            this.dispatchEvent(new CustomEvent('created', {
                detail: { proposal: result }
            }));

            this.resetForm();

        } catch (error) {
            this.fireError(this.reduceErrors(error));
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.resetForm();
    }

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
            Product__c: null
        };
        this.selectedProduct = null;
        this.validationErrors = [];
        this.activeTab = 'details';
    }

    fireError(message) {
        this.dispatchEvent(new CustomEvent('error', {
            detail: { message }
        }));
    }

    reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error.body?.message) return error.body.message;
        if (error.message) return error.message;
        return 'Unknown error';
    }
}
