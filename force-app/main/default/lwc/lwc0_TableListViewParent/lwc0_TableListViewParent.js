import { LightningElement, wire, track } from 'lwc';
import getAvailableSObjects from '@salesforce/apex/DA_ListViewController.getAvailableSObjects';
import getListViewsForSObject from '@salesforce/apex/DA_ListViewController.getListViewsForSObject';
import getRecordsForListViewPaginated from '@salesforce/apex/DA_ListViewController.getRecordsForListViewPaginated';
import getFieldsForListView from '@salesforce/apex/DA_ListViewController.getFieldsForListView';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import userId from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import PROFILE_ID_FIELD from '@salesforce/schema/User.ProfileId';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';
import LOCALE from '@salesforce/i18n/locale';
import CURRENCY from '@salesforce/i18n/currency';
import getRecordsForListViewPaginatedWithSearch from '@salesforce/apex/DA_ListViewController.getRecordsForListViewPaginatedWithSearch';


export default class Lwc0_TableListViewParent extends NavigationMixin(LightningElement) {
    @track sObjectOptions = [];
    @track listViewOptions = [];
    @track selectedSObject = '';
    @track selectedListView = '';
    @track columns = [];
    @track data = [];
    @track filteredData = [];
    @track paginatedData = [];
    @track searchTerm = '';
    @track isLoading = false;
    @track fieldsMetadata = {};
    @track lookupFields = [];
    @track lookupInfo = {};
    @track objectLogo = 'standard:custom';
    @track metadataByListView = new Map();
    @track isMyRecordsView = false;
    @track currentUserId = userId;
    @track currentUserProfileId;
    @track currentUserProfileName;
    @track userCurrencyCode = CURRENCY;
    @track fieldsList = [];

    // Sorting properties
    @track sortedBy = '';
    @track sortedDirection = 'asc';

    // Server-side Pagination properties
    @track pageSize = 50;
    @track currentPage = 1;
    @track totalRecords = 0;
    @track totalPages = 0;
    @track hasNextPage = false;
    @track hasPreviousPage = false;

    searchTimeout = null;

    // Get current user's profile information
    @wire(getRecord, { recordId: userId, fields: [PROFILE_ID_FIELD, PROFILE_NAME_FIELD] })
    wireUser({ error, data }) {
        if (data) {
            this.currentUserProfileId = data.fields.ProfileId.value;
            this.currentUserProfileName = data.fields.Profile.displayValue;
            console.log('Current user profile ID: ' + this.currentUserProfileId);
            console.log('Current user profile Name: ' + this.currentUserProfileName);
        } else if (error) {
            console.error('Error loading user profile:', error);
        }
    }

    @track showExport = false;

    // Computed properties for UI states
    get disableSObjectSelection() {
        return this.isLoading;
    }

    get disableListViewSelection() {
        return this.isLoading || !this.selectedSObject;
    }

    get disableSearch() {
       
        return this.isLoading || (!this.data.length && !this.searchTerm);
    }

    get isFirstPage() {
        return this.currentPage <= 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages || this.totalPages === 0;
    }

    get showPagination() {
        return this.totalRecords > 0;
    }

    get viewingMyRecords() {
        return this.isMyRecordsView;
    }

    // Pagination info display
    get paginationInfo() {
        if (this.totalRecords === 0) return 'Aucun enregistrement';
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(this.currentPage * this.pageSize, this.totalRecords);
        return `${start} - ${end} sur ${this.totalRecords}`;
    }

    // Page size options for dropdown
    get pageSizeOptions() {
        return [
            { label: '10', value: 10 },
            { label: '25', value: 25 },
            { label: '50', value: 50 },
            { label: '100', value: 100 },
            { label: '200', value: 200 }
        ];
    }

    // Get the list of available SObjects from metadata
    @wire(getAvailableSObjects)
    wiredSObjects({ data, error }) {
        this.isLoading = true;
        if (data) {
            const uniqueSObjects = [...new Set(data.map(item => item.sobjectName__c))];
            this.sObjectOptions = uniqueSObjects.map(sObject => ({
                label: sObject,
                value: sObject
            }));

            // Process and store metadata for later use
            data.forEach(item => {
                const key = `${item.sobjectName__c}_${item.listViewName__c}`;
                this.metadataByListView.set(key, item);
            });

            if (this.sObjectOptions.length > 0) {
                this.selectedSObject = this.sObjectOptions[0].value;
            }
            this.isLoading = false;
        } else if (error) {
            console.error('Error loading SObjects:', error);
            this.showToast('Error', 'Échec du chargement des objets : ' + (error.body?.message || error.message), 'error');
            this.isLoading = false;
        }
    }

    // Get list views when SObject is selected
    @wire(getListViewsForSObject, { sObjectName: '$selectedSObject' })
    wiredListViews({ data, error }) {
        if (this.selectedSObject) {
            // this.isLoading = true;
        }

        if (data) {
            this.listViewOptions = data.map(view => {
                const isMyView = view.showOwnerFilter__c ||
                    (view.listViewName__c && view.listViewName__c.startsWith('Mes '));
                console.log('Is "My" view:', isMyView);

                return {
                    label: view.listViewName__c,
                    value: view.listViewName__c,
                    isMyView: isMyView,
                    icon: isMyView ? 'utility:user' : undefined
                };
            });

            this.objectLogo = 'standard:custom';

            if (this.listViewOptions.length > 0) {
                this.selectedListView = this.listViewOptions[0].value;
                this.updateLogoFromMetadata(this.selectedSObject, this.selectedListView);
                this.loadRecords();
            } else {
                this.data = [];
                this.filteredData = [];
                this.paginatedData = [];
                this.totalRecords = 0;
                this.totalPages = 0;
                // this.isLoading = false;
            }
        } else if (error) {
            console.error('Error loading list views:', error);
            this.showToast('Error', 'Échec du chargement des vues de liste : ' + (error.body?.message || error.message), 'error');
            this.isLoading = false;
        }
    }

