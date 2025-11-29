import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import userId from '@salesforce/user/Id';

export default class GroupioCaseForm extends NavigationMixin(LightningElement) {
    // Configurable properties
    @api predefinedReason; // e.g., 'Business Group Onboarding'
    @api cardTitle = 'Business Group Onboarding Application';

    // State
    isSubmitted = false;
    isSending = false;
    recordId = '';

    // Standard fields for automatic assignment
    currentUserId = userId;


    // --- Form Handlers ---

    handleSubmit(event) {
        // Stop default form submission and ensure Reason is applied
        event.preventDefault();

        this.isSending = true;

        // Get all data from form fields
        const fields = event.detail.fields;

        // Assign the predefined Reason set in the Builder
        fields.Reason = this.predefinedReason;

        // Use Subject field for Company Name as requested
        // Fields.Subject is collected via the input field in the HTML

        // Submit the form
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess(event) {
        this.recordId = event.detail.id;
        this.isSubmitted = true;
        this.isSending = false;

        // Show success message and indicate the next step
        this.showToast('Application Received', 'Your Business Group application has been received and is under review.', 'success');
    }

    handleError(error) {
        this.isSending = false;
        console.error('Case submission error:', error);
        // Display a generic error message, or parse the specific error from the response
        this.showToast('Error', 'Failed to submit request. Please check all required fields and contact your administrator.', 'error');
    }

    // --- Navigation & Utility ---

    navigateToCaseRecord(event) {
        // Navigate to the created Case record page
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.target.dataset.id,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(evt);
    }
}