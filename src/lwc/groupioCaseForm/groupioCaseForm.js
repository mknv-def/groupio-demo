import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import createCase from '@salesforce/apex/CaseController.createCase';

/**
 * Case Form Component
 * 
 * predefinedReason determines the case type and visible fields:
 * - "Business Group Onboarding" -> B2B Customer Registration (shows business fields)
 * - "Merchandiser Application" -> Merchandiser Registration (shows business fields)
 * - "Proposal Approval Request" -> New Product Approval (shows product fields)
 * - "General Inquiry" / other -> Standard Inquiry (shows order reference)
 */
export default class GroupioCaseForm extends NavigationMixin(LightningElement) {
    // ===============================
    // PUBLIC PROPERTIES (from Experience Builder)
    // ===============================
    @api cardTitle = 'Submit a Request';
    @api predefinedReason = 'General Inquiry'; // Determines case type
    @api accountId;
    @api proposalId; // Optional: link to Group_Buy_Proposal__c
    @api orderId; // Optional: link to Order

    // ===============================
    // STATE
    // ===============================
    @track isSubmitted = false;
    @track isSubmitting = false;
    @track errorMessage = '';
    @track caseId = '';
    @track caseNumber = '';

    // ===============================
    // FORM FIELDS
    // ===============================
    // Contact
    @track suppliedName = '';
    @track suppliedEmail = '';
    @track suppliedPhone = '';
    @track priority = 'Medium';

    // Business (for Registration types)
    @track companyName = '';
    @track businessType = '';
    @track taxId = '';
    @track companyRegistrationNumber = '';
    @track website = '';

    // Product (for New Product Approval)
    @track productName = '';
    @track proposedCategory = '';
    @track proposedPrice = null;

    // Order Reference (for Standard Inquiry)
    @track orderReference = '';

    // Request Details
    @track subType = '';
    @track subject = '';
    @track description = '';

    // ===============================
    // OPTIONS
    // ===============================
    priorityOptions = [
        { label: 'Low', value: 'Low' },
        { label: 'Medium', value: 'Medium' },
        { label: 'High', value: 'High' }
    ];

    businessTypeOptions = [
        { label: 'Retail', value: 'Retail' },
        { label: 'Wholesale', value: 'Wholesale' },
        { label: 'Distributor', value: 'Distributor' }
    ];

    // Sub-type options mapped by Type__c
    subTypeMap = {
        'Standard Inquiry': [
            { label: 'Order Status', value: 'Order Status' },
            { label: 'Delivery Question', value: 'Delivery Question' },
            { label: 'Payment Issue', value: 'Payment Issue' },
            { label: 'Product Information', value: 'Product Information' },
            { label: 'Discount Question', value: 'Discount Question' },
            { label: 'Technical Support', value: 'Technical Support' },
            { label: 'Other', value: 'Other' }
        ],
        'Merchandiser Registration': [
            { label: 'New Application', value: 'New Application' },
            { label: 'Document Update', value: 'Document Update' },
            { label: 'Status Check', value: 'Status Check' }
        ],
        'B2B Customer Registration': [
            { label: 'New Account Request', value: 'New Account Request' },
            { label: 'Credit Application', value: 'Credit Application' },
            { label: 'Account Upgrade', value: 'Account Upgrade' }
        ],
        'New Product Approval': [
            { label: 'New Product Submission', value: 'New Product Submission' },
            { label: 'Product Update', value: 'Product Update' },
            { label: 'Resubmission', value: 'Resubmission' }
        ]
    };

    // ===============================
    // LIFECYCLE
    // ===============================
    connectedCallback() {
        // Set default sub-type based on case type
        const subTypes = this.subTypeOptions;
        if (subTypes.length > 0) {
            this.subType = subTypes[0].value;
        }

        // Auto-generate subject based on case type
        this.subject = this.getDefaultSubject();
    }

    // ===============================
    // COMPUTED PROPERTIES - CASE TYPE MAPPING
    // ===============================
    
    /**
     * Maps predefinedReason to Type__c value
     */
    get caseType() {
        const reasonToTypeMap = {
            'Business Group Onboarding': 'B2B Customer Registration',
            'Merchandiser Application': 'Merchandiser Registration',
            'Proposal Approval Request': 'New Product Approval',
            'General Inquiry': 'Standard Inquiry'
        };
        return reasonToTypeMap[this.predefinedReason] || 'Standard Inquiry';
    }

    /**
     * Determines if Business section should be visible
     * Shows for: B2B Customer Registration, Merchandiser Registration
     */
    get showBusinessSection() {
        return ['B2B Customer Registration', 'Merchandiser Registration'].includes(this.caseType);
    }

    /**
     * Determines if Product section should be visible
     * Shows for: New Product Approval
     */
    get showProductSection() {
        return this.caseType === 'New Product Approval';
    }

    /**
     * Determines if Order Reference section should be visible
     * Shows for: Standard Inquiry
     */
    get showOrderSection() {
        return this.caseType === 'Standard Inquiry';
    }

    /**
     * Gets sub-type options based on current case type
     */
    get subTypeOptions() {
        return this.subTypeMap[this.caseType] || [];
    }

    /**
     * Determines if sub-type combobox should be visible
     */
    get hasSubTypes() {
        return this.subTypeOptions.length > 0;
    }

