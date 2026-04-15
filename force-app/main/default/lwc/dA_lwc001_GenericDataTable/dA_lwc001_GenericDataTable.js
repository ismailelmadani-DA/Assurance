import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import getRecords from '@salesforce/apex/DA_GenericDataTableController.getRecords';
import getFieldsMetadata from '@salesforce/apex/DA_GenericDataTableController.getFieldsMetadata';
import getPicklistLabelsForField from '@salesforce/apex/DA_GenericDataTableController.getPicklistLabelsForField';

/**
 * @component DA_lwc001_GenericDataTable
 * @description Table de données générique et paramétrable depuis le Lightning App Builder.
 *
 * Propriétés configurables (target properties dans .js-meta.xml) :
 *  - objectApiName        : API Name de l'objet (ex: Case, InsurancePolicy__c)
 *  - fieldsApiNames       : Champs séparés par virgule (ex: CaseNumber,Status,Account.Name)
 *  - columnLabels         : Labels des colonnes séparés par virgule (même ordre que fieldsApiNames)
 *  - cardTitle            : Titre affiché dans le header de la card
 *  - filterField          : Champ de lookup/filtre (ex: Claim__c, AccountId) — vide = pas de filtre
 *  - recordTypeDeveloperName : Filtrer par RecordType.DeveloperName — vide = tous
 *  - orderByField         : Champ de tri initial (ex: CreatedDate)
 *  - orderDirection       : ASC ou DESC
 *  - pageSize             : Nombre de lignes par page
 *  - limitSize            : Nombre max d'enregistrements à charger (SOQL LIMIT)
 *  - clickableField       : Champ dont la valeur sera cliquable (navigue vers le record — ex: Id, CaseNumber)
 *  - statusField          : Champ utilisé pour colorer les lignes / badges de statut
 *  - showRecordCount      : Afficher le compteur dans le titre
 */
export default class DA_lwc001_GenericDataTable extends NavigationMixin(LightningElement) {

    // ─── Design-time properties (configurées dans le builder) ─────────────────
    @api recordId;
    @api objectApiName = '';
    @api targetObjectApiName = ''
    @api fieldsApiNames = '';          // ex: "CaseNumber,Status,Account.Name,CreatedDate"
    @api columnLabels = '';            // ex: "Numéro,Statut,Compte,Date création"
    @api cardTitle = 'Enregistrements';
    @api filterField = '';             // ex: "Claim__c"
    @api recordTypeDeveloperName = ''; // ex: "request"
    @api orderByField = 'CreatedDate';
    @api orderDirection = 'DESC';
    @api pageSize = 10;
    @api limitSize = 200;
    @api clickableField = '';          // ex: "CaseNumber" ou "Id" (rend la cellule cliquable)
    @api statusField = '';             // ex: "Status" — pour les badges colorés
    @api showRecordCount = false;

    // ─── Runtime state ────────────────────────────────────────────────────────
    @track _records = [];              // tous les enregistrements transformés
    @track _pageData = [];             // données de la page courante
    @track columns = [];               // colonnes construites dynamiquement
    @track currentPage = 1;
    @track totalRecords = 0;
    @track totalPages = 0;
    @track isLoading = false;
    @track isRefreshing = false;
    @track errorMessage = null;

    _sortBy = '';
    _sortDirection = 'desc';
    _picklistLabels = {};              // { fieldApiName: { value: label } }
    _fieldsMeta = [];                  // métadonnées des champs
    _configReady = false;
    _wheelBlocked = false;

    // ─── Getters ──────────────────────────────────────────────────────────────
    get hasData() { return !this.isLoading && !this.errorMessage && this._pageData.length > 0; }
    get isEmpty() { return !this.isLoading && !this.errorMessage && this._pageData.length === 0 && this._configReady; }
    get showPagination() { return this.hasData && this.totalPages > 1; }
    get headerTitle() { return this.showRecordCount ? `${this.cardTitle} (${this.totalRecords})` : this.cardTitle; }

