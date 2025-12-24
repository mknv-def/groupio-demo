import { LightningElement, api, track } from 'lwc';
import createProposalApprovalCase from '@salesforce/apex/CaseController.createProposalApprovalCase';

export default class GroupBuyProposalDetail extends LightningElement {
    @api proposal;
    @track isSubmitting = false;
    
    // Use a setter/getter for activeTab to handle external changes
    _activeTab = 'details';
    
    @api
    get activeTab() {
        return this._activeTab;
    }
    set activeTab(value) {
        this._activeTab = value || 'details';
    }

    // ===============================
    // GETTERS
    // ===============================

    get proposalName() {
        return this.proposal?.Name || 'Proposal Details';
    }

    get productName() {
        return this.proposal?.Product__r?.Name || 'N/A';
    }

    get productCode() {
        return this.proposal?.Product__r?.ProductCode || '';
    }

    get accountName() {
        return this.proposal?.Account__r?.Name || 'N/A';
    }

    get basePriceFormatted() {
        if (this.proposal?.Base_Price__c != null) {
            return new Intl.NumberFormat('en-US', { 
                style: 'currency', 
                currency: 'USD' 
            }).format(this.proposal.Base_Price__c);
        }
        return 'N/A';
    }

    get startDateFormatted() {
        if (this.proposal?.Start_Date__c) {
            return new Date(this.proposal.Start_Date__c).toLocaleString();
        }
        return 'N/A';
    }

    get endDateFormatted() {
        if (this.proposal?.End_Date__c) {
            return new Date(this.proposal.End_Date__c).toLocaleString();
        }
        return 'N/A';
    }

    get deliveryDateFormatted() {
        return this.proposal?.Approximate_Deliver_Start_Date__c || 'N/A';
    }

    get progressPercentage() {
        const progress = (this.proposal?.Progress_Percentage__c || 0) * 100;
        return Math.round(progress);
    }

    get progressStyle() {
        return `width: ${Math.min(100, this.progressPercentage)}%`;
    }

    get isGoalReached() {
        return this.progressPercentage >= 100;
    }

    get bookedQuota() {
        return this.proposal?.Booked_Quota__c || 0;
    }

    get availableQuota() {
        return this.proposal?.Available_Quota__c || 0;
    }

    get statusClass() {
        const status = this.proposal?.Status__c;
        const classes = {
            'Created': 'status-created',
            'Pending Approval': 'status-pending',
            'Approved': 'status-approved',
            'Active': 'status-active',
            'Rejected': 'status-rejected',
            'Expired': 'status-expired',
            'Closed': 'status-closed'
        };
        return `status-badge ${classes[status] || ''}`;
    }

    get canEdit() {
        const status = this.proposal?.Status__c;
        return ['Created', 'Pending Approval', 'Rejected'].includes(status);
    }

    get canSubmitForApproval() {
        return this.proposal?.Status__c === 'Created';
    }

    get hasDescription() {
        return !!this.proposal?.Description__c;
    }

    // ===============================
    // HANDLERS
    // ===============================

    handleTabActive(event) {
        this._activeTab = event.target.value;
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleEdit() {
        this.dispatchEvent(new CustomEvent('edit'));
    }

    async handleSubmitForApproval() {
        if (!this.proposal?.Id) {
            return;
        }

        this.isSubmitting = true;

        try {
            const caseType = 'Merchandiser'; // Default to Merchandiser for seller portal
            
            const result = await createProposalApprovalCase({
                proposalId: this.proposal.Id,
                caseType: caseType
            });

            // Dispatch success event with case info
            this.dispatchEvent(new CustomEvent('submitforapproval', {
                detail: {
                    proposalId: this.proposal.Id,
                    caseId: result.Id,
                    caseNumber: result.CaseNumber,
                    message: `Submitted for approval. Case #${result.CaseNumber} created.`
                }
            }));

            // Close the modal
            this.handleClose();

        } catch (error) {
            console.error('Error submitting for approval:', error);
            this.dispatchEvent(new CustomEvent('error', {
                detail: {
                    message: error.body?.message || 'Failed to submit for approval'
                }
            }));
        } finally {
            this.isSubmitting = false;
        }
    }
}
