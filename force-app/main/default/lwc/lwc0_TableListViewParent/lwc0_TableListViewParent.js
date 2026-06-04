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

    @track sortedBy = '';
    @track sortedDirection = 'asc';

    @track pageSize = 50;
    @track currentPage = 1;
    @track totalRecords = 0;
    @track totalPages = 0;
    @track hasNextPage = false;
    @track hasPreviousPage = false;

    searchTimeout = null;

    @wire(getRecord, { recordId: userId, fields: [PROFILE_ID_FIELD, PROFILE_NAME_FIELD] })
    wireUser({ error, data }) {
        if (data) {
            this.currentUserProfileId = data.fields.ProfileId.value;
            this.currentUserProfileName = data.fields.Profile.displayValue;
        } else if (error) {
            console.error('Error loading user profile:', error);
        }
    }

    @track showExport = false;

    get disableSObjectSelection() { return this.isLoading; }
    get disableListViewSelection() { return this.isLoading || !this.selectedSObject; }
    get disableSearch() { return this.isLoading || (!this.data.length && !this.searchTerm); }
    get isFirstPage() { return this.currentPage <= 1; }
    get isLastPage() { return this.currentPage >= this.totalPages || this.totalPages === 0; }
    get showPagination() { return this.totalRecords > 0; }
    get viewingMyRecords() { return this.isMyRecordsView; }

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
            this.sObjectOptions = uniqueSObjects.map(sObject => ({ label: sObject, value: sObject }));
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
        if (data) {
            this.listViewOptions = data.map(view => {
                const isMyView = view.showOwnerFilter__c ||
                    (view.listViewName__c && view.listViewName__c.startsWith('Mes '));
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
            this.objectLogo = metadata.logo__c;
        } else {
            for (const [metaKey, metaValue] of this.metadataByListView.entries()) {
                if (metaKey.startsWith(sObjectName + '_') && metaValue.logo__c) {
                    this.objectLogo = metaValue.logo__c;
                    break;
                }
            }
            if (!this.objectLogo || this.objectLogo === 'standard:custom') {
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
        this.showExport = this.selectedSObject === 'Revision';
    }

    handleListViewChange(event) {
        this.selectedListView = event.detail.value;
        this.searchTerm = '';
        this.currentPage = 1;
        this.updateLogoFromMetadata(this.selectedSObject, this.selectedListView);
        this.loadRecords();
    }

    toggleMyRecords() {
        if (this.isMyRecordsView) {
            const regularView = this.listViewOptions.find(view => !view.isMyView);
            if (regularView) this.selectedListView = regularView.value;
        } else {
            const myView = this.listViewOptions.find(view => view.isMyView);
            this.selectedListView = myView ? myView.value : 'Mes ' + this.selectedSObject;
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
            getFieldsForListView({ sObjectName: this.selectedSObject, listViewName: this.selectedListView })
                .then(result => {
                    this.fieldsList = result.fields;
                    this.fieldsMetadata = result.metadata;
                    this.lookupFields = result.lookups || [];
                    this.lookupInfo = result.lookupInfo || {};
                    this.isMyRecordsView = result.isMyRecordsView || false;

                    this.columns = this.createModernColumns(this.fieldsList);

                    return getRecordsForListViewPaginated({
                        sObjectName: this.selectedSObject,
                        listViewName: this.selectedListView,
                        fields: this.fieldsList,
                        pageSize: this.pageSize,
                        pageNumber: this.currentPage
                    });
                })
                .then(result => {
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

    // ============================================================
    // GÉNÉRIQUE : résout le nom de relation d'un champ lookup
    //   'Victimes__c' → 'Victimes'
    //   'OwnerId'     → 'Owner'
    // Pour ajouter un nouveau lookup : rien à modifier ici.
    // ============================================================
    getLookupRelationshipName(lookupField) {
        if (lookupField.endsWith('__c')) return lookupField.slice(0, -3);
        if (lookupField.endsWith('Id'))  return lookupField.slice(0, -2);
        return lookupField;
    }

    // ============================================================
    // GÉNÉRIQUE : construit DisplayValue + LookupUrl
    // pour TOUS les champs lookup déclarés par l'Apex.
    // Fonctionne pour tout objet, tout champ, sans hardcoding.
    // Pour ajouter un nouveau lookup : rien à modifier ici.
    // ============================================================
    processAllLookupFields(record) {
        this.lookupFields.forEach(lookupField => {
            if (!record[lookupField]) return;

            const relationshipName = this.getLookupRelationshipName(lookupField);
            const relationshipObj =
                record[relationshipName + '__r'] ||
                record[relationshipName];

            const info = this.lookupInfo[lookupField] || {};
            const nameField = info.nameField || 'Name';

            record[relationshipName + 'DisplayValue'] =
                (relationshipObj && relationshipObj[nameField])
                    ? relationshipObj[nameField]
                    : null;

            record[relationshipName + 'LookupUrl'] = '/' + record[lookupField];
        });
    }

    // ============================================================
    // GÉNÉRIQUE : traitement des champs traversés 2 et 3 niveaux
    //
    // 2 NIVEAUX : Police__r.PolicyNumber__c
    //   → texte  : Police__rPolicyNumber__c
    //   → URL    : /Police__r.Id
    //
    // 3 NIVEAUX : Victimes__r.ParticipantAccount__r.Name
    //   → texte  : Victimes__rParticipantAccount__rName  (nom du compte)
    //   → URL    : /Victimes__r.Id  (fiche ClaimParticipant = niveau 1)
    //
    // Pour ajouter un nouveau champ traversé : ajouter uniquement
    // dans FieldsToShow__c du metadata — aucune modif JS nécessaire.
    // ============================================================
    processTraversedFields(record) {
        this.fieldsList.forEach(listField => {
            if (!listField.includes('.')) return;

            const parts = listField.split('.');

            // ── 2 NIVEAUX ─────────────────────────────────────────
            if (parts.length === 2) {
                const [rel1, field1] = parts;

                if (record[rel1] && typeof record[rel1] === 'object') {
                    const relObj     = record[rel1];
                    const flatKey    = rel1.replace('__r', '') + '__r' + field1;
                    const flatKeyUrl = flatKey.replace('__c', '') + 'Url';

                    record[flatKey]    = relObj[field1];
                    record[flatKeyUrl] = '/' + relObj.Id;

                    this.traversedClickableFields.add(listField);
                }
            }

            // ── 3 NIVEAUX ─────────────────────────────────────────
            // ex. Victimes__r.ParticipantAccount__r.Name
            //   texte affiché = valeur niveau 3 (nom du compte)
            //   URL           = fiche niveau 1 (ClaimParticipant)
            // ──────────────────────────────────────────────────────
            else if (parts.length === 3) {
                const [rel1, rel2, field2] = parts;

                if (record[rel1] && typeof record[rel1] === 'object') {
                    const relObj1 = record[rel1];

                    // Clé plate pour le texte affiché
                    const flatKey = rel1.replace('__r', '') + '__r'
                                  + rel2.replace('__r', '') + '__r'
                                  + field2;

                    // Valeur affichée = valeur au niveau 3
                    record[flatKey] = (relObj1[rel2] && relObj1[rel2][field2])
                        ? relObj1[rel2][field2]
                        : null;

                    // URL = vers la fiche du niveau 1
                    const flatKeyUrl = rel1.replace('__r', '') + '__r'
                                     + rel2.replace('__r', '') + '__rUrl';
                    record[flatKeyUrl] = relObj1.Id ? '/' + relObj1.Id : null;

                    this.traversedClickableFields.add(listField);
                }
            }
        });
    }

    processRecords(records) {
        if (!records || records.length === 0) return [];

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

            // URL de navigation pour l'enregistrement principal
            newRecord['DeclarationUrl'] = '/' + newRecord.Id;

            // ✅ GÉNÉRIQUE : tous les lookups simples
            this.processAllLookupFields(newRecord);

            // ✅ GÉNÉRIQUE : tous les champs traversés 2 et 3 niveaux
            this.processTraversedFields(newRecord);

            // Nettoyage Num_ro_d_immatriculation__c
            if (newRecord['Num_ro_d_immatriculation__c']) {
                let value = newRecord['Num_ro_d_immatriculation__c'];
                value = value.replace(/[\n\r]/g, ' ').trim();
                newRecord['Num_ro_d_immatriculation_CLEAN'] = value.split('/')[0].trim();
            }

            recordKeys.forEach(field => {
                const value = newRecord[field];
                const fieldMetadata = this.fieldsMetadata[field] || {};

                if (field === 'Id') return;

                const isFormula     = fieldMetadata.formula === true;
                const isHtmlFormula = isFormula && fieldMetadata.formulaType === 'HTML';
                const isTextFormula = isFormula && fieldMetadata.formulaType === 'TEXT';
                if (isHtmlFormula || isTextFormula) return;

                if (field === 'Name')       newRecord['NameUrl']       = '/' + newRecord.Id;
                if (field === 'CaseNumber') newRecord['CaseNumberUrl'] = '/' + newRecord.Id;

                if (field.includes('.')) {
                    this.processRelationshipField(newRecord, field, value);
                    return;
                }

                if (field.endsWith('Id') && field !== 'Id') {
                    const relationshipName  = field.substring(0, field.length - 2);
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
                    this.processRelationshipData(newRecord, relationshipName, newRecord[field],
                        newRecord[relationshipName + '__c'] || newRecord[relationshipName + 'Id']);
                    return;
                }

                this.formatDateField(newRecord, field);
            });

            return newRecord;
        });
    }

    processRelationshipData(record, relationshipName, relationshipObject, idValue) {
        if (!relationshipObject) return;
        record[relationshipName + 'DisplayValue'] = this.findBestDisplayField(relationshipObject) || 'View';
        record[relationshipName + 'LookupUrl']    = '/' + (relationshipObject.Id || idValue);
    }

    processIdOnlyField(record, relationshipName, idValue) {
        if (!idValue) return;
        record[relationshipName + 'DisplayValue'] = 'View ' + relationshipName;
        record[relationshipName + 'LookupUrl']    = '/' + idValue;
    }

    findBestDisplayField(obj) {
        if (!obj) return '';
        const candidates = ['Name', 'Title', 'Subject', 'CaseNumber', 'ClaimNumber',
            'ClaimNumber__c', 'Label', 'FullName', 'Username', 'RequestType__c'];
        for (const field of candidates) {
            if (obj[field] !== undefined && obj[field] !== null) return obj[field];
        }
        for (const key in obj) {
            if (key !== 'Id' && typeof obj[key] === 'string' && obj[key]) return obj[key];
        }
        return obj.Id ? String(obj.Id).substring(0, 8) : '';
    }

    processRelationshipField(record, field, value) {
        const parts = field.split('.');
        if (parts.length !== 2) return;
        record[parts[0].replace('__r', '') + '__r' + parts[1]] = value;
    }

    formatDateField(record, field) {
        const fieldMetadata = this.fieldsMetadata[field] || {};
        const value = record[field];
        if (value && this.isDateField(field, fieldMetadata.type)) {
            try {
                const d = new Date(value);
                if (!isNaN(d.getTime())) {
                    const day   = String(d.getDate()).padStart(2, '0');
                    const month = String(d.getMonth() + 1).padStart(2, '0');
                    record[field + 'Formatted'] = `${day}-${month}-${d.getFullYear()}`;
                }
            } catch (e) {
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

    // ============================================================
    // CRÉATION DES COLONNES
    //
    // Ordre de priorité :
    //  1.  RecordType.Name          → texte non cliquable
    //  SKIP si traversed existe pour ce lookup __c
    //  2.  Champ traversé 2 niveaux → URL niveau 1, texte niveau 2
    //  3.  Champ traversé 3 niveaux → URL niveau 1, texte niveau 3
    //  4.  TextArea
    //  5.  Email
    //  6.  String
    //  7.  Picklist
    //  8.  Multi-picklist
    //  9.  HTML Formula
    //  10. Text Formula
    //  11. Currency
    //  12. Number
    //  13. Date
    //  14. Boolean
    //  15. Name / CaseNumber        → URL enregistrement principal
    //  16. Lookup __c               → URL lookup (générique)
    //  17. Reference / Id standard  → URL lookup (générique)
    //  18. Texte par défaut
    // ============================================================
    createModernColumns(fieldList) {
        return fieldList
            .filter(field => field !== 'Id')
            .map(field => {
                const fieldMetadata    = this.fieldsMetadata[field] || {};
                const fieldType        = fieldMetadata.type;
                const isFormula        = fieldMetadata.formula === true;
                const formulaType      = fieldMetadata.formulaType;

                const isHtmlFormula    = isFormula && formulaType === 'HTML';
                const isTextFormula    = isFormula && formulaType === 'TEXT';
                const isCurrencyFormula = isFormula && formulaType === 'CURRENCY';
                const isNumberFormula  = isFormula && ['DOUBLE','NUMBER','DECIMAL','PERCENT'].includes(formulaType);

                const isPicklist       = fieldType === 'PICKLIST';
                const isMultiPicklist  = fieldType === 'MULTIPICKLIST';
                const isTextArea       = fieldType === 'TEXTAREA';
                const isRichText       = isTextArea && fieldMetadata.isRichText === true;
                const isCurrency       = fieldType === 'CURRENCY' || isCurrencyFormula;
                const isNumber         = ['DOUBLE','DECIMAL','NUMBER','PERCENT'].includes(fieldType) || isNumberFormula;
                const isReference      = fieldMetadata.isReference;
                const isExplicitLookup = this.lookupFields.includes(field);
                const isRelationshipField = field.includes('.');
                const isDateFieldCheck = this.isDateField(field, fieldType);
                const isBooleanField   = fieldType === 'BOOLEAN' || formulaType === 'BOOLEAN';
                const isEmailField     = fieldType === 'EMAIL';

                const isString = (fieldType === 'STRING' || fieldType === 'TEXT' || fieldType === 'ID') &&
                    !isReference && !isExplicitLookup && !isRelationshipField &&
                    !field.endsWith('Id') && !isNumberFormula && !isTextFormula &&
                    !isHtmlFormula && !isFormula &&
                    !field.endsWith('Name') && field !== 'Name' && field !== 'CaseNumber';

                const column = {
                    label: this.formatFieldLabel(field, fieldMetadata.label),
                    fieldName: field,
                    type: 'text',
                    isDate: false, isText: false, isString: false, isUrl: false,
                    isBoolean: false, isCurrency, isNumber, isHtmlFormula, isTextFormula,
                    isPicklist, isMultiPicklist, isTextArea, isRichText,
                    displayField: field,
                    isSorted: this.sortedBy === field,
                    sortIconName: this.sortedBy === field
                        ? (this.sortedDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown')
                        : 'utility:arrowup',
                    headerClass: this.getHeaderClass(fieldType, isFormula, formulaType),
                    cellClass: this.getCellClass(field, fieldType, isReference || isExplicitLookup, isFormula, formulaType)
                };

                // 1️⃣ RecordType → texte non cliquable
                if (field === 'RecordType.Name') {
                    column.isString = true;
                    return column;
                }

                // SKIP __c si un champ traversé existe pour ce lookup
                if (field.endsWith('__c') && !field.endsWith('Number__c') &&
                    !field.endsWith('Date__c') && !field.startsWith('Date')) {
                    const relCheck = field.substring(0, field.length - 3) + '__r';
                    if (this.fieldsList.some(f => f.startsWith(relCheck + '.'))) {
                        return null;
                    }
                }

                // 2️⃣ & 3️⃣ Champ traversé (avec point)
                if (field.includes('.')) {
                    const parts = field.split('.');

                    // ── 2 niveaux : Police__r.PolicyNumber__c
                    if (parts.length === 2) {
                        const [rel1, field1] = parts;
                        const flatKey    = rel1.replace('__r', '') + '__r' + field1;
                        const flatKeyUrl = flatKey.replace('__c', '') + 'Url';
                        column.fieldName    = flatKeyUrl;
                        column.isUrl        = true;
                        column.displayField = flatKey;
                    }

                    // ── 3 niveaux : Victimes__r.ParticipantAccount__r.Name
                    // fieldName    → URL vers fiche niveau 1 (ClaimParticipant)
                    // displayField → texte niveau 3 (nom du compte)
                    else if (parts.length === 3) {
                        const [rel1, rel2, field2] = parts;
                        const flatKey    = rel1.replace('__r', '') + '__r'
                                         + rel2.replace('__r', '') + '__r'
                                         + field2;
                        const flatKeyUrl = rel1.replace('__r', '') + '__r'
                                         + rel2.replace('__r', '') + '__rUrl';
                        column.fieldName    = flatKeyUrl;
                        column.isUrl        = true;
                        column.displayField = flatKey;
                    }

                    return column;
                }

                // 4️⃣ TextArea
                if (isTextArea)    { column.isTextArea = true;  return column; }

                // 5️⃣ Email
                if (isEmailField)  { column.isString = true;    return column; }

                // 6️⃣ String
                if (isString)      { column.isString = true;    return column; }

                // 7️⃣ Picklist
                if (isPicklist)    { column.isPicklist = true;   return column; }

                // 8️⃣ Multi-picklist
                if (isMultiPicklist) { column.isMultiPicklist = true; return column; }

                // 9️⃣ HTML Formula
                if (isHtmlFormula) { column.isHtmlFormula = true; return column; }

                // 🔟 Text Formula
                if (isTextFormula) { column.isTextFormula = true; return column; }

                // 1️⃣1️⃣ Currency
                if (isCurrency)    { column.isCurrency = true;  return column; }

                // 1️⃣2️⃣ Number
                if (isNumber)      { column.isNumber = true;    return column; }

                // 1️⃣3️⃣ Date
                if (isDateFieldCheck) {
                    column.isDate    = true;
                    column.fieldName = field + 'Formatted';
                    return column;
                }

                // 1️⃣4️⃣ Boolean
                if (isBooleanField) { column.isBoolean = true;  return column; }

                // 1️⃣5️⃣ Name / CaseNumber → lien vers l'enregistrement principal
                if (field === 'Name' || field.endsWith('Name') || field === 'CaseNumber') {
                    column.fieldName    = field + 'Url';
                    column.isUrl        = true;
                    column.displayField = field;
                    return column;
                }

                // 1️⃣6️⃣ Lookup __c générique
                if (field.endsWith('__c') && !field.endsWith('Number__c') &&
                    !field.endsWith('Date__c') && !field.startsWith('Date')) {
                    const rel = this.getLookupRelationshipName(field);
                    column.fieldName    = rel + 'LookupUrl';
                    column.isUrl        = true;
                    column.displayField = rel + 'DisplayValue';
                    return column;
                }

                // 1️⃣7️⃣ Reference / Id standard (OwnerId, etc.)
                if (isReference || field.endsWith('Id') || isExplicitLookup) {
                    const rel = this.getLookupRelationshipName(field);
                    column.fieldName    = rel + 'LookupUrl';
                    column.isUrl        = true;
                    column.displayField = rel + 'DisplayValue';
                    return column;
                }

                // 1️⃣8️⃣ Texte par défaut
                column.isText = true;
                return column;
            })
            .filter(col => col !== null);
    }

    getHeaderClass(fieldType, isFormula, formulaType) {
        let classes = '';
        const numTypes = ['CURRENCY','DOUBLE','NUMBER','DECIMAL','PERCENT'];
        if (isFormula) {
            if (numTypes.includes(formulaType)) classes += 'cell-right ';
            else if (formulaType === 'BOOLEAN') classes += 'cell-center ';
        } else {
            if (numTypes.includes(fieldType)) classes += 'cell-right ';
            else if (fieldType === 'BOOLEAN') classes += 'cell-center ';
        }
        return classes.trim();
    }

    getCellClass(field, fieldType, isLookup, isFormula, formulaType) {
        let classes = '';
        const numTypes = ['CURRENCY','DOUBLE','NUMBER','DECIMAL','PERCENT'];
        if (isLookup || field === 'Name' || field.endsWith('Name')) classes += 'cell-link ';
        if (isFormula) {
            if (numTypes.includes(formulaType)) classes += 'cell-right ';
            else if (formulaType === 'BOOLEAN') classes += 'cell-center ';
        } else {
            if (numTypes.includes(fieldType)) classes += 'cell-right ';
            else if (fieldType === 'BOOLEAN') classes += 'cell-center ';
        }
        return classes.trim();
    }

    formatFieldLabel(fieldName, metadataLabel) {
        if (metadataLabel) return metadataLabel;
        if (fieldName.includes('.')) {
            return this.formatFieldLabel(fieldName.split('.').pop(), null);
        }
        const key = `${this.selectedSObject}_${this.selectedListView}`;
        const metadata = this.metadataByListView.get(key);
        if (metadata && metadata.labelOfFields__c) {
            for (const mapping of metadata.labelOfFields__c.split(';')) {
                const [f, l] = mapping.split(':');
                if (f && f.trim() === fieldName) return l.trim();
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
        if (this.searchTimeout) clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => this.performBackendSearch(), 500);
    }

    performBackendSearch() {
        if (!this.selectedSObject || !this.selectedListView) return;
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
                if (recordsWithFormattedData.length > 0) {
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
        if (fieldName.endsWith('LookupUrl')) {
            sortField = fieldName.replace('LookupUrl', '') + 'DisplayValue';
            isLookupField = true;
        } else if (fieldName.endsWith('Url')) {
            sortField = fieldName.replace('Url', '');
        } else if (fieldName.endsWith('Formatted')) {
            sortField = fieldName.replace('Formatted', '');
        } else if (fieldName.endsWith('DisplayValue')) {
            sortField = fieldName;
            isLookupField = true;
        }

        const cloneData = [...this.paginatedData];
        cloneData.sort((a, b) => {
            const valueA = isLookupField ? a[sortField] : this.getSortValue(a[sortField]);
            const valueB = isLookupField ? b[sortField] : this.getSortValue(b[sortField]);
            return this.compareValues(valueA, valueB, this.sortedDirection);
        });
        this.paginatedData = cloneData;

        this.columns = this.columns.map(col => ({
            ...col,
            isSorted: col.fieldName === fieldName,
            sortIconName: col.fieldName === fieldName
                ? (this.sortedDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown')
                : 'utility:arrowup'
        }));
        this.isLoading = false;
    }

    getSortValue(value) {
        if (value === null || value === undefined) return null;
        if (typeof value === 'object') {
            const candidates = ['Name','CaseNumber','ClaimNumber','ClaimNumber__c',
                'RequestType__c','Title','Subject','FullName','Username'];
            for (const f of candidates) {
                if (value[f] !== undefined && value[f] !== null) return value[f];
            }
            for (const key in value) {
                if (key !== 'Id' && typeof value[key] === 'string' && value[key]) return value[key];
            }
            return value.Id || '';
        }
        if (value instanceof Date) return value.getTime();
        if (typeof value === 'string' && (value.includes('-') || value.includes('/'))) {
            const d = new Date(value);
            if (!isNaN(d.getTime())) return d.getTime();
        }
        return value;
    }

    compareValues(a, b, sortDirection) {
        if (a === null || a === undefined) return sortDirection === 'asc' ? 1 : -1;
        if (b === null || b === undefined) return sortDirection === 'asc' ? -1 : 1;
        if (typeof a === 'string' && typeof b === 'string') {
            const cmp = a.toLowerCase().localeCompare(b.toLowerCase());
            return sortDirection === 'asc' ? cmp : -cmp;
        }
        if (a > b) return sortDirection === 'asc' ? 1 : -1;
        if (a < b) return sortDirection === 'asc' ? -1 : 1;
        return 0;
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.target.value, 10);
        this.currentPage = 1;
        this.searchTerm && this.searchTerm.trim().length > 0
            ? this.performBackendSearch() : this.loadRecords();
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.searchTerm && this.searchTerm.trim().length > 0
                ? this.performBackendSearch() : this.loadRecords();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.searchTerm && this.searchTerm.trim().length > 0
                ? this.performBackendSearch() : this.loadRecords();
        }
    }

    handlePageClick(event) {
        const selectedPage = parseInt(event.currentTarget.dataset.page, 10);
        if (selectedPage !== this.currentPage) {
            this.currentPage = selectedPage;
            this.searchTerm && this.searchTerm.trim().length > 0
                ? this.performBackendSearch() : this.loadRecords();
        }
    }

    applyClientSideFilter() {
        if (!this.searchTerm) {
            this.filteredData = this.data;
            this.paginatedData = this.data;
            return;
        }
        this.filteredData = this.data.filter(row =>
            Object.values(row).some(value => {
                if (value === null || value === undefined) return false;
                if (typeof value === 'object') {
                    return Object.values(value).some(v => v && String(v).toLowerCase().includes(this.searchTerm));
                }
                return String(value).toLowerCase().includes(this.searchTerm);
            })
        );
        this.paginatedData = this.filteredData;
    }

    handleRowClick(event) {
        const recordId = event.currentTarget.dataset.id;
        if (recordId) this.navigateToRecordPage(recordId);
    }

    handleCellLinkClick(event) {
        event.stopPropagation();
        const { recordId } = event.detail;
        if (recordId) {
            this.navigateToRecordPage(recordId);
        } else {
            console.error('No record ID provided in the click event');
        }
    }

    navigateToRecordPage(recordId) {
        if (!recordId) return;
        try {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId, actionName: 'view' }
            });
        } catch (error) {
            window.location.href = '/' + recordId;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title, message, variant,
            mode: variant === 'error' ? 'sticky' : 'dismissable'
        }));
    }

    exportToCSV() {
        if (!this.data || this.data.length === 0) {
            this.showToast('Info', 'Aucune donnée à exporter', 'info');
            return;
        }
        this.isLoading = true;
        try {
            const headers = this.columns.map(col => col.label);
            const fields  = this.columns.map(col => {
                if (col.isUrl) return col.displayField;
                if (col.fieldName.endsWith('Formatted')) return col.fieldName.replace('Formatted', '');
                return col.fieldName;
            });
            let csvContent = headers.join(',') + '\n';
            this.data.forEach(row => {
                const rowData = fields.map(field => {
                    let value = this.getFieldValue(row, field);
                    if (value === null || value === undefined) return '';
                    value = String(value).replace(/"/g, '""');
                    if (value.includes(',') || value.includes('\n') || value.includes('"')) {
                        value = `"${value}"`;
                    }
                    return value;
                });
                csvContent += rowData.join(',') + '\n';
            });
            const link = document.createElement('a');
            link.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent);
            link.download = `${this.selectedSObject}_${this.selectedListView}.csv`;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            this.showToast('Success', 'Fichier exporté avec succès', 'success');
        } catch (error) {
            this.showToast('Error', 'Échec de l\'exportation : ' + error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    getFieldValue(obj, path) {
        if (!obj || !path) return null;
        if (path.includes('.')) {
            return path.split('.').reduce((prev, curr) => prev ? prev[curr] : null, obj);
        }
        return obj[path];
    }

    refreshWithFeedback() {
        if (!this.isLoading && this.selectedSObject && this.selectedListView) {
            this.isLoading = true;
            setTimeout(() => {
                this.loadRecords()
                    .then(() => this.showToast('Success', 'Données actualisées avec succès', 'success'))
                    .catch(error => console.error('Error refreshing:', error));
            }, 300);
        }
    }

    refreshData() {
        if (!this.isLoading && this.selectedSObject && this.selectedListView) this.loadRecords();
    }

    handleRowSelection(event) { /* réservé */ }

    resetFilters() {
        this.searchTerm = '';
        this.currentPage = 1;
        this.loadRecords();
    }

    handleKeyDown(event) {
        if (event.key === 'Enter' && event.target.classList.contains('data-row')) {
            const recordId = event.target.dataset.id;
            if (recordId) this.navigateToRecordPage(recordId);
        }
    }

    performBulkAction(actionName) {
        this.showToast('Info', `L'action groupée ${actionName} n'est pas encore implémentée`, 'info');
    }

    handleInlineEdit(event) {
        event.stopPropagation();
        const { field, value } = event.detail;
        this.showToast('Info', `L'édition en ligne n'est pas encore implémentée : ${field}=${value}`, 'info');
    }

    handleSettingsAction(action) {
        const actions = {
            export: () => this.exportToCSV(),
            refresh: () => this.refreshWithFeedback(),
            reset: () => this.resetFilters(),
            toggleMyRecords: () => this.toggleMyRecords()
        };
        if (actions[action]) actions[action]();
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
        return Number(value).toLocaleString('fr-FR', { style: 'currency', currency: currencyCode });
    }

    handleCustomEvent(event) {
        console.log('Custom event received:', event.detail.action, event.detail.data);
    }

    customizeColumns() {
        this.showToast('Info', 'La personnalisation des colonnes sera disponible dans une future mise à jour.', 'info');
    }

    get prevPageClass() { return this.currentPage <= 1 ? 'page-prev disabled' : 'page-prev'; }
    get nextPageClass() { return this.currentPage >= this.totalPages ? 'page-next disabled' : 'page-next'; }

    get visiblePages() {
        if (!this.totalPages) return [];
        const total = this.totalPages;
        const cur   = this.currentPage;
        let start, end;

        if (total <= 5)           { start = 1;         end = total;   }
        else if (cur <= 3)        { start = 1;         end = 5;       }
        else if (cur >= total-2)  { start = total - 4; end = total;   }
        else                      { start = cur - 2;   end = cur + 2; }

        const pages = [];
        for (let i = start; i <= end; i++) {
            pages.push({ number: i, cssClass: i === cur ? 'page-item active' : 'page-item' });
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