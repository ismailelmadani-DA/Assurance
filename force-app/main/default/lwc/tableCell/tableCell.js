import { LightningElement, api } from 'lwc';

export default class TableCell extends LightningElement {
    @api record;
    @api fieldName;
    @api displayField;
    @api isUrl;
    @api isBoolean;
    @api isCurrency;
    @api isNumber;
    @api isText;
    @api isString = false;  // ✅ FIXED: Added missing isString prop
    @api recordId;
    @api isDate;
    @api currencyCode;
    @api isHtmlFormula = false;
    @api isTextFormula = false;
    @api isPicklist = false;
    @api isMultiPicklist = false;
    @api isTextArea = false;

    connectedCallback() {
        console.log('TableCell connected - Field:', this.fieldName, 
            'Type Info:', 
            'isPicklist:', this.isPicklist, 
            'isMultiPicklist:', this.isMultiPicklist, 
            'isTextArea:', this.isTextArea,
            'isString:', this.isString,
            'isCurrency:', this.isCurrency,
            'isNumber:', this.isNumber,
            'Value:', this.fieldValue);
            
        // Debug URL fields
        if (this.isUrl) {
            console.log('URL field details:');
            console.log('  fieldName:', this.fieldName);
            console.log('  displayField:', this.displayField);
            console.log('  fieldValue (URL link):', this.fieldValue);
            console.log('  displayValue (displayed text):', this.displayValue);
            console.log('  recordId (record):', this.recordId);
            console.log('  record.Id:', this.record?.Id);
        }
    }

    renderedCallback() {
        // If this is an HTML formula field, set the innerHTML of the container
        if (this.isHtmlFormula && this.fieldValue) {
            const htmlContainer = this.template.querySelector('.html-formula-container');
            if (htmlContainer) {
                htmlContainer.innerHTML = this.fieldValue;
            }
        }
        
        // For text area fields, implement expandable functionality
        if (this.isTextArea) {
            const textareaContainer = this.template.querySelector('.textarea-container');
            if (textareaContainer) {
                textareaContainer.addEventListener('click', this.handleTextAreaClick.bind(this));
            }
        }
    }

    get formattedCurrency() {
        if (this.fieldValue == null || this.fieldValue === undefined || this.fieldValue === '') {
            return '';
        }
        
        try {
            // Parse the value as a float
            const numValue = parseFloat(this.fieldValue);
            
            // Check if the value is a valid number
            if (isNaN(numValue)) {
                console.log('Invalid currency value:', this.fieldValue);
                return this.fieldValue;
            }
            
            // Format the number using locale options
            const formattedNum = new Intl.NumberFormat('fr-FR', {
                style: 'currency',
                currency: this.currencyCode || 'EUR',
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            }).format(numValue);
            
            return formattedNum;
        } catch (error) {
            console.error('Error formatting currency:', error);
            return this.fieldValue;
        }
    }

    get formattedNumber() {
        if (this.fieldValue == null || this.fieldValue === undefined || this.fieldValue === '') {
            return '';
        }
        
        try {
            // Parse the value as a float
            const numValue = parseFloat(this.fieldValue);
            
            // Check if the value is a valid number
            if (isNaN(numValue)) {
                console.log('Invalid number value:', this.fieldValue);
                return this.fieldValue;
            }
            
            // Determine if this is a decimal number or integer
            const isDecimal = numValue % 1 !== 0;
            
            // Format the number using locale options
            const formattedNum = new Intl.NumberFormat('fr-FR', {
                minimumFractionDigits: isDecimal ? 2 : 0,
                maximumFractionDigits: isDecimal ? 2 : 0
            }).format(numValue);
            
            return formattedNum;
        } catch (error) {
            console.error('Error formatting number:', error);
            return this.fieldValue;
        }
    }

    // Get the field value from the record
    get fieldValue() {
        return this.getFieldValue(this.record, this.fieldName);
    }

    // Get the display value for URL fields
    get displayValue() {
        let value = this.getFieldValue(this.record, this.displayField || this.fieldName);
        
        // ✅ CLEAN UP Num_ro_d_immatriculation__c - Remove line breaks and ID part
        if (this.displayField === 'Num_ro_d_immatriculation__c' && value) {
            // Remove line breaks and take only the first part before /
            value = value.replace(/[\n\r]/g, ' ').trim().split('/')[0].trim();
            console.log('✅ Cleaned displayValue for Num_ro_d_immatriculation__c:', value);
        }
        
        return value;
    }