    get previousClass() { return `pagination-nav-button${this.currentPage <= 1 ? ' disabled' : ''}`; }
    get nextClass() { return `pagination-nav-button${this.currentPage >= this.totalPages ? ' disabled' : ''}`; }

    get displayedPages() {
        const maxVisible = 5;
        const pages = [];
        const { totalPages, currentPage } = this;
        const add = i => pages.push(this._mkPage(i));
        const ell = () => pages.push({ value: '...', isEllipsis: true, isNumber: false });

        if (totalPages <= maxVisible) {
            for (let i = 1; i <= totalPages; i++) add(i);
        } else if (currentPage <= 3) {
            [1, 2, 3, 4].forEach(add); ell(); add(totalPages);
        } else if (currentPage >= totalPages - 2) {
            add(1); ell();
            for (let i = totalPages - 3; i <= totalPages; i++) add(i);
        } else {
            add(1); ell();
            [currentPage - 1, currentPage, currentPage + 1].forEach(add);
            ell(); add(totalPages);
        }
        return pages;
    }

    // ─── Lifecycle ────────────────────────────────────────────────────────────
    async connectedCallback() {
        this._sortBy = this.orderByField || 'CreatedDate';
        this._sortDirection = (this.orderDirection || 'DESC').toLowerCase();
        await this._initComponent();
    }

    renderedCallback() {
        if (!this._wheelBlocked) {
            const wrapper = this.template.querySelector('.table-wrapper');
            if (wrapper) {
                wrapper.addEventListener('wheel', evt => {
                    if (Math.abs(evt.deltaX) > Math.abs(evt.deltaY)) evt.preventDefault();
                }, { passive: false });
                this._wheelBlocked = true;
            }
        }
        // Rendre le HTML des champs formula (innerHTML manuel)
        this.template.querySelectorAll('.html-cell[data-value]').forEach(el => {
            if (el.innerHTML !== el.dataset.value) el.innerHTML = el.dataset.value || '';
        });
    }

    // ─── Initialisation ───────────────────────────────────────────────────────
    async _initComponent() {
        if (!this.targetObjectApiName || !this.fieldsApiNames) {
            this.errorMessage = 'Veuillez configurer targetObjectApiName...';
            return;
        }
        this.isLoading = true;
        this.errorMessage = null;
        try {
            // 1. Récupérer les métadonnées des champs
            this._fieldsMeta = await getFieldsMetadata({
                objectApiName: this.targetObjectApiName,
                fieldsString: this.fieldsApiNames
            });
            // 2. Construire les colonnes
            this._buildColumns();
            // 3. Charger les labels picklist
            await this._loadPicklistLabels();
            // 4. Charger les données
            await this._loadRecords();
            this._configReady = true;
        } catch (e) {
            this.errorMessage = e.body?.message || e.message || 'Erreur d\'initialisation.';
        } finally {
            this.isLoading = false;
        }
    }

    _buildColumns() {
        const labelList = (this.columnLabels || '').split(',').map(l => l.trim());
        this.columns = this._fieldsMeta.map((meta, idx) => ({
            fieldName: meta.apiName,
            label: labelList[idx] || meta.label || meta.apiName,
            sortable: true,
            type: meta.type,
            isPicklist: meta.isPicklist,
            isDate: meta.isDate,
            isDateTime: meta.isDateTime,
            isRelationship: meta.isRelationship,
            sortIcon: 'utility:arrowup',
            ariaSortValue: 'none'
        }));
        // Initialiser l'icône de tri
        this._refreshSortIcons();
    }

    async _loadPicklistLabels() {
        const picklistFields = this._fieldsMeta.filter(m => m.isPicklist);
        const promises = picklistFields.map(async (meta) => {
            const labels = await getPicklistLabelsForField({
                objectApiName: this.targetObjectApiName,
                fieldName: meta.apiName
            });
            this._picklistLabels[meta.apiName] = labels || {};
        });
        await Promise.all(promises);
    }

