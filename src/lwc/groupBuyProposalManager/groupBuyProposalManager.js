import { LightningElement, track, api } from 'lwc';
import { getSessionContext } from 'commerce/contextApi';
import getAccountById from '@salesforce/apex/GroupBuyProposalController.getAccountById';

export default class GroupBuyProposalManager extends LightningElement {
    @api title;

    // Session context
    @track userId = null;
    @track accountId = null;
    @track accountName = '';
    @track accountNumber = '';
    @track isPreview = false;
    @track contextLoaded = false;

    // UI state
    @track mainActiveTab = 'create';
    
    // Notification
    @track notification = null;
    notificationTimeout = null;

    // View Modal
    @track showViewModal = false;
    @track viewProposal = null;

    // Edit Modal
    @track showEditModal = false;
    @track editProposalId = null;

    // Delete Modal
    @track showDeleteModal = false;
    @track deleteProposal = null;

    // Refresh trigger
    @track refreshKey = 0;

    async connectedCallback() {
        await this.loadSessionContext();
    }

    disconnectedCallback() {
        if (this.notificationTimeout) {
            clearTimeout(this.notificationTimeout);
        }
    }

    async loadSessionContext() {
        try {
            const sessionContext = await getSessionContext();
            this.userId = sessionContext.userId;
            this.accountId = sessionContext.effectiveAccountId;
            this.isPreview = sessionContext.isPreview || false;

            if (this.accountId) {
                await this.loadAccountDetails();
            }
            this.contextLoaded = true;
        } catch (error) {
            console.error('Error fetching session context:', error);
            this.contextLoaded = true;
        }
    }

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
    // GETTERS
    // ===============================

    get hasAccountId() {
        return this.accountId != null;
    }

    get accountDisplayName() {
        if (this.accountName && this.accountNumber) {
            return `${this.accountName} (${this.accountNumber})`;
        }
        return this.accountName || 'Loading...';
    }

    // ===============================
    // TAB HANDLERS
    // ===============================

    handleMainTabActive(event) {
        this.mainActiveTab = event.target.value;
    }

    // ===============================
    // EVENT HANDLERS FROM CHILD COMPONENTS
    // ===============================

    handleProposalCreated(event) {
        const { proposal } = event.detail;
        this.showNotification('Proposal created successfully!', 'success');
        this.viewProposal = proposal;
        this.showViewModal = true;
        this.refreshKey++;
    }

    handleViewProposal(event) {
        this.viewProposal = event.detail.proposal;
        this.showViewModal = true;
    }

    handleCloseViewModal() {
        this.showViewModal = false;
        this.viewProposal = null;
    }

    handleEditFromView() {
        this.editProposalId = this.viewProposal.Id;
        this.showViewModal = false;
        this.showEditModal = true;
    }

    handleEditProposal(event) {
        this.editProposalId = event.detail.proposalId;
        this.showEditModal = true;
    }

    handleCloseEditModal() {
        this.showEditModal = false;
        this.editProposalId = null;
    }

    handleProposalUpdated(event) {
        this.showNotification('Proposal updated successfully!', 'success');
        this.showEditModal = false;
        this.editProposalId = null;
        this.refreshKey++;
    }

    handleDeleteProposal(event) {
        this.deleteProposal = event.detail.proposal;
        this.showDeleteModal = true;
    }

    handleCloseDeleteModal() {
        this.showDeleteModal = false;
        this.deleteProposal = null;
    }

    handleProposalDeleted() {
        this.showNotification('Proposal deleted successfully!', 'success');
        this.showDeleteModal = false;
        this.deleteProposal = null;
        this.refreshKey++;
    }

    handleManageDiscounts(event) {
        const { proposalId } = event.detail;
        // Find proposal and show view modal with discounts tab active
        this.dispatchEvent(new CustomEvent('managediscounts', {
            detail: { proposalId }
        }));
    }

    handleError(event) {
        this.showNotification(event.detail.message, 'error');
    }

    handleSuccess(event) {
        this.showNotification(event.detail.message, 'success');
    }
}
