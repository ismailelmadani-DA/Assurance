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
            'isCurrency:', this.isCurrency,
            'isNumber:', this.isNumber,
            'Value:', this.fieldValue);
            
        // Debug URL fields
        if (this.isUrl) {
            console.log('URL field details:');
            console.log('  fieldName:', this.fieldName);
            console.log('  displayField:', this.displayField);
            console.log('  fieldValue:', this.fieldValue);
            console.log('  displayValue:', this.displayValue);
            console.log('  recordId:', this.recordId);
            console.log('  record.Id:', this.record.Id);
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
        return this.getFieldValue(this.record, this.displayField || this.fieldName);
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
        
        // Debug information
        console.log('Link clicked for:', this.fieldName);
        console.log('Record ID:', this.record.Id);
        console.log('Link clicked for:', this.fieldValue);
        
        // Get the record ID from the main record, not the field value
         const recordId = this.fieldValue.split('/')[1];
        console.log('recordId'+recordId);
        
        if (recordId) {
            console.log('Dispatching linkclick event with recordId:', recordId);
            
            const linkClickEvent = new CustomEvent('linkclick', {
                detail: {
                    recordId: recordId,
                    fieldName: this.fieldName
                },
                bubbles: true,
                composed: true
            });
            
            this.dispatchEvent(linkClickEvent);
        } else {
            console.error('No record ID available for navigation');
        }
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