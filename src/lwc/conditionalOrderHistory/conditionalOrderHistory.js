import { LightningElement, api, track } from 'lwc';
import { getSessionContext } from 'commerce/contextApi';
import getOrdersGroupedByProposal from '@salesforce/apex/ConditionalOrderController.getOrdersGroupedByProposal';
import updateOrderQuantity from '@salesforce/apex/ConditionalOrderController.updateOrderQuantity';
import cancelOrder from '@salesforce/apex/ConditionalOrderController.cancelOrder';

export default class ConditionalOrderHistory extends LightningElement {
    @api recordId;

    @track orderGroups = [];
    @track isLoading = true;
    @track errorMsg = '';

    // Edit Modal
    @track showEditModal = false;
    @track editingOrder = null;
    @track editQuantity = 0;
    @track isSaving = false;

    // Cancel Modal
    @track showCancelModal = false;
    @track cancellingOrder = null;
    @track isCancelling = false;

    // Notification
    @track notification = null;
    notificationTimeout;

    accountId = null;

    async connectedCallback() {
        await this.loadContext();
        await this.loadOrders();
    }

    disconnectedCallback() {
        if (this.notificationTimeout) {
            clearTimeout(this.notificationTimeout);
        }
    }

    async loadContext() {
        try {
            const context = await getSessionContext();
            this.accountId = context?.accountId || null;
        } catch (error) {
            console.warn('Context API not available, using preview mode');
            this.accountId = null;
        }
    }

    async loadOrders() {
        this.isLoading = true;
        this.errorMsg = '';

        try {
            const result = await getOrdersGroupedByProposal({ accountId: this.accountId });
            this.orderGroups = this.processOrderGroups(result);
        } catch (error) {
            console.error('Error loading orders:', error);
            this.errorMsg = 'Failed to load your orders. Please try again.';
            this.orderGroups = [];
        } finally {
            this.isLoading = false;
        }
    }

    processOrderGroups(groups) {
        return groups.map((group, index) => {
            const proposal = group.proposal;
            const orders = group.orders || [];
            const discounts = group.discounts || [];

            // Calculate current discount based on booked quota
            const bookedQuota = proposal.Booked_Quota__c || 0;
            const currentDiscount = this.findCurrentDiscount(discounts, bookedQuota);

            // --- FIX 1: Normalize Discount Values ---
            const currentDiscountVal = currentDiscount ? this.normalizePercentage(currentDiscount.Discount__c) : 0;

            // Process discounts
            const processedDiscounts = discounts.map(d => {
                const rawDiscount = d.Discount__c || 0;
                // Determine if we display as-is or need formatting
                // If raw > 1 (e.g. 10), it's 10%. If raw <= 1 (e.g. 0.1), it's 10%.
                const displayPercent = rawDiscount > 1 ? rawDiscount : (rawDiscount * 100);

                return {
                    ...d,
                    discountPercent: displayPercent.toFixed(1),
                    rangeText: `${d.Min_Quota_For_Discount__c} - ${d.Max_Quota_Discount__c}`,
                    isCurrent: currentDiscount && d.Id === currentDiscount.Id,
                    cssClass: currentDiscount && d.Id === currentDiscount.Id ? 'discount-tier current' : 'discount-tier'
                };
            });

            // --- FIX 2: Normalize Progress Percentage ---
            // If progress > 100, assume it's already a percent (e.g. 250). Don't mulitply by 100.
            let rawProgress = proposal.Progress_Percentage__c || 0;
            let displayProgress = rawProgress;

            // Heuristic: If value is small (e.g. 2.5), it's a decimal ratio -> multiply by 100 (250%).
            // If value is large (e.g. 250), it's already a percent -> keep as 250.
            // Exception: 0.5 (50%) vs 1 (100%).
            // We assume standard Salesforce Percent fields (decimals) unless value > 10.
            if (rawProgress <= 10) {
                displayProgress = rawProgress * 100;
            }

            const processedOrders = orders.map(order => ({
                ...order,
                isConfirmed: order.Status__c === 'Confirmed',
                isCancelled: order.Status__c === 'Cancelled',
                canEdit: order.Status__c !== 'Confirmed' && order.Status__c !== 'Cancelled',
                canCancel: order.Status__c !== 'Confirmed' && order.Status__c !== 'Cancelled',
                statusClass: this.getStatusClass(order.Status__c),
                formattedDate: this.formatDate(order.CreatedDate),
                unitPrice: this.formatCurrency(proposal.Base_Price__c),
                totalPrice: this.formatCurrency((proposal.Base_Price__c || 0) * (order.Quantity__c || 0)),
                // Use normalized discount (decimal format) for math
                discountedUnitPrice: currentDiscount
                    ? this.formatCurrency((proposal.Base_Price__c || 0) * (1 - currentDiscountVal))
                    : null,
                discountedTotalPrice: currentDiscount
                    ? this.formatCurrency((proposal.Base_Price__c || 0) * (1 - currentDiscountVal) * (order.Quantity__c || 0))
                    : null
            }));

            const totalQuantity = orders.reduce((sum, o) => sum + (o.Quantity__c || 0), 0);

            return {
                key: proposal.Id,
                index,
                isExpanded: true,
                iconName: 'utility:chevrondown',
                proposal: {
                    ...proposal,
                    productName: proposal.Product__r?.Name || 'N/A',
                    productCode: proposal.Product__r?.ProductCode || '',
                    basePriceFormatted: this.formatCurrency(proposal.Base_Price__c),
                    progressPercent: Math.round(displayProgress),
                    progressStyle: `width: ${Math.min(100, displayProgress)}%`,
                    bookedQuota: bookedQuota,
                    statusClass: this.getProposalStatusClass(proposal.Status__c),
                    startDateFormatted: this.formatDate(proposal.Start_Date__c),
                    endDateFormatted: this.formatDate(proposal.End_Date__c)
                },
                orders: processedOrders,
                discounts: processedDiscounts,
                hasDiscounts: discounts.length > 0,
                currentDiscount: currentDiscount ? {
                    percent: (currentDiscountVal * 100).toFixed(1),
                    range: `${currentDiscount.Min_Quota_For_Discount__c} - ${currentDiscount.Max_Quota_Discount__c}`
                } : null,
                totalQuantity,
                orderCount: orders.length
            };
        });
    }

