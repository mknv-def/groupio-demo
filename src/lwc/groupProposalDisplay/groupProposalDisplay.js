import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';

// Apex methods
import getProposalDetails from '@salesforce/apex/GroupProposalController.getProposalDetails';
import getExistingOrder from '@salesforce/apex/GroupProposalController.getExistingOrder';
import createConditionalOrder from '@salesforce/apex/GroupProposalController.createConditionalOrder';
import updateConditionalOrder from '@salesforce/apex/GroupProposalController.updateConditionalOrder';
import cancelConditionalOrder from '@salesforce/apex/GroupProposalController.cancelConditionalOrder';

export default class GroupProposalDisplay extends LightningElement {
    // Public properties - set from Experience Builder or parent component
    @api recordId;
    @api proposalId;
    @api effectiveAccountId;

    // Tracked properties for reactivity
    @track proposalDetails = null;
    @track existingOrder = null;
    @track orderQuantity = 1;
    @track modifyQuantity = 1;
    @track showModifyModal = false;
    @track isLoading = true;
    @track isProcessing = false;
    @track error = null;

    // ================================
    // LIFECYCLE HOOKS
    // ================================

    connectedCallback() {
        this.loadProposalData();
    }

    renderedCallback() {
        this.renderDescription();
    }

    // ================================
    // WIRE ADAPTERS
    // ================================

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        if (pageRef && pageRef.state && pageRef.state.proposalId) {
            this.recordId = pageRef.state.proposalId;
            this.loadProposalData();
        }
    }

    // ================================
    // HELPER METHODS
    // ================================

    renderDescription() {
        if (this.proposalDetails &&
            this.proposalDetails.proposal &&
            this.proposalDetails.proposal.Description__c) {
            const container = this.template.querySelector('.description-content');
            if (container) {
                container.innerHTML = this.proposalDetails.proposal.Description__c;
            }
        }
    }

    // ================================
    // DATA LOADING
    // ================================

    async loadProposalData() {
        const propId = this.recordId || this.proposalId;

        if (!propId) {
            this.isLoading = false;
            this.error = 'No proposal ID provided';
            return;
        }

        this.isLoading = true;
        this.error = null;

        try {
            // Load proposal details
            this.proposalDetails = await getProposalDetails({ proposalId: propId });

            // Load existing order if we have account context
            if (this.effectiveAccountId) {
                this.existingOrder = await getExistingOrder({
                    proposalId: propId,
                    accountId: this.effectiveAccountId
                });

                if (this.existingOrder && this.existingOrder.Quantity__c) {
                    this.modifyQuantity = this.existingOrder.Quantity__c;
                }
            }
        } catch (err) {
            console.error('Error loading proposal:', err);
            this.error = this.reduceErrors(err);
        } finally {
            this.isLoading = false;
        }
    }

    // ================================
    // GETTERS - PROPOSAL INFO
    // ================================

    get hasProposal() {
        return !this.isLoading && !this.error && this.proposalDetails && this.proposalDetails.proposal;
    }

    get proposal() {
        return this.proposalDetails ? this.proposalDetails.proposal : null;
    }

    get proposalName() {
        return this.proposal ? this.proposal.Name : '';
    }

    get proposalDescription() {
        return this.proposal ? this.proposal.Description__c : null;
    }

    get proposalStatus() {
        return this.proposal ? this.proposal.Status__c : '';
    }

    get statusBadgeClass() {
        const status = (this.proposalStatus || '').toLowerCase();
        if (status === 'active') return 'badge badge-active';
        if (status === 'closed' || status === 'expired') return 'badge badge-closed';
        if (status === 'pending approval') return 'badge badge-pending';
        return 'badge badge-default';
    }

    get productName() {
        if (this.proposal && this.proposal.Product__r) {
            return this.proposal.Product__r.Name;
        }
        return 'Product';
    }

    get productImageUrl() {
        return this.proposalDetails ? this.proposalDetails.productImageUrl : null;
    }

    get paymentType() {
        return this.proposal ? (this.proposal.Type__c || 'Not specified') : 'Not specified';
    }

    // ================================
    // GETTERS - DATES
    // ================================

    get endDateFormatted() {
        if (!this.proposal || !this.proposal.End_Date__c) return null;
        return this.formatDateTime(this.proposal.End_Date__c);
    }

    get deliveryDateFormatted() {
        if (!this.proposal || !this.proposal.Approximate_Deliver_Start_Date__c) return null;
        return this.formatDate(this.proposal.Approximate_Deliver_Start_Date__c);
    }

    // ================================
    // GETTERS - QUOTA & PROGRESS
    // ================================

    get minQuota() {
        return this.proposal ? (this.proposal.Min_Quota__c || 0) : 0;
    }

    get maxQuota() {
        return this.proposal ? (this.proposal.Max_Quota__c || 0) : 0;
    }

    get hasMaxQuota() {
        return this.maxQuota > 0;
    }

    get bookedQuota() {
        return this.proposal ? (this.proposal.Booked_Quota__c || 0) : 0;
    }

    get availableQuota() {
        return this.proposalDetails ? (this.proposalDetails.availableQuota || 0) : 0;
    }

    get progressPercentage() {
        return this.proposalDetails ? (this.proposalDetails.progressPercentage || 0) : 0;
    }

    get progressPercentageFormatted() {
        return Math.round(this.progressPercentage);
    }

    get progressBarStyle() {
        const pct = Math.min(100, this.progressPercentage);
        return 'width: ' + pct + '%';
    }

    get isMinQuotaReached() {
        return this.proposalDetails ? this.proposalDetails.isMinQuotaReached : false;
    }

    get hasAvailableQuota() {
        return this.proposalDetails ? this.proposalDetails.hasAvailableQuota : false;
    }

    get isExpired() {
        return this.proposalDetails ? this.proposalDetails.isExpired : false;
    }

    get canOrder() {
        return this.proposalDetails && this.proposalDetails.canOrder && this.effectiveAccountId;
    }

    get unavailableReason() {
        if (!this.effectiveAccountId) {
            return 'Please log in to join this group buy';
        }
        if (this.isExpired) {
            return 'This group buy has expired';
        }
        if (this.proposalDetails && !this.proposalDetails.isActive) {
            return 'This group buy is not currently active';
        }
        if (!this.hasAvailableQuota) {
            return 'This group buy has reached its maximum capacity';
        }
        return 'Unable to join this group buy at this time';
    }

    // ================================
    // GETTERS - DISCOUNT TIERS
    // ================================

    get hasDiscountTiers() {
        return this.proposalDetails &&
            this.proposalDetails.discountTiers &&
            this.proposalDetails.discountTiers.length > 0;
    }

    get discountTiersDisplay() {
        if (!this.hasDiscountTiers) return [];

        const tiers = this.proposalDetails.discountTiers;
        const currentTierId = this.proposalDetails.currentTierId;

        return tiers.map(tier => {
            const minQty = tier.Min_Quota_For_Discount__c || 0;
            const maxQty = tier.Max_Quota_Discount__c || '∞';
            const isCurrent = tier.Id === currentTierId;
            const discount = tier.Discount__c || 0;

            return {
                id: tier.Id,
                discountFormatted: discount + '% OFF',
                minQty: minQty,
                maxQty: maxQty,
                isCurrent: isCurrent,
                tierClass: 'discount-tier' + (isCurrent ? ' tier-current' : '')
            };
        });
    }

    get currentDiscount() {
        return this.proposalDetails ? this.proposalDetails.currentDiscount : null;
    }

    get currentDiscountFormatted() {
        if (!this.currentDiscount) return null;
        return this.currentDiscount + '% OFF';
    }

    // ================================
    // GETTERS - EXISTING ORDER
    // ================================

    get hasExistingOrder() {
        return this.existingOrder !== null && this.existingOrder !== undefined;
    }

    get existingOrderName() {
        return this.existingOrder ? this.existingOrder.Name : '';
    }

    get existingOrderQuantity() {
        return this.existingOrder ? (this.existingOrder.Quantity__c || 0) : 0;
    }

    get availableQuotaForModify() {
        return this.availableQuota + this.existingOrderQuantity;
    }

    // ================================
    // GETTERS - QUANTITY INPUT
    // ================================

    get isMinQuantity() {
        return this.orderQuantity <= 1;
    }

    get isMaxQuantity() {
        return this.orderQuantity >= this.availableQuota;
    }

    // ================================
    // EVENT HANDLERS - QUANTITY
    // ================================

    handleQuantityChange(event) {
        let val = parseInt(event.target.value, 10);
        if (isNaN(val) || val < 1) val = 1;
        if (val > this.availableQuota) val = this.availableQuota;
        this.orderQuantity = val;
    }

    handleIncreaseQuantity() {
        if (this.orderQuantity < this.availableQuota) {
            this.orderQuantity = this.orderQuantity + 1;
        }
    }

    handleDecreaseQuantity() {
        if (this.orderQuantity > 1) {
            this.orderQuantity = this.orderQuantity - 1;
        }
    }

    // ================================
    // EVENT HANDLERS - CONNECT TO GROUP
    // ================================

    async handleConnectToGroup() {
        if (!this.effectiveAccountId) {
            this.showToast('Error', 'Please log in to join this group buy', 'error');
            return;
        }

        if (this.orderQuantity < 1 || this.orderQuantity > this.availableQuota) {
            this.showToast('Error', 'Please enter a valid quantity', 'error');
            return;
        }

        this.isProcessing = true;

        try {
            const result = await createConditionalOrder({
                proposalId: this.recordId || this.proposalId,
                accountId: this.effectiveAccountId,
                quantity: this.orderQuantity
            });

            if (result.success) {
                this.showToast('Success', result.message, 'success');

                // Fire event for parent components
                this.dispatchEvent(new CustomEvent('orderplaced', {
                    detail: {
                        orderId: result.order ? result.order.Id : null,
                        orderName: result.order ? result.order.Name : null,
                        quantity: this.orderQuantity
                    }
                }));

                // Reload data
                await this.loadProposalData();
            } else {
                this.showToast('Error', result.message || 'Failed to join group buy', 'error');
            }
        } catch (err) {
            console.error('Error creating order:', err);
            this.showToast('Error', this.reduceErrors(err), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ================================
    // EVENT HANDLERS - MODIFY ORDER
    // ================================

    handleModifyOrder() {
        this.modifyQuantity = this.existingOrderQuantity;
        this.showModifyModal = true;
    }

    handleCloseModifyModal() {
        this.showModifyModal = false;
    }

    handleModifyQuantityChange(event) {
        let val = parseInt(event.target.value, 10);
        if (isNaN(val) || val < 1) val = 1;
        if (val > this.availableQuotaForModify) val = this.availableQuotaForModify;
        this.modifyQuantity = val;
    }

    async handleUpdateOrder() {
        if (this.modifyQuantity < 1) {
            this.showToast('Error', 'Please enter a valid quantity', 'error');
            return;
        }

        this.isProcessing = true;

        try {
            const result = await updateConditionalOrder({
                orderId: this.existingOrder.Id,
                newQuantity: this.modifyQuantity
            });

            if (result.success) {
                this.showToast('Success', result.message, 'success');
                this.showModifyModal = false;
                await this.loadProposalData();
            } else {
                this.showToast('Error', result.message || 'Failed to update order', 'error');
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

    async handleCancelOrder() {
        if (!window.confirm('Are you sure you want to cancel your order?')) {
            return;
        }

        this.isProcessing = true;

        try {
            const result = await cancelConditionalOrder({
                orderId: this.existingOrder.Id
            });

            if (result.success) {
                this.showToast('Success', result.message, 'success');

                this.dispatchEvent(new CustomEvent('ordercancelled', {
                    detail: { orderId: this.existingOrder.Id }
                }));

                await this.loadProposalData();
            } else {
                this.showToast('Error', result.message || 'Failed to cancel order', 'error');
            }
        } catch (err) {
            console.error('Error cancelling order:', err);
            this.showToast('Error', this.reduceErrors(err), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ================================
    // UTILITY METHODS
    // ================================

    formatDate(dateStr) {
        if (!dateStr) return '';
        const d = new Date(dateStr);
        return d.toLocaleDateString(undefined, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }

    formatDateTime(dateTimeStr) {
        if (!dateTimeStr) return '';
        const d = new Date(dateTimeStr);
        return d.toLocaleDateString(undefined, {
            year: 'numeric',
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
        if (error && error.body && Array.isArray(error.body)) {
            return error.body.map(function(e) { return e.message; }).join(', ');
        }
        return 'An unexpected error occurred';
    }

    // ================================
    // PUBLIC API
    // ================================

    @api
    refresh() {
        return this.loadProposalData();
    }
}