    // Determine if text area content is expandable
    get isTextAreaExpanded() {
        return this.template.querySelector('.textarea-container.expanded') !== null;
    }

    // Get boolean icon based on field value
    get booleanIcon() {
        return this.fieldValue ? 'utility:check' : 'utility:close';
    }

    // Get boolean class based on field value
    get booleanClass() {
        return this.fieldValue ? 'boolean-true' : 'boolean-false';
    }

    // Parse multi-select picklist values
    get multiPicklistValues() {
        if (!this.fieldValue) return [];
        
        // Handle different formats of multi-picklist values
        if (typeof this.fieldValue === 'string') {
            // Standard semicolon-separated format
            return this.fieldValue.split(';').map(item => item.trim()).filter(item => item);
        } else if (Array.isArray(this.fieldValue)) {
            // Already an array
            return this.fieldValue;
        } else {
            // Unknown format, return empty array
            console.warn('Unknown multi-picklist format:', this.fieldValue);
            return [];
        }
    }
    
    // Handle click event for links
    handleClick(event) {
        event.preventDefault();
        event.stopPropagation();
        
        console.log('===== LINK CLICK DEBUG =====');
        console.log('Field name:', this.fieldName);
        console.log('Field value (should be URL):', this.fieldValue);
        console.log('Display value:', this.displayValue);
        console.log('Record ID (main):', this.recordId);
        console.log('===========================');
        
        // ✅ IMPROVED: Extract record ID from the URL field value
        if (!this.fieldValue || typeof this.fieldValue !== 'string') {
            console.error('❌ Invalid field value for URL:', this.fieldValue);
            return;
        }

        // Extract ID from URL (format: /a05qL000... or /001xx...)
        const recordIdFromUrl = this.extractRecordIdFromUrl(this.fieldValue);
        
        if (!recordIdFromUrl) {
            console.error('❌ Could not extract record ID from URL:', this.fieldValue);
            return;
        }

        console.log('✅ Extracted Record ID:', recordIdFromUrl);
        
        // Dispatch event to parent component
        const linkClickEvent = new CustomEvent('linkclick', {
            detail: {
                recordId: recordIdFromUrl,
                fieldName: this.fieldName,
                displayValue: this.displayValue
            },
            bubbles: true,
            composed: true
        });
        
        this.dispatchEvent(linkClickEvent);
        console.log('✅ Link click event dispatched');
    }

    // ✅ NEW: Helper method to extract record ID from URL
    extractRecordIdFromUrl(url) {
        if (!url || typeof url !== 'string') {
            return null;
        }

        // Remove leading/trailing whitespace
        url = url.trim();

        // Handle formats like "/a05qL000..." or "/001xx..."
        if (url.startsWith('/')) {
            const recordId = url.substring(1);  // Remove the leading slash
            
            // Validate Salesforce ID format (15 or 18 characters)
            if (recordId && (recordId.length === 15 || recordId.length === 18)) {
                return recordId;
            } else {
                console.warn('⚠️ Invalid Salesforce ID format:', recordId);
                return recordId;  // Return anyway in case it's valid
            }
        }

        // If no leading slash, assume it's already an ID
        if (url.length === 15 || url.length === 18) {
            return url;
        }

        console.error('❌ Cannot parse URL:', url);
        return null;
    }
    
    // Handle text area click to expand/collapse
    handleTextAreaClick(event) {
        event.stopPropagation();
        const container = this.template.querySelector('.textarea-container');
        if (container) {
            container.classList.toggle('expanded');
            
            // Update the read more/less text
            const expandButton = this.template.querySelector('.textarea-expand-button');
            if (expandButton) {
                if (container.classList.contains('expanded')) {
                    expandButton.textContent = 'Voir moins';
                } else {
                    expandButton.textContent = 'Voir plus';
                }
            }
        }
    }

    // Helper method to safely access nested properties
    getFieldValue(obj, path) {
        if (!obj || !path) {
            return null;
        }
        
        // Handle nested paths with dot notation
        if (path.includes('.')) {
            return path.split('.').reduce((prev, curr) => {
                return prev ? prev[curr] : null;
            }, obj);
        }
        
        // Direct property access
        return obj[path];
    }
}