    /**
     * Helper to turn any value (10 or 0.1) into a standard decimal (0.1)
     */
    normalizePercentage(value) {
        if (!value) return 0;
        // If value is greater than 1, assume it is a whole number percent (e.g., 10 = 10%)
        // Exception: if discount is 100% (free), value 1 is ambiguous (1% or 100%).
        // Contextually for discounts, 5, 10, 15 are common. 0.05, 0.1 are common.
        if (value > 1) {
            return value / 100;
        }
        return value;
    }

    findCurrentDiscount(discounts, bookedQuota) {
        if (!discounts || discounts.length === 0) return null;

        const sorted = [...discounts].sort((a, b) =>
            (b.Min_Quota_For_Discount__c || 0) - (a.Min_Quota_For_Discount__c || 0)
        );

        for (const discount of sorted) {
            if (bookedQuota >= (discount.Min_Quota_For_Discount__c || 0)) {
                return discount;
            }
        }
        return null;
    }

    get hasOrders() {
        return this.orderGroups.length > 0;
    }

    get noOrders() {
        return this.orderGroups.length === 0 && !this.isLoading;
    }

    get hasNotification() {
        return !!this.notification;
    }

    get notificationClass() {
        if (!this.notification) return '';
        return `notification notification-${this.notification.type}`;
    }

    get notificationIcon() {
        const icons = {
            success: 'utility:success',
            error: 'utility:error',
            warning: 'utility:warning',
            info: 'utility:info'
        };
        return icons[this.notification?.type] || 'utility:info';
    }

    formatCurrency(value) {
        if (value == null) return 'N/A';
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(value);
    }

    formatDate(dateStr) {
        if (!dateStr) return 'N/A';
        return new Date(dateStr).toLocaleDateString();
    }

    getStatusClass(status) {
        const classes = {
            'Pending': 'status-badge status-pending',
            'Confirmed': 'status-badge status-confirmed',
            'Cancelled': 'status-badge status-cancelled'
        };
        return classes[status] || 'status-badge';
    }

    getProposalStatusClass(status) {
        const classes = {
            'Created': 'proposal-status status-created',
            'Pending Approval': 'proposal-status status-pending',
            'Approved': 'proposal-status status-approved',
            'Active': 'proposal-status status-active',
            'Rejected': 'proposal-status status-rejected',
            'Expired': 'proposal-status status-expired',
            'Closed': 'proposal-status status-closed'
        };
        return classes[status] || 'proposal-status';
    }

    handleToggleGroup(event) {
        const proposalId = event.currentTarget.dataset.id;
        this.orderGroups = this.orderGroups.map(group => {
            if (group.key === proposalId) {
                const isExpanded = !group.isExpanded;
                return {
                    ...group,
                    isExpanded: isExpanded,
                    iconName: isExpanded ? 'utility:chevrondown' : 'utility:chevronright'
                };
            }
            return group;
        });
    }

    handleRefresh() {
        this.loadOrders();
    }

    handleEditOrder(event) {
        const orderId = event.currentTarget.dataset.id;
        const order = this.findOrderById(orderId);
        if (order) {
            this.editingOrder = order;
            this.editQuantity = order.Quantity__c;
            this.showEditModal = true;
        }
    }

    handleQuantityChange(event) {
        this.editQuantity = parseInt(event.target.value, 10) || 0;
    }

    handleCloseEditModal() {
        this.showEditModal = false;
        this.editingOrder = null;
        this.editQuantity = 0;
    }

    async handleSaveQuantity() {
        if (this.editQuantity < 1) {
            this.showNotification('Quantity must be at least 1', 'error');
            return;
        }

        this.isSaving = true;
        try {
            await updateOrderQuantity({
                orderId: this.editingOrder.Id,
                newQuantity: this.editQuantity
            });

            this.showNotification('Order updated successfully!', 'success');
            this.handleCloseEditModal();
            await this.loadOrders();
        } catch (error) {
            console.error('Error updating order:', error);
            this.showNotification(error.body?.message || 'Failed to update order', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleCancelOrder(event) {
        const orderId = event.currentTarget.dataset.id;
        const order = this.findOrderById(orderId);
        if (order) {
            this.cancellingOrder = order;
            this.showCancelModal = true;
        }
    }

    handleCloseCancelModal() {
        this.showCancelModal = false;
        this.cancellingOrder = null;
    }

    async handleConfirmCancel() {
        this.isCancelling = true;
        try {
            await cancelOrder({ orderId: this.cancellingOrder.Id });

            this.showNotification('Order cancelled successfully!', 'success');
            this.handleCloseCancelModal();
            await this.loadOrders();
        } catch (error) {
            console.error('Error cancelling order:', error);
            this.showNotification(error.body?.message || 'Failed to cancel order', 'error');
        } finally {
            this.isCancelling = false;
        }
    }

    showNotification(message, type = 'info') {
        this.notification = { message, type };

        if (this.notificationTimeout) {
            clearTimeout(this.notificationTimeout);
        }

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

    findOrderById(orderId) {
        for (const group of this.orderGroups) {
            const order = group.orders.find(o => o.Id === orderId);
            if (order) return order;
        }
        return null;
    }
}