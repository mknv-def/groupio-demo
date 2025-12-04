import { LightningElement, api, track } from 'lwc';

export default class GroupBuyProposalDetail extends LightningElement {
    @api proposal;

    @track activeTab = 'details';

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

    get hasDescription() {
        return !!this.proposal?.Description__c;
    }

    // ===============================
    // HANDLERS
    // ===============================

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleEdit() {
        this.dispatchEvent(new CustomEvent('edit'));
    }
}