    // Update logo based on selected SObject and List View
    updateLogoFromMetadata(sObjectName, listViewName) {
        const key = `${sObjectName}_${listViewName}`;
        const metadata = this.metadataByListView.get(key);

        if (metadata && metadata.logo__c) {
            console.log(`Found logo in metadata for ${key}: ${metadata.logo__c}`);
            this.objectLogo = metadata.logo__c;
        } else {
            for (const [metaKey, metaValue] of this.metadataByListView.entries()) {
                if (metaKey.startsWith(sObjectName + '_') && metaValue.logo__c) {
                    console.log(`Using logo from related list view: ${metaValue.logo__c}`);
                    this.objectLogo = metaValue.logo__c;
                    break;
                }
            }

            if (!this.objectLogo || this.objectLogo === 'standard:custom') {
                console.log('Using default logo for ' + sObjectName);

                const logoMap = {
                    'Compte': 'standard:account',
                    'Police d\'assurance': 'standard:contract',
                    'Sinistre': 'standard:case',
                    'Mission': 'standard:task'
                };

                this.objectLogo = logoMap[sObjectName] || 'standard:custom';
            }

            if (listViewName && listViewName.startsWith('Mes ')) {
                this.objectLogo = 'standard:user_role';
            }
        }

        console.log('Final logo set to: ' + this.objectLogo);
    }

    // Handle changes in selected SObject
    handleSObjectChange(event) {
        this.selectedSObject = event.detail.value;
        this.selectedListView = '';
        this.searchTerm = '';
        this.data = [];
        this.filteredData = [];
        this.paginatedData = [];
        this.currentPage = 1;
        this.totalRecords = 0;
        this.totalPages = 0;

        if (this.selectedSObject == 'Revision') {
            this.showExport = true;
        } else {
            this.showExport = false;
        }
    }

    // Handle changes in selected List View
    handleListViewChange(event) {
    console.log('Selected list view changed to: ' + event.detail.value);
    this.selectedListView = event.detail.value;
    this.searchTerm = ''; // Clear search when changing view
    this.currentPage = 1;
    
    this.updateLogoFromMetadata(this.selectedSObject, this.selectedListView);
    
    this.loadRecords(); // Always use normal load when changing view
}

    // Toggle between "My" records and all records
    toggleMyRecords() {
        if (this.isMyRecordsView) {
            const regularView = this.listViewOptions.find(view => !view.isMyView);
            if (regularView) {
                this.selectedListView = regularView.value;
            }
        } else {
            const myView = this.listViewOptions.find(view => view.isMyView);
            if (myView) {
                this.selectedListView = myView.value;
            } else {
                const myViewName = 'Mes ' + this.selectedSObject;
                this.selectedListView = myViewName;
            }
        }

        this.currentPage = 1;
        this.updateLogoFromMetadata(this.selectedSObject, this.selectedListView);
        this.loadRecords();
    }

    // MAIN METHOD: Load records with server-side pagination
    loadRecords() {
        if (!this.selectedSObject || !this.selectedListView) {
            return Promise.reject(new Error('No SObject or ListView selected'));
        }

        this.isLoading = true;
        // this.data = [];
        // this.filteredData = [];
        // this.paginatedData = [];

        return new Promise((resolve, reject) => {
            // First get the fields for this list view
            getFieldsForListView({
                sObjectName: this.selectedSObject,
                listViewName: this.selectedListView
            })
                .then(result => {
                    this.fieldsList = result.fields;
                    this.fieldsMetadata = result.metadata;
                    this.lookupFields = result.lookups || [];
                    this.lookupInfo = result.lookupInfo || {};
                    this.isMyRecordsView = result.isMyRecordsView || false;

                    console.log('Fields metadata:', JSON.stringify(this.fieldsMetadata));
                    console.log('Lookup fields:', JSON.stringify(this.lookupFields));
                    console.log('Lookup info:', JSON.stringify(this.lookupInfo));
                    console.log('Is "My Records" view:', this.isMyRecordsView);

                    // Create columns for the table
                    this.columns = this.createModernColumns(this.fieldsList);
                    console.log('ColumnsVal:', JSON.stringify(this.columns));

                    // Get paginated records from server
                    return getRecordsForListViewPaginated({
                        sObjectName: this.selectedSObject,
                        listViewName: this.selectedListView,
                        fields: this.fieldsList,
                        pageSize: this.pageSize,
                        pageNumber: this.currentPage
                    });
                })
                .then(result => {
                    console.log('Paginated result:', JSON.stringify(result));

                    // Process records to add URL fields and format data for display
                    const recordsWithFormattedData = this.processRecords(result.records);

                    this.data = recordsWithFormattedData;
                    this.filteredData = recordsWithFormattedData;
                    this.paginatedData = recordsWithFormattedData;

                    // Update pagination info from server response
                    this.totalRecords = result.totalRecords;
                    this.totalPages = result.totalPages;
                    this.currentPage = result.currentPage;
                    this.hasNextPage = result.hasNextPage;
                    this.hasPreviousPage = result.hasPreviousPage;

                    this.isLoading = false;

                    // Animation for a seamless entry
                    setTimeout(() => {
                        const tableContainer = this.template.querySelector('.table-container');
                        if (tableContainer) {
                            tableContainer.classList.add('fade-in');
                        }
                    }, 100);

                    resolve(recordsWithFormattedData);
                })
                .catch(error => {
                    console.error('Error loading data:', error);
                    this.showToast('Error', 'Échec du chargement des données : ' + (error.body?.message || error.message), 'error');
                    this.isLoading = false;
                    reject(error);
                });
        });
    }