    async _loadRecords() {
        const raw = await getRecords({
            objectApiName: this.targetObjectApiName,
            fieldsString: this.fieldsApiNames,
            filterField: this.filterField || '',
            filterValue: (this.filterField && this.recordId) ? this.recordId : '',
            recordTypeDeveloperName: this.recordTypeDeveloperName || '',
            orderByField: this._sortBy,
            orderDirection: this._sortDirection.toUpperCase(),
            limitSize: parseInt(this.limitSize, 10) || 200
        });
        this._records = this._transform(raw || []);
        this.totalRecords = this._records.length;
        this.totalPages = Math.ceil(this.totalRecords / parseInt(this.pageSize, 10)) || 1;
        this._applyPage();
    }

    // ─── Transformation des données ───────────────────────────────────────────
    _transform(rawList) {
        return rawList.map(record => {
            const row = { Id: record.Id, _raw: record };

            this._fieldsMeta.forEach(meta => {
                const apiName = meta.apiName;

                // Champs de relation: Account.Name → traverser l'objet
                if (meta.isRelationship) {
                    row[apiName] = this._resolveRelationship(record, apiName);
                } else if (meta.isPicklist) {
                    const rawVal = record[apiName];
                    const plLabels = this._picklistLabels[apiName] || {};
                    row[apiName] = plLabels[rawVal] || rawVal || '';
                } else {
                    row[apiName] = record[apiName] ?? '';
                }
            });

            // Colonne cliquable (ex: CaseNumber → lien vers record)
            row._clickableValue = this.clickableField ? row[this.clickableField] : null;
            row._clickableField = this.clickableField || null;

            // Badges de statut
            if (this.statusField) {
                const rawStatus = record[this.statusField] || '';
                row._statusClass = this._getStatusClass(rawStatus);
                row._statusBadgeClass = this._getStatusBadgeClass(rawStatus);
            } else {
                row._statusClass = '';
                row._statusBadgeClass = '';
            }

            // Construire les cellules pour le template
            row._cells = this._buildCells(row, record);
            return row;
        });
    }

    _buildCells(row, record) {
        return this._fieldsMeta.map(meta => {
            const apiName = meta.apiName;
            const value = row[apiName];
            const isClickable = this.clickableField === apiName;

            // Résoudre l'Id pour la navigation (si la valeur cliquable est dans ce champ)
            let navigateId = record.Id;
            // Si le champ cliquable est un lookup (ex: Claim__r.name), naviguer vers l'Id parent
            if (isClickable && meta.isRelationship) {
                navigateId = this._resolveRelationshipId(record, apiName);
            }

            return {
                key: apiName,
                value: value,
                rawValue: record[apiName],
                isClickable: isClickable,
                navigateId: navigateId,
                isDate: meta.isDate,
                isDateTime: meta.isDateTime,
                isHtml: false, // peut être étendu pour les champs formula HTML
                displayValue: value,
                // Pour les dates, laisser lightning-formatted-date-time gérer
                dateValue: (meta.isDate || meta.isDateTime) ? record[apiName] : null,
                isText: !meta.isDate && !meta.isDateTime
            };
        });
    }

    _resolveRelationship(record, apiName) {
        const parts = apiName.split('.');
        let obj = record;
        for (const part of parts) {
            if (obj == null) return '';
            obj = obj[part];
        }
        return obj ?? '';
    }

    _resolveRelationshipId(record, apiName) {
        // Ex: "Account.Name" → on remonte sur record.Account.Id
        const parts = apiName.split('.');
        let obj = record;
        for (let i = 0; i < parts.length - 1; i++) {
            if (obj == null) return record.Id;
            obj = obj[parts[i]];
        }
        return obj?.Id || record.Id;
    }

    // ─── Pagination & tri ─────────────────────────────────────────────────────
    _applyPage() {
        let data = [...this._records];
        // Tri côté client
        if (this._sortBy) {
            data = this._sortData(data, this._sortBy, this._sortDirection);
        }
        const ps = parseInt(this.pageSize, 10) || 10;
        const start = (this.currentPage - 1) * ps;
        this._pageData = data.slice(start, start + ps);
    }

