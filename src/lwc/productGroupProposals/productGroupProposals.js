import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';

// Apex methods
import getProposalsByProduct from '@salesforce/apex/GroupProposalController.getProposalsByProduct';
import getExistingOrdersForProduct from '@salesforce/apex/GroupProposalController.getExistingOrdersForProduct';
import createConditionalOrder from '@salesforce/apex/GroupProposalController.createConditionalOrder';
import updateConditionalOrder from '@salesforce/apex/GroupProposalController.updateConditionalOrder';
import cancelConditionalOrder from '@salesforce/apex/GroupProposalController.cancelConditionalOrder';

export default class ProductGroupProposals extends LightningElement {
    // Public properties
    @api recordId; // Product ID from record page
    @api productId; // Product ID from property
    @api effectiveAccountId; // Account ID from parent or Experience Builder

    // Tracked state
    @track proposals = [];
    @track existingOrders = {};
    @track quantities = {}; // Map of proposalId to quantity
    @track processingProposals = {}; // Map of proposalId to processing state
    @track isLoading = true;
    @track error = null;

    // Modal state
    @track showModifyModal = false;
    @track modifyProposalId = null;
    @track modifyQuantity = 1;
    @track modifyMaxQuantity = 1;
    @track isProcessing = false;

    // ================================
    // LIFECYCLE
    // ================================

    connectedCallback() {
        this.loadData();
    }