    // Process records to prepare for display
    processRecords(records) {
        if (!records || records.length === 0) return [];

        console.log('Sample record structure:', JSON.stringify(records[0]));

        return records.map(record => {
            const newRecord = { ...record };
            const recordKeys = Object.keys(newRecord);

            // First pass: identify all relationship fields in the record
            const relationshipFields = new Set();
            recordKeys.forEach(key => {
                if (newRecord[key] && typeof newRecord[key] === 'object' && newRecord[key].Id) {
                    relationshipFields.add(key);
                }
            });

            console.log('Detected relationship fields:', Array.from(relationshipFields));

            // Second pass: process all fields appropriately
            recordKeys.forEach(field => {
                const value = newRecord[field];
                const fieldMetadata = this.fieldsMetadata[field] || {};
                const fieldType = fieldMetadata.type;

                if (fieldType === 'PICKLIST' || fieldType === 'MULTIPICKLIST') {
                    console.log(`Processing ${fieldType} field:`, field, 'Value:', value);
                }

                if (field === 'Id') {
                    return;
                }

                // Check if field is a formula field with HTML or TEXT format
                const isFormula = fieldMetadata.formula === true;
                const isHtmlFormula = isFormula && fieldMetadata.formulaType === 'HTML';
                const isTextFormula = isFormula && fieldMetadata.formulaType === 'TEXT';

                if (isHtmlFormula) {
                    console.log('Processing HTML formula field:', field, value);
                    return;
                }

                if (isTextFormula) {
                    console.log('Processing Text formula field:', field, value);
                    return;
                }

                if (field === 'Name') {
                    newRecord[field + 'Url'] = '/' + newRecord.Id;
                }
                if (field === 'CaseNumber') {
                    console.log('URLCaseNumber', newRecord.Id);
                    newRecord[field + 'Url'] = '/' + newRecord.Id;
                }

                // Handle relationship fields in dot notation (e.g., Account.Name)
                if (field.includes('.')) {
                    this.processRelationshipField(newRecord, field, value);
                    return;
                }

                // Handle fields ending with Id which are lookups
                if (field.endsWith('Id') && field !== 'Id') {
                    const relationshipName = field.substring(0, field.length - 2);
                    const relationshipField = relationshipName + '__r';

                    if (newRecord[relationshipField] && newRecord[relationshipField].Id) {
                        this.processRelationshipData(newRecord, relationshipName, newRecord[relationshipField], value);
                    } else {
                        this.processIdOnlyField(newRecord, relationshipName, value);
                    }

                    console.log('newRecord' + value);
                    console.log('relationshipName' + relationshipName);
                    console.log('newRecord' + newRecord);

                    if (field === 'OwnerId' && value === this.currentUserId) {
                        newRecord.isOwnedByCurrentUser = true;
                    }

                    return;
                }

                // Handle custom lookup fields (ending with __c and having __r relationship)
                if (field.endsWith('__c')) {
                    const possibleRelationField = field.replace('__c', '__r');
                    if (relationshipFields.has(possibleRelationField)) {
                        const relationshipName = field.substring(0, field.length - 3);
                        this.processRelationshipData(newRecord, relationshipName, newRecord[possibleRelationField], value);
                        return;
                    }
                }

                // Process direct relationship objects (fields ending with __r or relationship objects)
                if (relationshipFields.has(field)) {
                    const relationshipName = field.endsWith('__r')
                        ? field.substring(0, field.length - 3)
                        : field;

                    this.processRelationshipData(newRecord, relationshipName, newRecord[field], newRecord[relationshipName + '__c'] || newRecord[relationshipName + 'Id']);
                    return;
                }

                // Format date fields
                this.formatDateField(newRecord, field);
            });

            console.log('Processed record:', JSON.stringify(newRecord));
            return newRecord;
        });
    }

    // Helper method to process relationship data
    processRelationshipData(record, relationshipName, relationshipObject, idValue) {
        if (!relationshipObject) return;

        let displayValue = this.findBestDisplayField(relationshipObject);

        record[relationshipName + 'DisplayValue'] = displayValue || 'View';
        record[relationshipName + 'LookupUrl'] = '/' + (relationshipObject.Id || idValue);

        console.log('relationshipObject' + JSON.stringify(relationshipObject));
    }

    // Helper method to process ID-only lookup fields
    processIdOnlyField(record, relationshipName, idValue) {
        if (!idValue) return;

        record[relationshipName + 'DisplayValue'] = 'View ' + relationshipName;
        record[relationshipName + 'LookupUrl'] = '/' + idValue;

        console.log('processIdOnlyField' + idValue);
    }

