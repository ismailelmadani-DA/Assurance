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
    @track traversedClickableFields = new Set();

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

    get paginationInfo() {
        if (this.totalRecords === 0) return 'Aucun enregistrement';
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(this.currentPage * this.pageSize, this.totalRecords);
        return `${start} - ${end} sur ${this.totalRecords}`;
    }

    get pageSizeOptions() {
        return [
            { label: '10', value: 10 },
            { label: '25', value: 25 },
            { label: '50', value: 50 },
            { label: '100', value: 100 },
            { label: '200', value: 200 }
        ];
    }

    @wire(getAvailableSObjects)
    wiredSObjects({ data, error }) {
        this.isLoading = true;
        if (data) {
            const uniqueSObjects = [...new Set(data.map(item => item.sobjectName__c))];
            this.sObjectOptions = uniqueSObjects.map(sObject => ({
                label: sObject,
                value: sObject
            }));

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
            }
        } else if (error) {
            console.error('Error loading list views:', error);
            this.showToast('Error', 'Échec du chargement des vues de liste : ' + (error.body?.message || error.message), 'error');
            this.isLoading = false;
        }
    }

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

    handleListViewChange(event) {
        console.log('Selected list view changed to: ' + event.detail.value);
        this.selectedListView = event.detail.value;
        this.searchTerm = '';
        this.currentPage = 1;
        
        this.updateLogoFromMetadata(this.selectedSObject, this.selectedListView);
        
        this.loadRecords();
    }

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

    loadRecords() {
        if (!this.selectedSObject || !this.selectedListView) {
            return Promise.reject(new Error('No SObject or ListView selected'));
        }

        this.isLoading = true;

        return new Promise((resolve, reject) => {
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

                    // ✅ CREATE COLUMNS - THIS IS CRITICAL
                    this.columns = this.createModernColumns(this.fieldsList);
                    console.log('Columns created:', JSON.stringify(this.columns.map(c => ({fieldName: c.fieldName, isUrl: c.isUrl, label: c.label}))));

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

                    const recordsWithFormattedData = this.processRecords(result.records);

                    this.data = recordsWithFormattedData;
                    this.filteredData = recordsWithFormattedData;
                    this.paginatedData = recordsWithFormattedData;

                    this.totalRecords = result.totalRecords;
                    this.totalPages = result.totalPages;
                    this.currentPage = result.currentPage;
                    this.hasNextPage = result.hasNextPage;
                    this.hasPreviousPage = result.hasPreviousPage;

                    this.isLoading = false;

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

    processRecords(records) {
        if (!records || records.length === 0) return [];

        console.log('Sample record structure:', JSON.stringify(records[0]));

        this.traversedClickableFields = new Set();

        return records.map(record => {
            const newRecord = { ...record };
            const recordKeys = Object.keys(newRecord);

            const relationshipFields = new Set();
            recordKeys.forEach(key => {
                if (newRecord[key] && typeof newRecord[key] === 'object' && newRecord[key].Id) {
                    relationshipFields.add(key);
                }
            });

            console.log('Detected relationship fields:', Array.from(relationshipFields));

            // ✅ CREATE URL FOR ALL CLICKABLE FIELDS
            newRecord['DeclarationUrl'] = '/' + newRecord.Id;

            // ✅ CLEAN UP Num_ro_d_immatriculation__c - Remove ID part after / and line breaks
            if (newRecord['Num_ro_d_immatriculation__c']) {
                let value = newRecord['Num_ro_d_immatriculation__c'];
                // Remove line breaks first
                value = value.replace(/[\n\r]/g, ' ').trim();
                // Then split by / and take only the first part
                const cleanValue = value.split('/')[0].trim();
                // CREATE A NEW CLEAN FIELD for display
                newRecord['Num_ro_d_immatriculation_CLEAN'] = cleanValue;
                console.log('✅ Created clean field - Num_ro_d_immatriculation_CLEAN:', cleanValue);
            }

            // ✅ HANDLE TRAVERSED FIELDS (Police__r.PolicyNumber__c)
            console.log('--- PROCESSING TRAVERSED FIELDS ---');
            this.fieldsList.forEach(listField => {
                if (listField.includes('.')) {
                    console.log(`Processing traversed field: ${listField}`);
                    
                    const parts = listField.split('.');
                    const relationshipName = parts[0];
                    const targetField = parts[1];
                    
                    if (newRecord[relationshipName] && typeof newRecord[relationshipName] === 'object') {
                        const relObj = newRecord[relationshipName];
                        const value = relObj[targetField];
                        const flatKey = relationshipName.replace('__r', '') + '__r' + targetField;
                        newRecord[flatKey] = value;
                        
                        // ✅ CREATE URL FOR TRAVERSED FIELD
                        const flatKeyUrl = flatKey.replace('__c', '') + 'Url';
                        newRecord[flatKeyUrl] = '/' + relObj.Id;
                        
                        this.traversedClickableFields.add(listField);
                        
                        console.log(`  ✅ Created: ${flatKey} = ${value}`);
                        console.log(`  ✅ Created URL: ${flatKeyUrl} = ${newRecord[flatKeyUrl]}`);
                    } else {
                        console.log(`  ❌ Relationship object NOT found: ${relationshipName}`);
                    }
                }
            });
            console.log('--- END TRAVERSED FIELDS ---\n');

            recordKeys.forEach(field => {
                const value = newRecord[field];
                const fieldMetadata = this.fieldsMetadata[field] || {};
                const fieldType = fieldMetadata.type;

                if (field === 'Id') {
                    return;
                }

                const isFormula = fieldMetadata.formula === true;
                const isHtmlFormula = isFormula && fieldMetadata.formulaType === 'HTML';
                const isTextFormula = isFormula && fieldMetadata.formulaType === 'TEXT';

                if (isHtmlFormula || isTextFormula) {
                    return;
                }

                if (field === 'Name') {
                    newRecord[field + 'Url'] = '/' + newRecord.Id;
                }
                if (field === 'CaseNumber') {
                    newRecord[field + 'Url'] = '/' + newRecord.Id;
                }

                if (field.includes('.')) {
                    this.processRelationshipField(newRecord, field, value);
                    return;
                }

                if (field.endsWith('Id') && field !== 'Id') {
                    const relationshipName = field.substring(0, field.length - 2);
                    const relationshipField = relationshipName + '__r';

                    if (newRecord[relationshipField] && newRecord[relationshipField].Id) {
                        this.processRelationshipData(newRecord, relationshipName, newRecord[relationshipField], value);
                    } else {
                        this.processIdOnlyField(newRecord, relationshipName, value);
                    }

                    if (field === 'OwnerId' && value === this.currentUserId) {
                        newRecord.isOwnedByCurrentUser = true;
                    }

                    return;
                }

                if (field.endsWith('__c')) {
                    const possibleRelationField = field.replace('__c', '__r');
                    if (relationshipFields.has(possibleRelationField)) {
                        const relationshipName = field.substring(0, field.length - 3);
                        this.processRelationshipData(newRecord, relationshipName, newRecord[possibleRelationField], value);
                        return;
                    }
                }

                if (relationshipFields.has(field)) {
                    const relationshipName = field.endsWith('__r')
                        ? field.substring(0, field.length - 3)
                        : field;

                    this.processRelationshipData(newRecord, relationshipName, newRecord[field], newRecord[relationshipName + '__c'] || newRecord[relationshipName + 'Id']);
                    return;
                }

                this.formatDateField(newRecord, field);
            });

            console.log('Processed record:', JSON.stringify(newRecord));
            return newRecord;
        });
    }

    processRelationshipData(record, relationshipName, relationshipObject, idValue) {
        if (!relationshipObject) return;

        let displayValue = this.findBestDisplayField(relationshipObject);

        record[relationshipName + 'DisplayValue'] = displayValue || 'View';
        record[relationshipName + 'LookupUrl'] = '/' + (relationshipObject.Id || idValue);
    }

    processIdOnlyField(record, relationshipName, idValue) {
        if (!idValue) return;

        record[relationshipName + 'DisplayValue'] = 'View ' + relationshipName;
        record[relationshipName + 'LookupUrl'] = '/' + idValue;
    }

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

    processRelationshipField(record, field, value) {
        const parts = field.split('.');
        if (parts.length !== 2) return;

        const relationshipName = parts[0];
        const fieldName = parts[1];

        const flatKey = parts[0].replace('__r', '') + '__r' + parts[1];
        record[flatKey] = value;
    }

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
            } catch (error) {
                console.error('Error formatting date:', error);
                record[field + 'Formatted'] = value;
            }
        }
    }

    isDateField(field, fieldType) {
        return fieldType === 'DATE' || fieldType === 'DATETIME' ||
            field.toLowerCase().includes('date') ||
            field === 'CreatedDate' || field === 'LastModifiedDate' ||
            field === 'EffectiveDate' || field === 'ExpirationDate';
    }

    // ✅ MAIN COLUMN CREATION - CRITICAL LOGIC
    createModernColumns(fieldList) {
        console.log('=== CREATING COLUMNS ===');
        console.log('fieldList:', fieldList);

        return fieldList
            .filter(field => field !== 'Id')
            .map(field => {
                const fieldMetadata = this.fieldsMetadata[field] || {};
                const fieldType = fieldMetadata.type;
                
                // ✅ DEBUG LOG FOR EMAIL AND RECORDTYPE
                if (field === 'Email__c' || field === 'RecordType.Name') {
                    console.log(`\n⚠️ DEBUG ${field}:`, {
                        fieldType: fieldType,
                        fieldMetadata: JSON.stringify(fieldMetadata),
                        hasMetadata: !!fieldMetadata
                    });
                }
                
                console.log(`\n>>> Processing field: ${field} (type: ${fieldType})`);

                const isFormula = fieldMetadata.formula === true;
                const formulaType = fieldMetadata.formulaType;

                const isHtmlFormula = isFormula && formulaType === 'HTML';
                const isTextFormula = isFormula && formulaType === 'TEXT';
                const isCurrencyFormula = isFormula && (formulaType === 'CURRENCY');
                const isNumberFormula = isFormula && (formulaType === 'DOUBLE' || formulaType === 'NUMBER' || formulaType === 'DECIMAL' || formulaType === 'PERCENT');

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
                const isEmailField = fieldType === 'EMAIL';

                const isString = (fieldType === 'STRING' || fieldType === 'TEXT' || fieldType === 'ID') &&
                    !isReference && !isExplicitLookup && !isRelationshipField &&
                    !field.endsWith('Id') && !isNumberFormula && !isTextFormula && !isHtmlFormula && !isFormula &&
                    !field.endsWith('Name') && field !== 'Name' && field !== 'CaseNumber';

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

                // ✅ RECORD TYPE SPECIAL CASE - NOT CLICKABLE
                if (field === 'RecordType.Name') {
                    column.isString = true;
                    console.log(`  >> RECORD TYPE (not clickable)`);
                    return column;
                }

                // ✅ SKIP lookups with traversed fields
                if (field.endsWith('__c') && !field.endsWith('Number__c') && !field.endsWith('Date__c') && !field.startsWith('Date')) {
                    const relationshipNameForCheck = field.substring(0, field.length - 3) + '__r';
                    const hasTraversedField = this.fieldsList.some(f => f.startsWith(relationshipNameForCheck + '.'));
                    if (hasTraversedField) {
                        console.log(`  ✅ SKIP: ${field} has traversed field`);
                        return null;
                    }
                }

                // ✅ ORDER MATTERS - CHECK SPECIFIC FIELDS FIRST

                // ✅ TRAVERSED CLICKABLE LOOKUP (ANY field with dot notation - Police, Véhicule, etc)
                if (field.includes('.')) {
                    const flatKey = field.replace('.', '');
                    const flatKeyUrl = flatKey.replace('__c', '') + 'Url';
                    column.fieldName = flatKeyUrl;
                    column.isUrl = true;
                    column.displayField = flatKey;
                    console.log(`  ✅ CLICKABLE TRAVERSED: field=${field}, fieldName=${flatKeyUrl}, displayField=${flatKey}`);
                    return column;
                }

                // 3️⃣ TEXT AREA
                if (isTextArea) {
                    column.isTextArea = true;
                    console.log(`  >> TEXTAREA`);
                    return column;
                }

                // 4️⃣ EMAIL FIELD ✅ FIXED
                if (isEmailField) {
                    column.isString = true;
                    console.log(`  >> EMAIL`);
                    return column;
                }

                // 5️⃣ STRING
                if (isString) {
                    column.isString = true;
                    console.log(`  >> STRING`);
                    return column;
                }

                // 6️⃣ PICKLIST
                if (isPicklist) {
                    column.isPicklist = true;
                    console.log(`  >> PICKLIST`);
                    return column;
                }

                // 7️⃣ MULTI-PICKLIST
                if (isMultiPicklist) {
                    column.isMultiPicklist = true;
                    console.log(`  >> MULTI-PICKLIST`);
                    return column;
                }

                // 8️⃣ HTML FORMULA
                if (isHtmlFormula) {
                    column.isHtmlFormula = true;
                    console.log(`  >> HTML FORMULA`);
                    return column;
                }

                // 9️⃣ TEXT FORMULA
                if (isTextFormula) {
                    column.isTextFormula = true;
                    console.log(`  >> TEXT FORMULA`);
                    return column;
                }

                // 🔟 CURRENCY
                if (isCurrency) {
                    column.isCurrency = true;
                    console.log(`  >> CURRENCY`);
                    return column;
                }

                // 1️⃣1️⃣ NUMBER
                if (isNumber) {
                    column.isNumber = true;
                    console.log(`  >> NUMBER`);
                    return column;
                }

                // 1️⃣2️⃣ DATE
                if (isDateFieldCheck) {
                    column.isDate = true;
                    column.fieldName = field + 'Formatted';
                    console.log(`  >> DATE`);
                    return column;
                }

                // 1️⃣3️⃣ BOOLEAN
                if (isBooleanField) {
                    column.isBoolean = true;
                    console.log(`  >> BOOLEAN`);
                    return column;
                }

                // 1️⃣4️⃣ CASE NUMBER / NAME (standard clickable)
                if (field === 'Name' || field.endsWith('Name') || field === 'CaseNumber') {
                    column.fieldName = field + 'Url';
                    column.isUrl = true;
                    column.displayField = field;
                    console.log(`  ✅ CLICKABLE NAME/CASE: fieldName=${field}Url`);
                    return column;
                }

                // 1️⃣5️⃣ REGULAR LOOKUPS
                if (field.endsWith('__c') && !field.endsWith('Number__c') && !field.endsWith('Date__c') && !field.startsWith('Date')) {
                    const relationshipName = field.substring(0, field.length - 3);
                    column.fieldName = relationshipName + 'LookupUrl';
                    column.isUrl = true;
                    column.displayField = relationshipName + 'DisplayValue';
                    console.log(`  ✅ CLICKABLE LOOKUP: fieldName=${relationshipName}LookupUrl`);
                    return column;
                }

                // 1️⃣6️⃣ REFERENCE/LOOKUP FIELDS
                if (isReference || field.endsWith('Id') || isExplicitLookup) {
                    const relationshipName = field.endsWith('Id') ? field.substring(0, field.length - 2) : field;
                    column.fieldName = relationshipName + 'LookupUrl';
                    column.isUrl = true;
                    column.displayField = relationshipName + 'DisplayValue';
                    console.log(`  ✅ CLICKABLE REFERENCE: fieldName=${relationshipName}LookupUrl`);
                    return column;
                }

                // 1️⃣7️⃣ DEFAULT TEXT
                column.isText = true;
                console.log(`  >> TEXT (default)`);
                return column;
            })
            .filter(col => col !== null);
    }

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

    handleSearchChange(event) {
        this.searchTerm = event.detail.value.toLowerCase();
        this.currentPage = 1;
        
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }
        
        this.searchTimeout = setTimeout(() => {
            this.performBackendSearch();
        }, 500);
    }

    performBackendSearch() {
        if (!this.selectedSObject || !this.selectedListView) {
            return;
        }
        
        this.isLoading = true;
        
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
                
                const recordsWithFormattedData = this.processRecords(result.records);
                
                this.data = recordsWithFormattedData;
                this.filteredData = recordsWithFormattedData;
                this.paginatedData = recordsWithFormattedData;
                
                this.totalRecords = result.totalRecords;
                this.totalPages = result.totalPages;
                this.currentPage = result.currentPage;
                this.hasNextPage = result.hasNextPage;
                this.hasPreviousPage = result.hasPreviousPage;
                
                this.isLoading = false;
                
                if (recordsWithFormattedData.length === 0) {
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
            this.loadRecords();
        }
    }

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

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.target.value, 10);
        this.currentPage = 1;
        
        if (this.searchTerm && this.searchTerm.trim().length > 0) {
            this.performBackendSearch();
        } else {
            this.loadRecords();
        }
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage = this.currentPage - 1;
            
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
            
            if (this.searchTerm && this.searchTerm.trim().length > 0) {
                this.performBackendSearch();
            } else {
                this.loadRecords();
            }
        }
    }

    loadRecordsWithSearch() {
        if (!this.searchTerm || this.searchTerm.trim().length === 0) {
            this.loadRecords();
        } else {
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

    handleRowClick(event) {
        const recordId = event.currentTarget.dataset.id;
        if (recordId) {
            console.log('Row clicked, navigating to:', recordId);
            this.navigateToRecordPage(recordId);
        }
    }

    handleCellLinkClick(event) {
        event.stopPropagation();
        const { recordId } = event.detail;
        if (recordId) {
            console.log('Navigating to record:', recordId);
            this.navigateToRecordPage(recordId);
        } else {
            console.error('No record ID provided in the click event');
        }
    }

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

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: variant === 'error' ? 'sticky' : 'dismissable'
        });
        this.dispatchEvent(event);
    }

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

    refreshData() {
        if (!this.isLoading && this.selectedSObject && this.selectedListView) {
            this.loadRecords();
        }
    }

    handleRowSelection(event) {
        const selectedRow = event.currentTarget.dataset.id;
    }

    toggleAdvancedFilters() {
        const filtersPanel = this.template.querySelector('.advanced-filters');
        if (filtersPanel) {
            filtersPanel.classList.toggle('filters-expanded');
        }
    }

    resetFilters() {
        this.searchTerm = '';
        this.currentPage = 1;
        this.loadRecords();
    }

    handleKeyDown(event) {
        if (event.key === 'Enter' && event.target.classList.contains('data-row')) {
            const recordId = event.target.dataset.id;
            if (recordId) {
                this.navigateToRecordPage(recordId);
            }
        }
    }

    performBulkAction(actionName) {
        this.showToast('Info', `L'action groupée ${actionName} n'est pas encore implémentée`, 'info');
    }

    handleInlineEdit(event) {
        event.stopPropagation();
        const { field, value, recordId } = event.detail;
        this.showToast('Info', `L'édition en ligne n'est pas encore implémentée : ${field}=${value}`, 'info');
    }

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

    formatNumber(value, decimals = 2) {
        if (value === null || value === undefined) return '';
        return Number(value).toLocaleString('fr-FR', {
            minimumFractionDigits: decimals,
            maximumFractionDigits: decimals
        });
    }

    formatCurrency(value, currencyCode = 'EUR') {
        if (value === null || value === undefined) return '';
        return Number(value).toLocaleString('fr-FR', {
            style: 'currency',
            currency: currencyCode
        });
    }

    handleCustomEvent(event) {
        const { action, data } = event.detail;
        console.log('Custom event received:', action, data);
    }

    customizeColumns() {
        this.showToast('Info', 'La fonctionnalité de personnalisation des colonnes sera disponible dans une future mise à jour.', 'info');
    }

    get prevPageClass() {
        return this.currentPage <= 1 ? 'page-prev disabled' : 'page-prev';
    }

    get nextPageClass() {
        return this.currentPage >= this.totalPages ? 'page-next disabled' : 'page-next';
    }

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

    get showFirstPageLink() {
        return this.totalPages > 6 && this.visiblePages.length > 0 && this.visiblePages[0].number > 1;
    }

    get showLastPageLink() {
        return this.totalPages > 6 && this.visiblePages.length > 0 &&
            this.visiblePages[this.visiblePages.length - 1].number < this.totalPages;
    }
}