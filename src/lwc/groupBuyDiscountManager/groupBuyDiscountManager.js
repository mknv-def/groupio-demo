import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getDiscounts from '@salesforce/apex/GroupBuyDiscountController.getDiscounts';
import saveDiscounts from '@salesforce/apex/GroupBuyDiscountController.saveDiscounts';

export default class GroupBuyDiscountManager extends LightningElement {
    @api recordId;

    @track rows = [];
    @track isLoading = false;
    @track isSaving = false;
    @track errorMsg = '';
    @track successMsg = '';

    deletedRecordIds = [];
    wiredDiscountResult;

    @wire(getDiscounts, { proposalId: '$recordId' })
    wiredDiscounts(result) {
        this.wiredDiscountResult = result;
        if (result.data) {
            this.rows = result.data.map(item => ({
                ...item,
                key: item.Id,
                discountDisplay: item.Discount__c ? (item.Discount__c * 100).toFixed(1) + '%' : '0%'
            }));
            this.errorMsg = '';
        } else if (result.error) {
            this.errorMsg = 'Error loading discounts';
            console.error(result.error);
        }
    }

    // ===============================
    // GETTERS
    // ===============================

    get hasRows() {
        return this.rows.length > 0;
    }

    get noRows() {
        return this.rows.length === 0;
    }

    get isSaveDisabled() {
        return this.isLoading || this.isSaving || this.rows.length === 0;
    }

    get rowsWithIndex() {
        return this.rows.map((row, index) => ({
            ...row,
            index,
            tierNumber: index + 1,
            discountPercent: row.Discount__c ? (row.Discount__c * 100).toFixed(1) : '0'
        }));
    }

    // ===============================
    // HANDLERS
    // ===============================

    handleAddRow() {
        const newRow = {
            key: Date.now(),
            Id: null,
            Group_Buy_Proposal__c: this.recordId,
            Min_Quota_For_Discount__c: null,
            Max_Quota_Discount__c: null,
            Discount__c: null
        };
        this.rows = [...this.rows, newRow];
        this.clearMessages();
    }

    handleDeleteRow(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const rowToDelete = this.rows[index];

        if (rowToDelete.Id) {
            this.deletedRecordIds.push(rowToDelete.Id);
        }

        this.rows = this.rows.filter((_, i) => i !== index);
        this.clearMessages();
    }

    handleInputChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const field = event.target.dataset.field;
        let value = event.target.value;

        // Convert percentage input to decimal for Discount__c
        if (field === 'Discount__c' && value !== null && value !== '') {
            value = parseFloat(value) / 100;
        }

        const updatedRows = [...this.rows];
        updatedRows[index] = {
            ...updatedRows[index],
            [field]: value
        };
        this.rows = updatedRows;
        this.clearMessages();
    }

    clearMessages() {
        this.errorMsg = '';
        this.successMsg = '';
    }

    validateData() {
        // Basic field validation
        const allValid = [...this.template.querySelectorAll('lightning-input')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);

        if (!allValid) {
            this.errorMsg = 'Please complete all required fields.';
            return false;
        }

        // Logic validation (Min <= Max)
        for (let row of this.rows) {
            let min = Number(row.Min_Quota_For_Discount__c);
            let max = Number(row.Max_Quota_Discount__c);

            if (min > max) {
                this.errorMsg = `Min Quota (${min}) cannot be greater than Max Quota (${max}).`;
                return false;
            }
        }

        // Overlap validation
        let sortedRows = [...this.rows].sort((a, b) => {
            return Number(a.Min_Quota_For_Discount__c) - Number(b.Min_Quota_For_Discount__c);
        });

        for (let i = 0; i < sortedRows.length - 1; i++) {
            let current = sortedRows[i];
            let next = sortedRows[i + 1];

            let currentMax = Number(current.Max_Quota_Discount__c);
            let nextMin = Number(next.Min_Quota_For_Discount__c);

            if (currentMax >= nextMin) {
                this.errorMsg = `Quota range overlap: [${current.Min_Quota_For_Discount__c}-${current.Max_Quota_Discount__c}] and [${next.Min_Quota_For_Discount__c}-${next.Max_Quota_Discount__c}]`;
                return false;
            }
        }

        return true;
    }

    async handleSave() {
        if (!this.validateData()) {
            return;
        }

        this.isSaving = true;
        this.clearMessages();

        const recordsToSave = this.rows.map(row => {
            const { key, discountDisplay, tierNumber, discountPercent, index, ...cleanRow } = row;
            return cleanRow;
        });

        try {
            await saveDiscounts({
                discountsToUpsert: recordsToSave,
                discountsToDelete: this.deletedRecordIds
            });

            this.successMsg = 'Discounts saved successfully!';
            this.deletedRecordIds = [];
            await refreshApex(this.wiredDiscountResult);

            // Auto-hide success message
            setTimeout(() => {
                this.successMsg = '';
            }, 3000);

        } catch (error) {
            console.error(error);
            this.errorMsg = error.body ? error.body.message : error.message;
        } finally {
            this.isSaving = false;
        }
    }
}