    // Helper to find the best field to use as display value from a relationship object
    findBestDisplayField(obj) {
        if (!obj) return '';

        const displayFieldCandidates = [
            'Name', 'Title', 'Subject', 'CaseNumber', 'ClaimNumber',
            'ClaimNumber__c', 'Label', 'FullName', 'Username', 'RequestType__c'
        ];

        for (const field of displayFieldCandidates) {
            if (obj[field] !== undefined && obj[field] !== null) {
                return obj[field];
            }
        }

        for (const key in obj) {
            if (key !== 'Id' && typeof obj[key] === 'string' && obj[key]) {
                return obj[key];
            }
        }

        return obj.Id ? String(obj.Id).substring(0, 8) : '';
    }

    // Process a relationship field in dot notation (e.g., Account.Name)
    processRelationshipField(record, field, value) {
        const parts = field.split('.');
        if (parts.length !== 2) return;

        const relationshipName = parts[0];
        const fieldName = parts[1];

        record[relationshipName + fieldName + 'Formatted'] = value;
    }

    // Format date fields
    formatDateField(record, field) {
        const fieldMetadata = this.fieldsMetadata[field] || {};
        const fieldType = fieldMetadata.type;
        const value = record[field];

        if (value && this.isDateField(field, fieldType)) {
            try {
                const dateObj = new Date(value);
                if (!isNaN(dateObj.getTime())) {
                    const day = String(dateObj.getDate()).padStart(2, '0');
                    const month = String(dateObj.getMonth() + 1).padStart(2, '0');
                    const year = dateObj.getFullYear();

                    record[field + 'Formatted'] = `${day}-${month}-${year}`;
                }
                console.log('record[field + Formatted]', record[field + 'Formatted']);
            } catch (error) {
                console.error('Error formatting date:', error);
                record[field + 'Formatted'] = value;
            }
        }
    }

    // Check if a field is a date field
    isDateField(field, fieldType) {
        return fieldType === 'DATE' || fieldType === 'DATETIME' ||
            field.toLowerCase().includes('date') ||
            field === 'CreatedDate' || field === 'LastModifiedDate' ||
            field === 'EffectiveDate' || field === 'ExpirationDate';
    }

    // Create column definitions for modern table
    createModernColumns(fieldList) {
        return fieldList
            .filter(field => field !== 'Id')
            .map(field => {
                const fieldMetadata = this.fieldsMetadata[field] || {};
                const fieldType = fieldMetadata.type;
                console.log('Field:', field, 'Type:', fieldType);

                // Check if this is a formula field
                const isFormula = fieldMetadata.formula === true;
                const formulaType = fieldMetadata.formulaType;

                // Handle formula fields based on their return type
                const isHtmlFormula = isFormula && formulaType === 'HTML';
                const isTextFormula = isFormula && formulaType === 'TEXT';
                const isCurrencyFormula = isFormula && (formulaType === 'CURRENCY');
                const isNumberFormula = isFormula && (formulaType === 'DOUBLE' || formulaType === 'NUMBER' || formulaType === 'DECIMAL' || formulaType === 'PERCENT');

                // Detect field types
                const isPicklist = fieldType === 'PICKLIST';
                const isMultiPicklist = fieldType === 'MULTIPICKLIST';
                const isTextArea = fieldType === 'TEXTAREA';
                const isRichText = isTextArea && fieldMetadata.isRichText === true;
                const isCurrency = fieldType === 'CURRENCY' || isCurrencyFormula;
                const isNumber = fieldType === 'DOUBLE' || fieldType === 'DECIMAL' || fieldType === 'NUMBER' ||
                    fieldType === 'PERCENT' || isNumberFormula;
                const isReference = fieldMetadata.isReference;
                const isExplicitLookup = this.lookupFields.includes(field);
                const isRelationshipField = field.includes('.');
                const isDateFieldCheck = this.isDateField(field, fieldType);
                const isBooleanField = fieldType === 'BOOLEAN' || formulaType === 'BOOLEAN';

                // Detect pure string fields
                const isString = (fieldType === 'STRING' || fieldType === 'TEXT' || fieldType === 'ID') &&
                    !isReference && !isExplicitLookup && !isRelationshipField &&
                    !field.endsWith('Id') && !isNumberFormula && !isTextFormula && !isHtmlFormula && !isFormula &&
                    !field.endsWith('Name') && field !== 'Name' && field !== 'CaseNumber';

                // Log special field types for debugging
                if (isTextArea) {
                    console.log('TextArea Field detected:', field, 'isRichText:', isRichText);
                }

                if (isString) {
                    console.log('String Field detected:', field, 'Type:', fieldType);
                }

                // Base column configuration for modern table
                const column = {
                    label: this.formatFieldLabel(field, fieldMetadata.label),
                    fieldName: field,
                    type: 'text',
                    isDate: false,
                    isText: false,
                    isString: false,
                    isUrl: false,
                    isBoolean: false,
                    isCurrency: isCurrency,
                    isNumber: isNumber,
                    isHtmlFormula: isHtmlFormula,
                    isTextFormula: isTextFormula,
                    isPicklist: isPicklist,
                    isMultiPicklist: isMultiPicklist,
                    isTextArea: isTextArea,
                    isRichText: isRichText,
                    displayField: field,
                    isSorted: this.sortedBy === field,
                    sortIconName: this.sortedBy === field
                        ? this.sortedDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown'
                        : 'utility:arrowup',
                    headerClass: this.getHeaderClass(fieldType, isFormula, formulaType),
                    cellClass: this.getCellClass(field, fieldType, isReference || isExplicitLookup, isFormula, formulaType)
                };

                // Configure column based on field type and pattern - ORDER MATTERS HERE
                if (isTextArea) {
                    column.isTextArea = true;
                    console.log('Setting TextArea for field:', field);
                }
                else if (isString) {
                    column.isString = true;
                    console.log('Setting String for field:', field);
                }
                else if (isPicklist) {
                    column.isPicklist = true;
                    console.log('Setting Picklist for field:', field);
                }
                else if (isMultiPicklist) {
                    column.isMultiPicklist = true;
                    console.log('Setting MultiPicklist for field:', field);
                }
                else if (isHtmlFormula) {
                    column.isHtmlFormula = true;
                    console.log('Setting HTML Formula for field:', field);
                }
                else if (isTextFormula) {
                    column.isTextFormula = true;
                    console.log('Setting Text Formula for field:', field);
                }
                else if (isCurrency) {
                    column.isCurrency = true;
                    console.log('Setting Currency for field:', field);
                }
                else if (isNumber) {
                    column.isNumber = true;
                    console.log('Setting Number for field:', field);
                }
                else if (isDateFieldCheck) {
                    console.log('Date field:', field);
                    console.log('Date field type:', fieldType);
                    console.log('Date field metadata:', fieldMetadata);
                    column.isDate = true;
                    column.fieldName = field + 'Formatted';
                    console.log('Setting Date for field:', field);
                }
                else if (isBooleanField) {
                    column.isBoolean = true;
                    console.log('Setting Boolean for field:', field);
                }
                else if (field === 'Name' || field.endsWith('Name') || field === 'CaseNumber') {
                    column.fieldName = field + 'Url';
                    column.isUrl = true;
                    column.displayField = field;
                    console.log('Setting Name URL for field:', field);
                }
                else if (isRelationshipField) {
                    column.fieldName = field.replace('.', '') + 'Formatted';
                    column.isText = true;
                    console.log('Setting Relationship for field:', field);
                }
                else if (field.endsWith('__c') && !field.endsWith('Number__c') && !field.endsWith('Date__c') && !field.startsWith('Date')) {
                    const relationshipName = field.substring(0, field.length - 3);
                    column.fieldName = relationshipName + 'LookupUrl';
                    column.isUrl = true;
                    column.displayField = relationshipName + 'DisplayValue';
                    console.log('Setting Custom Lookup for field:', field);
                }
                else if (isReference || field.endsWith('Id') || isExplicitLookup) {
                    const relationshipName = field.endsWith('Id') ? field.substring(0, field.length - 2) : field;
                    column.fieldName = relationshipName + 'LookupUrl';
                    column.isUrl = true;
                    column.displayField = relationshipName + 'DisplayValue';
                    console.log('Setting Reference Lookup for field:', field);
                }
                else {
                    column.isText = true;
                    console.log('Setting Text (default) for field:', field);
                }

                return column;
            });
    }

