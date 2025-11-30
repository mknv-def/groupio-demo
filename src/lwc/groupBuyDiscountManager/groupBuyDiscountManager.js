import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDiscounts from '@salesforce/apex/GroupBuyDiscountController.getDiscounts';
import saveDiscounts from '@salesforce/apex/GroupBuyDiscountController.saveDiscounts';

export default class GroupBuyDiscountManager extends LightningElement {
    @api recordId; // Group_Buy_Proposal__c ID

    @track rows = [];
    @track isLoading = false;
    @track errorMsg = '';

    deletedRecordIds = [];
    wiredDiscountResult;

    @wire(getDiscounts, { proposalId: '$recordId' })
    wiredDiscounts(result) {
        this.wiredDiscountResult = result;
        if (result.data) {
            // Transform data for UI usage (add a temporary key for tracking)
            this.rows = result.data.map(item => ({
                ...item,
                key: item.Id
            }));
            this.errorMsg = '';
        } else if (result.error) {
            this.showToast('Error', 'Error loading discounts', 'error');
        }
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get isSaveDisabled() {
        return this.isLoading || this.rows.length === 0;
    }

    handleAddRow() {
        const newRow = {
            key: Date.now(), // Temporary ID for UI rendering
            Id: null,
            Group_Buy_Proposal__c: this.recordId,
            Min_Quota_For_Discount__c: null,
            Max_Quota_Discount__c: null,
            Discount__c: null
        };
        this.rows = [...this.rows, newRow];
    }

    handleDeleteRow(event) {
        const index = event.currentTarget.dataset.index;
        const rowToDelete = this.rows[index];

        // If it's an existing record in SF, mark for deletion
        if (rowToDelete.Id) {
            this.deletedRecordIds.push(rowToDelete.Id);
        }

        // Remove from UI array
        this.rows = this.rows.filter((_, i) => i !== parseInt(index));
    }

    handleInputChange(event) {
        const { index, field } = event.target.dataset;
        const value = event.target.value;

        let row = this.rows[index];
        row[field] = value;

        this.rows = [...this.rows]; // Trigger reactivity
        this.errorMsg = ''; // Clear errors on edit
    }

    validateData() {
        // 1. Basic Field Validation (Required fields)
        const allValid = [...this.template.querySelectorAll('lightning-input')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);

        if (!allValid) {
            this.errorMsg = 'Please complete all required fields.';
            return false;
        }

        // 2. Logic Validation (Min < Max)
        for (let row of this.rows) {
            let min = Number(row.Min_Quota_For_Discount__c);
            let max = Number(row.Max_Quota_Discount__c);

            if (min > max) {
                this.errorMsg = `Min Quota (${min}) cannot be greater than Max Quota (${max}).`;
                return false;
            }
        }

        // 3. Overlap Validation
        // Sort rows by Min Quota to make checking easier
        // We create a copy to not mess up UI order if user prefers insertion order
        let sortedRows = [...this.rows].sort((a, b) => {
            return Number(a.Min_Quota_For_Discount__c) - Number(b.Min_Quota_For_Discount__c);
        });

        for (let i = 0; i < sortedRows.length - 1; i++) {
            let current = sortedRows[i];
            let next = sortedRows[i+1];

            // Check if Current Max overlaps Next Min
            // Example: Row 1 (1-10), Row 2 (5-15). 10 >= 5 (Overlap)
            // Example: Row 1 (1-10), Row 2 (11-20). 10 < 11 (No overlap)

            let currentMax = Number(current.Max_Quota_Discount__c);
            let nextMin = Number(next.Min_Quota_For_Discount__c);

            if (currentMax >= nextMin) {
                this.errorMsg = `Quota Range Overlap detected between ranges: [${current.Min_Quota_For_Discount__c}-${current.Max_Quota_Discount__c}] and [${next.Min_Quota_For_Discount__c}-${next.Max_Quota_Discount__c}]`;
                return false;
            }
        }

        return true;
    }

    async handleSave() {
        if (!this.validateData()) {
            return;
        }

        this.isLoading = true;

        // Clean data for Apex (remove temporary 'key' property)
        const recordsToSave = this.rows.map(row => {
            const { key, ...cleanRow } = row;
            return cleanRow;
        });

        try {
            await saveDiscounts({
                discountsToUpsert: recordsToSave,
                discountsToDelete: this.deletedRecordIds
            });

            this.showToast('Success', 'Discounts saved successfully', 'success');
            this.deletedRecordIds = []; // Clear deleted queue
            await refreshApex(this.wiredDiscountResult); // Reload data

        } catch (error) {
            console.error(error);
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}