import { LightningElement, api, track } from 'lwc';
import getMyProposals from '@salesforce/apex/GroupBuyProposalController.getMyProposals';
import updateProposal from '@salesforce/apex/GroupBuyProposalController.updateProposal';
import deleteProposal from '@salesforce/apex/GroupBuyProposalController.deleteProposal';

export default class GroupBuyProposalList extends LightningElement {
    @api accountId;
    
    _refreshKey = 0;
    @api 
    get refreshKey() {
        return this._refreshKey;
    }
    set refreshKey(value) {
        this._refreshKey = value;
        if (this._initialized) {
            this.loadProposals();
        }
    }

    @track proposals = [];
    @track isLoading = false;
    @track filterStatus = 'all';

    _initialized = false;

    statusFilterOptions = [
        { label: 'All Statuses', value: 'all' },
        { label: 'Created', value: 'Created' },
        { label: 'Pending Approval', value: 'Pending Approval' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Active', value: 'Active' },
        { label: 'Rejected', value: 'Rejected' },
        { label: 'Expired', value: 'Expired' },
        { label: 'Closed', value: 'Closed' }
    ];

    connectedCallback() {
        this._initialized = true;
        this.loadProposals();
    }

    async loadProposals() {
        this.isLoading = true;
        try {
            this.proposals = await getMyProposals({ accountId: this.accountId });
        } catch (error) {
            this.fireError('Failed to load proposals');
            this.proposals = [];
        } finally {
            this.isLoading = false;
        }
    }

    // ===============================
    // GETTERS
    // ===============================

    get hasProposals() {
        return this.filteredProposals.length > 0;
    }

    get noProposals() {
        return this.filteredProposals.length === 0;
    }

    get filteredProposals() {
        if (this.filterStatus === 'all') {
            return this.proposalsDisplay;
        }
        return this.proposalsDisplay.filter(p => p.Status__c === this.filterStatus);
    }

    get proposalsDisplay() {
        return this.proposals.map(p => {
            const progress = (p.Progress_Percentage__c || 0) * 100;
            const isGoalReached = progress >= 100;
            
            return {
                ...p,
                productName: p.Product__r?.Name || 'N/A',
                startDateFormatted: this.formatDate(p.Start_Date__c),
                endDateFormatted: this.formatDate(p.End_Date__c),
                deliveryDateFormatted: p.Approximate_Deliver_Start_Date__c || 'N/A',
                basePriceFormatted: this.formatCurrency(p.Base_Price__c),
                progressValue: Math.min(100, progress),
                progressStyle: `width: ${Math.min(100, progress)}%`,
                progressText: `${Math.round(progress)}%`,
                progressTextClass: isGoalReached ? 'progress-text goal-reached' : 'progress-text',
                isGoalReached,
                statusClass: this.getStatusClass(p.Status__c),
                canEdit: ['Created', 'Pending Approval', 'Rejected'].includes(p.Status__c),
                canDelete: ['Created', 'Rejected'].includes(p.Status__c),
                canSubmit: p.Status__c === 'Created',
                bookedQuota: p.Booked_Quota__c || 0,
                availableQuota: p.Available_Quota__c || p.Max_Quota__c
            };
        });
    }

    getStatusClass(status) {
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

    formatDate(dateStr) {
        if (!dateStr) return 'N/A';
        return new Date(dateStr).toLocaleDateString();
    }

    formatCurrency(value) {
        if (value == null) return 'N/A';
        return new Intl.NumberFormat('en-US', { 
            style: 'currency', 
            currency: 'USD' 
        }).format(value);
    }

    // ===============================
    // HANDLERS
    // ===============================

    handleFilterChange(event) {
        this.filterStatus = event.detail.value;
    }

    handleView(event) {
        const proposalId = event.currentTarget.dataset.id;
        const proposal = this.proposals.find(p => p.Id === proposalId);
        if (proposal) {
            this.dispatchEvent(new CustomEvent('view', {
                detail: { proposal }
            }));
        }
    }

    handleEdit(event) {
        const proposalId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('edit', {
            detail: { proposalId }
        }));
    }

    handleDelete(event) {
        const proposalId = event.currentTarget.dataset.id;
        const proposal = this.proposals.find(p => p.Id === proposalId);
        if (proposal) {
            this.dispatchEvent(new CustomEvent('delete', {
                detail: { proposal }
            }));
        }
    }

    handleManageDiscounts(event) {
        const proposalId = event.currentTarget.dataset.id;
        const proposal = this.proposals.find(p => p.Id === proposalId);
        if (proposal) {
            this.dispatchEvent(new CustomEvent('managediscounts', {
                detail: { proposal }
            }));
        }
    }

    async handleSubmitForApproval(event) {
        const proposalId = event.currentTarget.dataset.id;
        
        try {
            await updateProposal({
                proposalData: JSON.stringify({
                    Id: proposalId,
                    Status__c: 'Pending Approval'
                })
            });

            this.fireSuccess('Submitted for approval');
            await this.loadProposals();
        } catch (error) {
            this.fireError('Failed to submit for approval');
        }
    }

    fireError(message) {
        this.dispatchEvent(new CustomEvent('error', { detail: { message } }));
    }

    fireSuccess(message) {
        this.dispatchEvent(new CustomEvent('success', { detail: { message } }));
    }

    @api
    refresh() {
        return this.loadProposals();
    }
}