    // Get header class for styling
    getHeaderClass(fieldType, isFormula, formulaType) {
        let classes = '';

        if (isFormula) {
            if (formulaType === 'CURRENCY' || formulaType === 'DOUBLE' ||
                formulaType === 'NUMBER' || formulaType === 'DECIMAL' ||
                formulaType === 'PERCENT') {
                classes += 'cell-right ';
            } else if (formulaType === 'BOOLEAN') {
                classes += 'cell-center ';
            }
        }
        else if (fieldType === 'CURRENCY' || fieldType === 'DOUBLE' ||
            fieldType === 'NUMBER' || fieldType === 'DECIMAL' ||
            fieldType === 'PERCENT') {
            classes += 'cell-right ';
        } else if (fieldType === 'BOOLEAN') {
            classes += 'cell-center ';
        }

        return classes.trim();
    }

    // Get cell class for styling
    getCellClass(field, fieldType, isLookup, isFormula, formulaType) {
        let classes = '';

        if (isLookup || field === 'Name' || field.endsWith('Name')) {
            classes += 'cell-link ';
        }

        if (isFormula) {
            if (formulaType === 'CURRENCY' || formulaType === 'DOUBLE' ||
                formulaType === 'NUMBER' || formulaType === 'DECIMAL' ||
                formulaType === 'PERCENT') {
                classes += 'cell-right ';
            } else if (formulaType === 'BOOLEAN') {
                classes += 'cell-center ';
            }
        }
        else if (fieldType === 'CURRENCY' || fieldType === 'DOUBLE' ||
            fieldType === 'NUMBER' || fieldType === 'DECIMAL' ||
            fieldType === 'PERCENT') {
            classes += 'cell-right ';
        } else if (fieldType === 'BOOLEAN') {
            classes += 'cell-center ';
        }

        return classes.trim();
    }

    // Format the field API name to a more readable label
    formatFieldLabel(fieldName, metadataLabel) {
        if (metadataLabel) {
            return metadataLabel;
        }

        if (fieldName.includes('.')) {
            const parts = fieldName.split('.');
            return this.formatFieldLabel(parts[1], null);
        }

        const key = `${this.selectedSObject}_${this.selectedListView}`;
        const metadata = this.metadataByListView.get(key);

        if (metadata && metadata.labelOfFields__c) {
            const labelMappings = metadata.labelOfFields__c.split(';');
            for (const mapping of labelMappings) {
                const [field, label] = mapping.split(':');
                if (field && field.trim() === fieldName) {
                    return label.trim();
                }
            }
        }

        return fieldName
            .replace(/([A-Z])/g, ' $1')
            .replace(/__c/g, '')
            .replace(/_/g, ' ')
            .replace(/Id$/g, '')
            .trim();
    }

