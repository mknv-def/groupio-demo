import { LightningElement, api, track } from 'lwc';
import getProposalById from '@salesforce/apex/GroupBuyProposalController.getProposalById';
import getProposalPicklistValues from '@salesforce/apex/GroupBuyProposalController.getProposalPicklistValues';
import updateProposal from '@salesforce/apex/GroupBuyProposalController.updateProposal';

export default class GroupBuyProposalEditModal extends LightningElement {
    @api proposalId;

    @track isLoading = true;
    @track isSaving = false;
    @track proposal = {};

    // Picklists
    @track statusOptions = [];
    @track typeOptions = [];

    async connectedCallback() {
        await Promise.all([
            this.loadPicklistValues(),
            this.loadProposal()
        ]);
        this.isLoading = false;
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
            console.error('Error loading picklists:', error);
        }
    }

    async loadProposal() {
        try {
            const result = await getProposalById({ proposalId: this.proposalId });
            this.proposal = { ...result };
        } catch (error) {
            this.fireError('Failed to load proposal');
        }
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
    }

    async handleSave() {
        this.isSaving = true;

        try {
            await updateProposal({
                proposalData: JSON.stringify(this.proposal)
            });

            this.dispatchEvent(new CustomEvent('save'));
        } catch (error) {
            this.fireError(this.reduceErrors(error));
        } finally {
            this.isSaving = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
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