    _sortData(data, fieldName, direction) {
        return [...data].sort((a, b) => {
            let va = a[fieldName];
            let vb = b[fieldName];
            if (va == null && vb == null) return 0;
            if (va == null) return direction === 'asc' ? -1 : 1;
            if (vb == null) return direction === 'asc' ? 1 : -1;

            const meta = this._fieldsMeta.find(m => m.apiName === fieldName);
            if (meta && (meta.isDate || meta.isDateTime)) {
                va = new Date(a._raw[fieldName]);
                vb = new Date(b._raw[fieldName]);
                return direction === 'asc' ? va - vb : vb - va;
            }
            const r = String(va).toLowerCase().localeCompare(String(vb).toLowerCase());
            return direction === 'asc' ? r : -r;
        });
    }

    _refreshSortIcons() {
        this.columns = this.columns.map(col => ({
            ...col,
            sortIcon: this._sortBy === col.fieldName
                ? (this._sortDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown')
                : 'utility:arrowup',
            ariaSortValue: this._sortBy === col.fieldName
                ? (this._sortDirection === 'asc' ? 'ascending' : 'descending')
                : 'none'
        }));
    }

    // ─── Status helpers ───────────────────────────────────────────────────────
    _getStatusClass(status) {
        const s = (status || '').toLowerCase();
        if (/closed|resolved|completed|actif|active/.test(s)) return 'status-success';
        if (/pending|open|new|en cours/.test(s)) return 'status-warning';
        if (/cancelled|escalated|expiré|expired/.test(s)) return 'status-danger';
        return '';
    }

    _getStatusBadgeClass(status) {
        const s = (status || '').toLowerCase();
        if (/closed|resolved|completed|actif|active/.test(s)) return 'slds-badge badge-success';
        if (/pending|open|new|en cours/.test(s)) return 'slds-badge badge-warning';
        if (/cancelled|escalated|expiré|expired/.test(s)) return 'slds-badge badge-danger';
        return 'slds-badge';
    }

    // ─── Event handlers ───────────────────────────────────────────────────────
    async handleRefresh(e) {
        if (e) e.preventDefault();
        this.isRefreshing = true;
        this.isLoading = true;
        this.errorMessage = null;
        try {
            await this._loadRecords();
            if (this.recordId) getRecordNotifyChange([{ recordId: this.recordId }]);
        } catch (err) {
            this.errorMessage = err.body?.message || 'Erreur lors du chargement.';
        } finally {
            this.isLoading = false;
            this.isRefreshing = false;
        }
    }

    handleRowClick(e) {
        e.preventDefault();
        const recordId = e.currentTarget.dataset.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId, actionName: 'view' }
            });
        }
    }

    handleSort(e) {
        const field = e.currentTarget.dataset.field;
        const col = this.columns.find(c => c.fieldName === field);
        if (!col?.sortable) return;
        this._sortBy === field
            ? (this._sortDirection = this._sortDirection === 'asc' ? 'desc' : 'asc')
            : (this._sortBy = field, this._sortDirection = 'asc');
        this.currentPage = 1;
        this._refreshSortIcons();
        this._applyPage();
    }

    handlePrevious(e) {
        e.preventDefault();
        if (this.currentPage > 1) { this.currentPage--; this._applyPage(); }
    }

    handleNext(e) {
        e.preventDefault();
        if (this.currentPage < this.totalPages) { this.currentPage++; this._applyPage(); }
    }

    handlePageChange(e) {
        e.preventDefault();
        const page = parseInt(e.currentTarget.dataset.page, 10);
        if (page !== this.currentPage && page > 0 && page <= this.totalPages) {
            this.currentPage = page;
            this._applyPage();
        }
    }

    // ─── Private helpers ──────────────────────────────────────────────────────
    _mkPage(num) {
        return {
            value: num,
            isNumber: true,
            isEllipsis: false,
            class: `pagination-page${num === this.currentPage ? ' active' : ''}`,
            ariaLabel: `Page ${num}`,
            ariaCurrent: num === this.currentPage ? 'page' : null
        };
    }
}