    // Handle search input - client-side filtering of current page only
    handleSearchChange(event) {
    this.searchTerm = event.detail.value.toLowerCase();
    this.currentPage = 1; // Reset to first page on search
    
    // Clear any existing timeout
    if (this.searchTimeout) {
        clearTimeout(this.searchTimeout);
    }
    
    // Debounce search - wait 500ms after user stops typing
    this.searchTimeout = setTimeout(() => {
        this.performBackendSearch();
    }, 500);
}


performBackendSearch() {
    if (!this.selectedSObject || !this.selectedListView) {
        return;
    }
    
    this.isLoading = true;
    
    // Use backend search if there's a search term, otherwise use normal load
    if (this.searchTerm && this.searchTerm.trim().length > 0) {
        getRecordsForListViewPaginatedWithSearch({
            sObjectName: this.selectedSObject,
            listViewName: this.selectedListView,
            fields: this.fieldsList,
            pageSize: this.pageSize,
            pageNumber: this.currentPage,
            searchTerm: this.searchTerm.trim()
        })
        .then(result => {
            console.log('Search result:', JSON.stringify(result));
            
            // Process records
            const recordsWithFormattedData = this.processRecords(result.records);
            
            this.data = recordsWithFormattedData;
            this.filteredData = recordsWithFormattedData;
            this.paginatedData = recordsWithFormattedData;
            
            // Update pagination info
            this.totalRecords = result.totalRecords;
            this.totalPages = result.totalPages;
            this.currentPage = result.currentPage;
            this.hasNextPage = result.hasNextPage;
            this.hasPreviousPage = result.hasPreviousPage;
            
            this.isLoading = false;
            
            // Show message if no results
            if (recordsWithFormattedData.length === 0) {
                // this.showToast('Info', `Aucun résultat trouvé pour "${this.searchTerm}"`, 'info');
            } else {
                this.showToast('Success', `${result.totalRecords} résultat(s) trouvé(s)`, 'success');
            }
        })
        .catch(error => {
            console.error('Error searching:', error);
            this.showToast('Error', 'Erreur lors de la recherche : ' + (error.body?.message || error.message), 'error');
            this.isLoading = false;
        });
    } else {
        // No search term - load normally
        this.loadRecords();
    }
}

    // Handle column click for sorting
    handleColumnClick(event) {
        this.isLoading = true;
        const fieldName = event.currentTarget.dataset.field;

        if (this.sortedBy === fieldName) {
            this.sortedDirection = this.sortedDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortedBy = fieldName;
            this.sortedDirection = 'asc';
        }

        let sortField = fieldName;
        let isLookupField = false;

        if (fieldName.endsWith('Url')) {
            sortField = fieldName.replace('Url', '');
        } else if (fieldName.endsWith('LookupUrl')) {
            const baseField = fieldName.replace('LookupUrl', '');
            sortField = baseField + 'DisplayValue';
            isLookupField = true;
        } else if (fieldName.endsWith('Formatted')) {
            sortField = fieldName.replace('Formatted', '');
        } else if (fieldName.endsWith('DisplayValue')) {
            sortField = fieldName;
            isLookupField = true;
        }

        console.log(`Sorting by field: ${sortField} (original: ${fieldName}), isLookup: ${isLookupField}`);

        const cloneData = [...this.paginatedData];
        cloneData.sort((a, b) => {
            const valueA = isLookupField ? a[sortField] : this.getSortValue(a[sortField]);
            const valueB = isLookupField ? b[sortField] : this.getSortValue(b[sortField]);
            return this.compareValues(valueA, valueB, this.sortedDirection);
        });

        this.paginatedData = cloneData;

        this.columns = this.columns.map(column => {
            return {
                ...column,
                isSorted: column.fieldName === fieldName,
                sortIconName: column.fieldName === fieldName
                    ? this.sortedDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown'
                    : 'utility:arrowup'
            };
        });

        this.isLoading = false;
    }

    // Helper method to get sortable value
    getSortValue(value) {
        if (value === null || value === undefined) {
            return null;
        }

        if (typeof value === 'object') {
            const possibleFields = ['Name', 'CaseNumber', 'ClaimNumber', 'ClaimNumber__c', 'RequestType__c',
                'Title', 'Subject', 'FullName', 'Username'];

            for (const field of possibleFields) {
                if (value[field] !== undefined && value[field] !== null) {
                    return value[field];
                }
            }

            for (const key in value) {
                if (key !== 'Id' && typeof value[key] === 'string' && value[key]) {
                    return value[key];
                }
            }

            return value.Id || '';
        }

        if (value instanceof Date) {
            return value.getTime();
        }

        if (typeof value === 'string') {
            if (value.includes('-') || value.includes('/')) {
                const dateObj = new Date(value);
                if (!isNaN(dateObj.getTime())) {
                    return dateObj.getTime();
                }
            }
        }

        return value;
    }

    // Helper method to compare values for sorting
    compareValues(a, b, sortDirection) {
        if (a === null || a === undefined) {
            return sortDirection === 'asc' ? 1 : -1;
        }
        if (b === null || b === undefined) {
            return sortDirection === 'asc' ? -1 : 1;
        }

        if (typeof a === 'string' && typeof b === 'string') {
            const aLower = a.toLowerCase();
            const bLower = b.toLowerCase();

            if (aLower > bLower) {
                return sortDirection === 'asc' ? 1 : -1;
            } else if (aLower < bLower) {
                return sortDirection === 'asc' ? -1 : 1;
            }
            return 0;
        }

        if (a > b) {
            return sortDirection === 'asc' ? 1 : -1;
        } else if (a < b) {
            return sortDirection === 'asc' ? -1 : 1;
        }

        return 0;
    }

