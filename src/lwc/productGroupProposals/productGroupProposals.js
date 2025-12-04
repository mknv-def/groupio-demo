import { LightningElement, api, track } from 'lwc';

// Commerce Context API
import { getSessionContext } from 'commerce/contextApi';

// Apex methods
import getProposalsByProduct from '@salesforce/apex/GroupProposalController.getProposalsByProduct';
import getExistingOrdersForProduct from '@salesforce/apex/GroupProposalController.getExistingOrdersForProduct';
import createConditionalOrder from '@salesforce/apex/GroupProposalController.createConditionalOrder';
import updateConditionalOrder from '@salesforce/apex/GroupProposalController.updateConditionalOrder';
import cancelConditionalOrder from '@salesforce/apex/GroupProposalController.cancelConditionalOrder';

export default class ProductGroupProposals extends LightningElement {
    // Session context
    _accountId = null;
    _isPreview = false;
    _isLoggedIn = false;
    _contextLoaded = false;

    // Product data
    _productData;
    _dataLoaded = false;

    @api
    get productData() {
        return this._productData;
    }

    set productData(value) {
        this._productData = value;
        if (value && value.id) {
            this.tryLoadData();
        }
    }

    // Tracked state
    @track proposals = [];
    @track existingOrders = {};
    @track quantities = {};
    @track processingProposals = {};
    @track isLoading = true;
    @track error = null;

    // Notification state
    @track notification = null;
    notificationTimeout = null;

    // Modify Modal state
    @track showModifyModal = false;
    @track modifyProposalId = null;
    @track modifyQuantity = 1;
    @track modifyMaxQuantity = 1;
    @track isProcessing = false;

    // Cancel Confirmation Modal state
    @track showCancelModal = false;
    @track cancelProposalId = null;

    // ================================
    // LIFECYCLE
    // ================================

    async connectedCallback() {
        await this.loadSessionContext();
    }

    disconnectedCallback() {
        if (this.notificationTimeout) {
            clearTimeout(this.notificationTimeout);
        }
    }

    // ================================
    // SESSION CONTEXT
    // ================================

    async loadSessionContext() {
        try {
            const ctx = await getSessionContext();
            console.log('Session Context:', JSON.stringify(ctx));

            this._accountId = ctx.effectiveAccountId;
            this._isPreview = ctx.isPreview || false;
            this._isLoggedIn = ctx.isLoggedIn || false;
            this._contextLoaded = true;

            this.tryLoadData();
        } catch (err) {
            console.error('Error loading session context:', err);
            this._contextLoaded = true;
            this.tryLoadData();
        }
    }

    // ================================
    // NOTIFICATION
    // ================================

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

    // ================================
    // COMPUTED PROPERTIES
    // ================================

    get effectiveAccountId() {
        return this._accountId;
    }

    get effectiveProductId() {
        return this._productData?.id;
    }

    get canInteract() {
        return this._isLoggedIn;
    }

    get hasProposals() {
        return !this.isLoading && !this.error && this.proposals?.length > 0;
    }

    get noProposals() {
        return !this.isLoading && !this.error && (!this.proposals || this.proposals.length === 0);
    }