    // ================================
    // WIRE
    // ================================

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        // Try to get productId from URL state
        if (pageRef && pageRef.state) {
            if (pageRef.state.productId) {
                this.productId = pageRef.state.productId;
                this.loadData();
            } else if (pageRef.state.recordId) {
                this.recordId = pageRef.state.recordId;
                this.loadData();
            }
        }
    }

    // ================================
    // DATA LOADING
    // ================================

    async loadData() {
        const prodId = this.recordId || this.productId;

        if (!prodId) {
            this.isLoading = false;
            return;
        }

        this.isLoading = true;
        this.error = null;

        try {
            // Load proposals for this product
            this.proposals = await getProposalsByProduct({ productId: prodId });

            // Initialize quantities
            this.proposals.forEach(p => {
                if (!this.quantities[p.proposal.Id]) {
                    this.quantities[p.proposal.Id] = 1;
                }
            });

            // Load existing orders if we have account context
            if (this.effectiveAccountId) {
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

    // ================================
    // GETTERS
    // ================================

    get hasProposals() {
        return !this.isLoading && !this.error && this.proposals && this.proposals.length > 0;
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

            // Progress calculation
            const booked = proposal.Booked_Quota__c || 0;
            const minQuota = proposal.Min_Quota__c || 0;
            const maxQuota = proposal.Max_Quota__c || 0;
            const available = p.availableQuota || 0;
            const progress = p.progressPercentage || 0;

            // Discount tiers display
            const discountTiers = (p.discountTiers || []).map(tier => {
                const isCurrent = tier.Id === p.currentTierId;
                return {
                    id: tier.Id,
                    label: (tier.Discount__c || 0) + '% (' + (tier.Min_Quota_For_Discount__c || 0) + '+)',
                    tierClass: 'tier-badge' + (isCurrent ? ' tier-current' : '')
                };
            });

            // Can join check
            let canJoin = available > 0 && this.effectiveAccountId;
            let cannotJoinReason = '';
            if (!this.effectiveAccountId) {
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
                progressStyle: 'width: ' + Math.min(100, progress) + '%',
                progressText: Math.round(progress) + '% to goal',
                progressClass: progress >= 100 ? 'progress-text goal-reached' : 'progress-text',
                currentDiscount: p.currentDiscount,
                currentDiscountFormatted: (p.currentDiscount || 0) + '% OFF',
                maxDiscount: p.maxDiscount,
                maxDiscountFormatted: (p.maxDiscount || 0) + '% OFF',
                hasDiscounts: discountTiers.length > 0,
                discountTiers: discountTiers,
                hasExistingOrder: existingOrder != null,
                existingOrderId: existingOrder ? existingOrder.Id : null,
                existingOrderQty: existingOrder ? existingOrder.Quantity__c : 0,
                canJoin: canJoin && !existingOrder,
                cannotJoinReason: cannotJoinReason,
                quantity: quantity,
                isProcessing: isProcessing
            };
        });
    }

    // ================================
    // EVENT HANDLERS - QUANTITY
    // ================================

    handleQtyChange(event) {
        const proposalId = event.target.dataset.proposalId;
        let val = parseInt(event.target.value, 10);

        const proposal = this.proposals.find(p => p.proposal.Id === proposalId);
        const maxQty = proposal ? proposal.availableQuota : 1;

        if (isNaN(val) || val < 1) val = 1;
        if (val > maxQty) val = maxQty;

        this.quantities = { ...this.quantities, [proposalId]: val };
    }

    handleIncreaseQty(event) {
        const proposalId = event.target.dataset.proposalId;
        const proposal = this.proposals.find(p => p.proposal.Id === proposalId);
        const maxQty = proposal ? proposal.availableQuota : 1;
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
    // EVENT HANDLERS - CONNECT TO GROUP
    // ================================

    async handleConnectToGroup(event) {
        const proposalId = event.target.dataset.proposalId;
        const quantity = this.quantities[proposalId] || 1;

        if (!this.effectiveAccountId) {
            this.showToast('Error', 'Please log in to join', 'error');
            return;
        }

        // Set processing state
        this.processingProposals = { ...this.processingProposals, [proposalId]: true };

        try {
            const result = await createConditionalOrder({
                proposalId: proposalId,
                accountId: this.effectiveAccountId,
                quantity: quantity
            });

            if (result.success) {
                this.showToast('Success', result.message, 'success');

                // Dispatch event
                this.dispatchEvent(new CustomEvent('orderplaced', {
                    detail: {
                        proposalId: proposalId,
                        orderId: result.order ? result.order.Id : null,
                        quantity: quantity
                    }
                }));

                // Reload data
                await this.loadData();
            } else {
                this.showToast('Error', result.message || 'Failed to join', 'error');
            }
        } catch (err) {
            console.error('Error joining group:', err);
            this.showToast('Error', this.reduceErrors(err), 'error');
        } finally {
            this.processingProposals = { ...this.processingProposals, [proposalId]: false };
        }
    }

    // ================================
    // EVENT HANDLERS - MODIFY ORDER
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
                this.showToast('Success', result.message, 'success');
                this.showModifyModal = false;
                await this.loadData();
            } else {
                this.showToast('Error', result.message || 'Failed to update', 'error');
            }
        } catch (err) {
            console.error('Error updating order:', err);
            this.showToast('Error', this.reduceErrors(err), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ================================
    // EVENT HANDLERS - CANCEL ORDER
    // ================================

    async handleCancelOrder(event) {
        const proposalId = event.target.dataset.proposalId;
        const existingOrder = this.existingOrders[proposalId];

        if (!existingOrder) return;

        if (!window.confirm('Are you sure you want to cancel your order?')) {
            return;
        }

        this.processingProposals = { ...this.processingProposals, [proposalId]: true };

        try {
            const result = await cancelConditionalOrder({
                orderId: existingOrder.Id
            });

            if (result.success) {
                this.showToast('Success', result.message, 'success');

                this.dispatchEvent(new CustomEvent('ordercancelled', {
                    detail: { proposalId: proposalId, orderId: existingOrder.Id }
                }));

                await this.loadData();
            } else {
                this.showToast('Error', result.message || 'Failed to cancel', 'error');
            }
        } catch (err) {
            console.error('Error cancelling order:', err);
            this.showToast('Error', this.reduceErrors(err), 'error');
        } finally {
            this.processingProposals = { ...this.processingProposals, [proposalId]: false };
        }
    }

    // ================================
    // UTILITIES
    // ================================

    formatDateTime(dateTimeStr) {
        if (!dateTimeStr) return null;
        const d = new Date(dateTimeStr);
        return d.toLocaleDateString(undefined, {
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }

    reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred';
    }

    // ================================
    // PUBLIC API
    // ================================

    @api
    refresh() {
        return this.loadData();
    }
}