    // Handle page size change - SERVER-SIDE
    handlePageSizeChange(event) {
    this.pageSize = parseInt(event.target.value, 10);
    this.currentPage = 1;
    
    // Use backend search if searching, otherwise normal load
    if (this.searchTerm && this.searchTerm.trim().length > 0) {
        this.performBackendSearch();
    } else {
        this.loadRecords();
    }
}


    // Handle previous page button click - SERVER-SIDE
    handlePrevious() {
    if (this.currentPage > 1) {
        this.currentPage = this.currentPage - 1;
        
        // Use backend search if searching, otherwise normal load
        if (this.searchTerm && this.searchTerm.trim().length > 0) {
            this.performBackendSearch();
        } else {
            this.loadRecords();
        }
    }
}

    handleNext() {
    if (this.currentPage < this.totalPages) {
        this.currentPage = this.currentPage + 1;
        
        // Use backend search if searching, otherwise normal load
        if (this.searchTerm && this.searchTerm.trim().length > 0) {
            this.performBackendSearch();
        } else {
            this.loadRecords();
        }
    }
}

    handlePageClick(event) {
    const selectedPage = parseInt(event.currentTarget.dataset.page, 10);
    if (selectedPage !== this.currentPage) {
        this.currentPage = selectedPage;
        
        // Use backend search if searching, otherwise normal load
        if (this.searchTerm && this.searchTerm.trim().length > 0) {
            this.performBackendSearch();
        } else {
            this.loadRecords();
        }
    }
}


    loadRecordsWithSearch() {
    if (!this.searchTerm || this.searchTerm.trim().length === 0) {
        // No search term - use normal pagination
        this.loadRecords();
    } else {
        // Has search term - use backend search
        this.performBackendSearch();
    }
}


    applyClientSideFilter() {
        if (!this.searchTerm) {
            this.filteredData = this.data;
            this.paginatedData = this.data;
            return;
        }

        this.filteredData = this.data.filter(row => {
            return Object.values(row).some(value => {
                if (value === null || value === undefined) {
                    return false;
                }

                if (typeof value === 'object') {
                    return Object.values(value).some(nestedValue =>
                        nestedValue && String(nestedValue).toLowerCase().includes(this.searchTerm)
                    );
                }

                return String(value).toLowerCase().includes(this.searchTerm);
            });
        });
        this.paginatedData = this.filteredData;
    }

    // Handle row click to navigate to record
    handleRowClick(event) {
        const recordId = event.currentTarget.dataset.id;
        if (recordId) {
            console.log('Row clicked, navigating to:', recordId);
            this.navigateToRecordPage(recordId);
        }
    }

    // Handle cell link click (prevent propagation to row click)
    handleCellLinkClick(event) {
        console.log('Cell link clicked:', JSON.stringify(event));
        console.log('Cell link clicked:', JSON.stringify(event.detail));
        console.log('Cell link clicked:', event.currentTarget.dataset.id);

        event.stopPropagation();
        const { recordId } = event.detail;
        if (recordId) {
            console.log('Navigating to record:', recordId);
            this.navigateToRecordPage(recordId);
        } else {
            console.error('No record ID provided in the click event');
        }
    }