    get proposalsDisplay() {
        if (!this.proposals) return [];

        return this.proposals.map(p => {
            const proposal = p.proposal;
            const propId = proposal.Id;
            const existingOrder = this.existingOrders[propId];
            const quantity = this.quantities[propId] || 1;
            const isProcessing = this.processingProposals[propId] || false;

            const booked = proposal.Booked_Quota__c || 0;
            const minQuota = proposal.Min_Quota__c || 0;
            const maxQuota = proposal.Max_Quota__c || 0;
            const available = p.availableQuota || 0;
            const progress = p.progressPercentage || 0;

            const discountTiers = (p.discountTiers || []).map(tier => ({
                id: tier.Id,
                label: `${tier.Discount__c || 0}% (${tier.Min_Quota_For_Discount__c || 0}+)`,
                tierClass: 'tier-badge' + (tier.Id === p.currentTierId ? ' tier-current' : '')
            }));

            let canJoin = available > 0 && this.canInteract;
            let cannotJoinReason = '';
            if (!this._isLoggedIn) {
                cannotJoinReason = 'Please log in to join';
            } else if (available <= 0) {
                cannotJoinReason = 'No spots available';
            }

            return {
                id: propId,
                name: proposal.Name,
                endDateFormatted: this.formatDateTime(proposal.End_Date__c),
                paymentType: proposal.Type__c || 'Standard',
                bookedQuota: booked,
                minQuota: minQuota,
                maxQuota: maxQuota,
                availableQuota: available,
                progressStyle: `width: ${Math.min(100, progress)}%`,
                progressText: `${Math.round(progress)}% to goal`,
                progressClass: progress >= 100 ? 'progress-text goal-reached' : 'progress-text',
                currentDiscount: p.currentDiscount,
                currentDiscountFormatted: `${p.currentDiscount || 0}% OFF`,
                maxDiscount: p.maxDiscount,
                maxDiscountFormatted: `${p.maxDiscount || 0}% OFF`,
                hasDiscounts: discountTiers.length > 0,
                discountTiers: discountTiers,
                hasExistingOrder: !!existingOrder,
                existingOrderId: existingOrder?.Id,
                existingOrderQty: existingOrder?.Quantity__c || 0,
                canJoin: canJoin && !existingOrder,
                cannotJoinReason: cannotJoinReason,
                quantity: quantity,
                isProcessing: isProcessing
            };
        });
    }

    // ================================
    // DATA LOADING
    // ================================

    tryLoadData() {
        if (this._contextLoaded && this._productData?.id && !this._dataLoaded) {
            this.loadData();
        }
    }

    async loadData() {
        const prodId = this.effectiveProductId;
        if (!prodId) {
            this.isLoading = false;
            return;
        }

        this.isLoading = true;
        this.error = null;
        this._dataLoaded = true;

        try {
            this.proposals = await getProposalsByProduct({ productId: prodId });

            this.proposals.forEach(p => {
                if (!this.quantities[p.proposal.Id]) {
                    this.quantities[p.proposal.Id] = 1;
                }
            });

            if (this._isLoggedIn) {
                this.existingOrders = await getExistingOrdersForProduct({
                    productId: prodId,
                    accountId: this.effectiveAccountId
                });
            }
        } catch (err) {
            console.error('Error loading proposals:', err);
            this.error = this.reduceErrors(err);
        } finally {
            this.isLoading = false;
        }
    }

    async reloadData() {
        this._dataLoaded = false;
        this.existingOrders = {};
        await this.loadData();
    }

    // ================================
    // QUANTITY HANDLERS
    // ================================

    handleQtyChange(event) {
        const proposalId = event.target.dataset.proposalId;
        let val = parseInt(event.target.value, 10);
        const proposal = this.proposals.find(p => p.proposal.Id === proposalId);
        const maxQty = proposal?.availableQuota || 1;

        if (isNaN(val) || val < 1) val = 1;
        if (val > maxQty) val = maxQty;

        this.quantities = { ...this.quantities, [proposalId]: val };
    }

    handleIncreaseQty(event) {
        const proposalId = event.target.dataset.proposalId;
        const proposal = this.proposals.find(p => p.proposal.Id === proposalId);
        const maxQty = proposal?.availableQuota || 1;
        const currentQty = this.quantities[proposalId] || 1;

        if (currentQty < maxQty) {
            this.quantities = { ...this.quantities, [proposalId]: currentQty + 1 };
        }
    }

    handleDecreaseQty(event) {
        const proposalId = event.target.dataset.proposalId;
        const currentQty = this.quantities[proposalId] || 1;

        if (currentQty > 1) {
            this.quantities = { ...this.quantities, [proposalId]: currentQty - 1 };
        }
    }

    // ================================
    // CONNECT TO GROUP
    // ================================