    // ===============================
    // HELPERS
    // ===============================
    
    getDefaultSubject() {
        const subjectMap = {
            'B2B Customer Registration': 'B2B Customer Registration Request',
            'Merchandiser Registration': 'Merchandiser Application',
            'New Product Approval': 'New Product Approval Request',
            'Standard Inquiry': ''
        };
        return subjectMap[this.caseType] || '';
    }

    // ===============================
    // EVENT HANDLERS
    // ===============================
    
    handleInputChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
        this.errorMessage = '';
    }

    handlePriorityChange(event) {
        this.priority = event.detail.value;
    }

    handleBusinessTypeChange(event) {
        this.businessType = event.detail.value;
    }

    handleSubTypeChange(event) {
        this.subType = event.detail.value;
    }

    // ===============================
    // VALIDATION
    // ===============================
    
    validateForm() {
        // Contact validation
        if (!this.suppliedName?.trim()) {
            this.errorMessage = 'Please enter your name.';
            return false;
        }
        if (!this.suppliedEmail?.trim()) {
            this.errorMessage = 'Please enter your email.';
            return false;
        }

        // Email format validation
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(this.suppliedEmail)) {
            this.errorMessage = 'Please enter a valid email address.';
            return false;
        }

        // Business validation (for registration types)
        if (this.showBusinessSection) {
            if (!this.companyName?.trim()) {
                this.errorMessage = 'Please enter your company name.';
                return false;
            }
            if (!this.businessType) {
                this.errorMessage = 'Please select a business type.';
                return false;
            }
        }

        // Product validation (for New Product Approval)
        if (this.showProductSection) {
            if (!this.productName?.trim()) {
                this.errorMessage = 'Please enter the product name.';
                return false;
            }
        }

        // Subject validation
        if (!this.subject?.trim()) {
            this.errorMessage = 'Please enter a subject.';
            return false;
        }

        // Sub-type validation
        if (this.hasSubTypes && !this.subType) {
            this.errorMessage = 'Please select a request category.';
            return false;
        }

        return true;
    }

    // ===============================
    // SUBMIT
    // ===============================
    
    async handleSubmit() {
        this.errorMessage = '';

        if (!this.validateForm()) {
            return;
        }

        this.isSubmitting = true;

        try {
            const caseData = {
                // Standard fields
                Subject: this.subject,
                Description: this.description,
                Status: 'New',
                Priority: this.priority,
                Reason: this.predefinedReason,
                Origin: 'Web',
                
                // Custom Type fields
                Type__c: this.caseType,
                Sub_Type__c: this.subType,

                // Contact fields
                SuppliedName: this.suppliedName,
                SuppliedEmail: this.suppliedEmail,
                SuppliedPhone: this.suppliedPhone
            };

            // Add AccountId if available
            if (this.accountId) {
                caseData.AccountId = this.accountId;
            }

            // Business fields (for Registration types)
            if (this.showBusinessSection) {
                caseData.SuppliedCompany = this.companyName;
                caseData.Business_Type__c = this.businessType;
                caseData.Tax_Id__c = this.taxId;
                caseData.Company_Registration_Number__c = this.companyRegistrationNumber;
                caseData.Website__c = this.website;
            }

            // Product fields (for New Product Approval)
            if (this.showProductSection) {
                caseData.Product_Name__c = this.productName;
                caseData.Proposed_Category__c = this.proposedCategory;
                if (this.proposedPrice) {
                    caseData.Proposed_Price__c = parseFloat(this.proposedPrice);
                }
                if (this.proposalId) {
                    caseData.Group_Buy_Proposal__c = this.proposalId;
                }
            }

            // Order reference (for Standard Inquiry)
            if (this.showOrderSection && this.orderId) {
                caseData.Order__c = this.orderId;
            }

            const result = await createCase({ caseData: JSON.stringify(caseData) });
            
            this.caseId = result.Id;
            this.caseNumber = result.CaseNumber;
            this.isSubmitted = true;

            this.showToast('Success', 'Your request has been submitted successfully.', 'success');

        } catch (error) {
            console.error('Error creating case:', error);
            this.errorMessage = error.body?.message || 'An error occurred while submitting your request.';
            this.showToast('Error', this.errorMessage, 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    // ===============================
    // RESET
    // ===============================
    
    handleReset() {
        this.isSubmitted = false;
        this.caseId = '';
        this.caseNumber = '';
        
        // Reset all form fields
        this.suppliedName = '';
        this.suppliedEmail = '';
        this.suppliedPhone = '';
        this.priority = 'Medium';
        
        this.companyName = '';
        this.businessType = '';
        this.taxId = '';
        this.companyRegistrationNumber = '';
        this.website = '';
        
        this.productName = '';
        this.proposedCategory = '';
        this.proposedPrice = null;
        
        this.orderReference = '';
        
        this.subject = this.getDefaultSubject();
        this.description = '';
        this.errorMessage = '';

        // Reset sub-type to first option
        const subTypes = this.subTypeOptions;
        if (subTypes.length > 0) {
            this.subType = subTypes[0].value;
        }
    }

    // ===============================
    // NAVIGATION & UTILITY
    // ===============================
    
    navigateToCaseRecord(event) {
        const recordId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }
}