    // Navigate to record detail page
    navigateToRecordPage(recordId) {
        console.log('Navigating to record page:', recordId);

        if (!recordId) {
            console.error('Cannot navigate: No record ID provided');
            return;
        }

        try {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    actionName: 'view'
                }
            });
        } catch (error) {
            console.error('Navigation error:', error);
            window.location.href = '/' + recordId;
        }
    }

    // Show toast message
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: variant === 'error' ? 'sticky' : 'dismissable'
        });
        this.dispatchEvent(event);
    }

    // Export data to CSV
    exportToCSV() {
        if (!this.data || this.data.length === 0) {
            this.showToast('Info', 'Aucune donnée à exporter', 'info');
            return;
        }

        this.isLoading = true;

        try {
            const headers = this.columns.map(col => col.label);

            const fields = this.columns.map(col => {
                if (col.isUrl) {
                    return col.displayField;
                }
                if (col.fieldName.endsWith('Formatted')) {
                    return col.fieldName.replace('Formatted', '');
                }
                return col.fieldName;
            });

            let csvContent = headers.join(',') + '\n';

            this.data.forEach(row => {
                const rowData = fields.map(field => {
                    let value = this.getFieldValue(row, field);

                    if (value === null || value === undefined) {
                        return '';
                    }

                    value = String(value).replace(/"/g, '""');
                    if (value.includes(',') || value.includes('\n') || value.includes('"')) {
                        value = `"${value}"`;
                    }

                    return value;
                });

                csvContent += rowData.join(',') + '\n';
            });

            const encodedUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent);
            const downloadLink = document.createElement('a');
            downloadLink.href = encodedUri;
            downloadLink.download = `${this.selectedSObject}_${this.selectedListView}.csv`;
            document.body.appendChild(downloadLink);
            downloadLink.click();
            document.body.removeChild(downloadLink);

            this.showToast('Success', 'Fichier exporté avec succès', 'success');
        } catch (error) {
            console.error('Error exporting to CSV:', error);
            this.showToast('Error', 'Échec de l\'exportation des données : ' + error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Helper method to safely access nested properties
    getFieldValue(obj, path) {
        if (!obj || !path) {
            return null;
        }

        if (path.includes('.')) {
            return path.split('.').reduce((prev, curr) => {
                return prev ? prev[curr] : null;
            }, obj);
        }

        return obj[path];
    }

    // Refresh data with a visual indicator of success
    refreshWithFeedback() {
        if (!this.isLoading && this.selectedSObject && this.selectedListView) {
            this.isLoading = true;

            const refreshButton = this.template.querySelector('.refresh-btn');
            if (refreshButton) {
                refreshButton.classList.add('rotate-animation');
            }

            setTimeout(() => {
                this.loadRecords()
                    .then(() => {
                        this.showToast('Success', 'Données actualisées avec succès', 'success');
                    })
                    .catch(error => {
                        console.error('Error refreshing data:', error);
                    })
                    .finally(() => {
                        if (refreshButton) {
                            refreshButton.classList.remove('rotate-animation');
                        }
                    });
            }, 300);
        }
    }

    // Refresh data
    refreshData() {
        if (!this.isLoading && this.selectedSObject && this.selectedListView) {
            this.loadRecords();
        }
    }

    // Handle row selection for mass actions (future enhancement)
    handleRowSelection(event) {
        const selectedRow = event.currentTarget.dataset.id;
    }

    // Toggle advanced filters panel (for future enhancement)
    toggleAdvancedFilters() {
        const filtersPanel = this.template.querySelector('.advanced-filters');
        if (filtersPanel) {
            filtersPanel.classList.toggle('filters-expanded');
        }
    }

    // Reset all filters to default values
    resetFilters() {
        this.searchTerm = '';
        this.currentPage = 1;
        this.loadRecords();
    }

    // Add additional keyboard support for accessibility
    handleKeyDown(event) {
        if (event.key === 'Enter' && event.target.classList.contains('data-row')) {
            const recordId = event.target.dataset.id;
            if (recordId) {
                this.navigateToRecordPage(recordId);
            }
        }
    }

    // Add method to enable future bulk actions
    performBulkAction(actionName) {
        this.showToast('Info', `L'action groupée ${actionName} n'est pas encore implémentée`, 'info');
    }

    // Method to handle inline editing in future enhancement
    handleInlineEdit(event) {
        event.stopPropagation();
        const { field, value, recordId } = event.detail;
        this.showToast('Info', `L'édition en ligne n'est pas encore implémentée : ${field}=${value}`, 'info');
    }

    // Handle settings menu actions
    handleSettingsAction(action) {
        switch (action) {
            case 'export':
                this.exportToCSV();
                break;
            case 'refresh':
                this.refreshWithFeedback();
                break;
            case 'reset':
                this.resetFilters();
                break;
            case 'toggleMyRecords':
                this.toggleMyRecords();
                break;
            default:
                break;
        }
    }

    // Enhanced formatter for number fields
    formatNumber(value, decimals = 2) {
        if (value === null || value === undefined) return '';
        return Number(value).toLocaleString('fr-FR', {
            minimumFractionDigits: decimals,
            maximumFractionDigits: decimals
        });
    }

    // Enhanced formatter for currency fields
    formatCurrency(value, currencyCode = 'EUR') {
        if (value === null || value === undefined) return '';
        return Number(value).toLocaleString('fr-FR', {
            style: 'currency',
            currency: currencyCode
        });
    }

    // Custom event handling for future child components
    handleCustomEvent(event) {
        const { action, data } = event.detail;
        console.log('Custom event received:', action, data);
    }

    // Future enhancement for column customization
    customizeColumns() {
        this.showToast('Info', 'La fonctionnalité de personnalisation des colonnes sera disponible dans une future mise à jour.', 'info');
    }

    // Computed properties for pagination
    get prevPageClass() {
        return this.currentPage <= 1 ? 'page-prev disabled' : 'page-prev';
    }

    get nextPageClass() {
        return this.currentPage >= this.totalPages ? 'page-next disabled' : 'page-next';
    }

    // Method to generate visible page numbers with their CSS classes
    get visiblePages() {
        if (!this.totalPages) return [];

        let pages = [];
        const totalPagesToShow = 5;

        if (this.totalPages <= totalPagesToShow) {
            for (let i = 1; i <= this.totalPages; i++) {
                pages.push({
                    number: i,
                    cssClass: i === this.currentPage ? 'page-item active' : 'page-item'
                });
            }
        } else {
            if (this.currentPage <= 3) {
                for (let i = 1; i <= 5; i++) {
                    pages.push({
                        number: i,
                        cssClass: i === this.currentPage ? 'page-item active' : 'page-item'
                    });
                }
            } else if (this.currentPage >= this.totalPages - 2) {
                for (let i = this.totalPages - 4; i <= this.totalPages; i++) {
                    pages.push({
                        number: i,
                        cssClass: i === this.currentPage ? 'page-item active' : 'page-item'
                    });
                }
            } else {
                for (let i = this.currentPage - 2; i <= this.currentPage + 2; i++) {
                    pages.push({
                        number: i,
                        cssClass: i === this.currentPage ? 'page-item active' : 'page-item'
                    });
                }
            }
        }

        return pages;
    }

    // Determine if we need to show the first page ellipsis
    get showFirstPageLink() {
        return this.totalPages > 6 && this.visiblePages.length > 0 && this.visiblePages[0].number > 1;
    }

    // Determine if we need to show the last page ellipsis
    get showLastPageLink() {
        return this.totalPages > 6 && this.visiblePages.length > 0 &&
            this.visiblePages[this.visiblePages.length - 1].number < this.totalPages;
    }
}