    async handleConnectToGroup(event) {
        const proposalId = event.target.dataset.proposalId;
        const quantity = this.quantities[proposalId] || 1;

        if (!this.canInteract) {
            this.showNotification('Please log in to join', 'error');
            return;
        }

        this.processingProposals = { ...this.processingProposals, [proposalId]: true };

        try {
            const result = await createConditionalOrder({
                proposalId: proposalId,
                accountId: this.effectiveAccountId,
                quantity: quantity
            });

            if (result.success) {
                this.showNotification(result.message || 'Successfully joined the group!', 'success');
                this.dispatchEvent(new CustomEvent('orderplaced', {
                    detail: { proposalId, orderId: result.order?.Id, quantity }
                }));
                await this.reloadData();
            } else {
                this.showNotification(result.message || 'Failed to join', 'error');
            }
        } catch (err) {
            console.error('Error joining group:', err);
            this.showNotification(this.reduceErrors(err), 'error');
        } finally {
            this.processingProposals = { ...this.processingProposals, [proposalId]: false };
        }
    }

    // ================================
    // MODIFY ORDER
    // ================================

    handleModifyOrder(event) {
        const proposalId = event.target.dataset.proposalId;
        const existingOrder = this.existingOrders[proposalId];
        const proposal = this.proposals.find(p => p.proposal.Id === proposalId);

        if (!existingOrder || !proposal) return;

        this.modifyProposalId = proposalId;
        this.modifyQuantity = existingOrder.Quantity__c || 1;
        this.modifyMaxQuantity = (proposal.availableQuota || 0) + (existingOrder.Quantity__c || 0);
        this.showModifyModal = true;
    }

    handleCloseModifyModal() {
        this.showModifyModal = false;
        this.modifyProposalId = null;
    }

    handleModifyQtyChange(event) {
        let val = parseInt(event.target.value, 10);
        if (isNaN(val) || val < 1) val = 1;
        if (val > this.modifyMaxQuantity) val = this.modifyMaxQuantity;
        this.modifyQuantity = val;
    }

    async handleUpdateOrder() {
        if (!this.modifyProposalId) return;

        const existingOrder = this.existingOrders[this.modifyProposalId];
        if (!existingOrder) return;

        this.isProcessing = true;

        try {
            const result = await updateConditionalOrder({
                orderId: existingOrder.Id,
                newQuantity: this.modifyQuantity
            });

            if (result.success) {
                this.showNotification(result.message || 'Order updated successfully!', 'success');
                this.showModifyModal = false;
                await this.reloadData();
            } else {
                this.showNotification(result.message || 'Failed to update', 'error');
            }
        } catch (err) {
            console.error('Error updating order:', err);
            this.showNotification(this.reduceErrors(err), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ================================
    // CANCEL ORDER
    // ================================

    handleCancelOrder(event) {
        const proposalId = event.target.dataset.proposalId;
        this.cancelProposalId = proposalId;
        this.showCancelModal = true;
    }

    handleCloseCancelModal() {
        this.showCancelModal = false;
        this.cancelProposalId = null;
    }

    async handleConfirmCancel() {
        if (!this.cancelProposalId) return;

        const existingOrder = this.existingOrders[this.cancelProposalId];
        if (!existingOrder) return;

        this.isProcessing = true;

        try {
            const result = await cancelConditionalOrder({ orderId: existingOrder.Id });

            if (result.success) {
                this.showNotification(result.message || 'Order cancelled successfully!', 'success');
                this.dispatchEvent(new CustomEvent('ordercancelled', {
                    detail: { proposalId: this.cancelProposalId, orderId: existingOrder.Id }
                }));
                this.showCancelModal = false;
                this.cancelProposalId = null;
                await this.reloadData();
            } else {
                this.showNotification(result.message || 'Failed to cancel', 'error');
            }
        } catch (err) {
            console.error('Error cancelling order:', err);
            this.showNotification(this.reduceErrors(err), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ================================
    // UTILITIES
    // ================================

    formatDateTime(dateTimeStr) {
        if (!dateTimeStr) return '';
        return new Date(dateTimeStr).toLocaleDateString(undefined, {
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return 'An unexpected error occurred';
    }

    @api
    refresh() {
        return this.reloadData();
    }
}