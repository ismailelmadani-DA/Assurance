import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin }              from 'lightning/navigation';
import { ShowToastEvent }               from 'lightning/platformShowToastEvent';
import { refreshApex }                  from '@salesforce/apex';
import { getRecord }                    from 'lightning/uiRecordApi';
import Id                               from '@salesforce/user/Id';

import getEvenements            from '@salesforce/apex/DA_lwc020_EvenementListController.getEvenements';
import saveEvenement            from '@salesforce/apex/DA_lwc020_EvenementListController.saveEvenement';
import getCategorieOptions      from '@salesforce/apex/DA_lwc020_EvenementListController.getCategorieOptions';
import getPaysOptions           from '@salesforce/apex/DA_lwc020_EvenementListController.getPaysOptions';
import getDependentTypeOptions  from '@salesforce/apex/DA_lwc020_EvenementListController.getDependentTypeOptions';
import getDependentVilleOptions from '@salesforce/apex/DA_lwc020_EvenementListController.getDependentVilleOptions';

const CAT_FILTER_OPTIONS = [
    { label: 'Toutes les catégories',     value: '' },
    { label: 'Catastrophe Naturelle',     value: 'Catastrophe Naturelle' },
    { label: 'Catastrophe non Naturelle', value: 'Catastrophe non Naturelle' }
];

const PERIOD_FILTER_OPTIONS = [
    { label: 'Toutes les périodes', value: '',       isAllPeriods: true },
    { label: "Aujourd'hui",         value: 'day',    isDay:        true },
    { label: 'Cette semaine',       value: 'week',   isWeek:       true },
    { label: 'Ce mois',             value: 'month',  isMonth:      true },
    { label: 'Cette année',         value: 'year',   isYear:       true },
    { label: 'Plage personnalisée', value: 'custom', isCustom:     true }
];

const ALLOWED_PROFILES = ['Manager', 'Directeur', 'System Administrator'];

const EMPTY_FORM = {
    libelle   : '',
    categorie : '',
    type      : '',
    dateDebut : '',
    dateFin   : '',
    pays      : 'Maroc',
    ville     : '',
    code      : ''
};

// ── Messages d'erreur centralisés ──────────────────────
const ERROR_MESSAGES = {
    libelle   : 'Ce champ est obligatoire.',
    categorie : 'Ce champ est obligatoire.',
    type      : 'Ce champ est obligatoire.',
    dateDebut : 'Ce champ est obligatoire.',
    dateFin   : 'Ce champ est obligatoire.',
    pays      : 'Ce champ est obligatoire.',
    ville     : 'Ce champ est obligatoire.',
};

const EMPTY_ERRORS = () => ({
    libelle   : '',
    categorie : '',
    type      : '',
    dateDebut : '',
    dateFin   : '',
    pays      : '',
    ville     : '',
});

export default class DA_lwc020_evenementList extends NavigationMixin(LightningElement) {

    /* ── États UI ── */
    @track searchTerm            = '';
    @track debouncedSearch       = '';
    @track selectedCat           = '';
    @track selectedPeriod        = '';
    @track currentView           = 'list';
    @track currentPage           = 1;
    @track pageSize              = 10;
    @track pageSizeDropdownOpen  = false;
    @track dropdownOpen          = false;
    @track periodDropdownOpen    = false;
    @track showFormModal         = false;
    @track form                  = { ...EMPTY_FORM };
    @track errors                = EMPTY_ERRORS();
    @track isSaving              = false;
    @track editId                = null;

    /* ── Tri ── */
    @track sortField = '';
    @track sortDir   = 'asc';

    /* ── Filtre période personnalisée ── */
    @track customDateFrom       = '';
    @track customDateTo         = '';
    @track showCustomDateInputs = false;

    /* ── Options picklists ── */
    @track categorieOptions = [];
    @track paysOptions      = [];
    @track villeOptions     = [];

    _dependentTypeOptions  = {};
    _dependentVilleOptions = {};
    _userProfileName       = '';
    _wiredEvenementsResult;
    _debounceTimer;
    _closeDropdown;

    /* ══ LIFECYCLE ══ */
    connectedCallback() {
        this._closeDropdown = (event) => {
            const inside = this.template.querySelector('.ev-toolbar__right');
            if (inside && inside.contains(event.target)) return;
            this.dropdownOpen         = false;
            this.pageSizeDropdownOpen = false;
            this.periodDropdownOpen   = false;
            this.showCustomDateInputs = false;
        };
        document.addEventListener('click', this._closeDropdown);
        this._loadPicklists();
    }
disconnectedCallback() {
    document.removeEventListener('click', this._closeDropdown);
}

/* ══ FIX DROPDOWN HAUTEUR ══ */
renderedCallback() {
    if (this._styleInjected) return;
    this._styleInjected = true;

    const style = document.createElement('style');
    style.textContent = `
        .slds-listbox.slds-dropdown.slds-dropdown_fluid,
        .slds-listbox_vertical.slds-dropdown.slds-dropdown_fluid {
            height: auto !important;
            max-height: 250px !important;
            overflow-y: auto !important;
            overflow-x: hidden !important;
        }
    `;
    document.head.appendChild(style);
}


    /* ══ WIRE ══ */
    @wire(getRecord, { recordId: Id, fields: ['User.Profile.Name'] })
    wiredUser({ data, error }) {
        if (data) {
            this._userProfileName = data.fields.Profile.value.fields.Name.value;
        }
        if (error) console.error('Erreur profil utilisateur :', error);
    }

    @wire(getEvenements, {
        catFilter    : '$selectedCat',
        periodFilter : '$selectedPeriod',
        searchTerm   : '$debouncedSearch'
    })
    wiredEvenements(result) {
        this._wiredEvenementsResult = result;
    }

    /* ══ PICKLISTS ══ */
    _loadPicklists() {
        getCategorieOptions()
            .then(d => { this.categorieOptions = d; })
            .catch(e => console.error('getCategorieOptions:', e));

        getPaysOptions()
            .then(d => { this.paysOptions = d; })
            .catch(e => console.error('getPaysOptions:', e));

        getDependentTypeOptions()
            .then(d => { this._dependentTypeOptions = d; })
            .catch(e => console.error('getDependentTypeOptions:', e));

        getDependentVilleOptions()
            .then(d => {
                this._dependentVilleOptions = d;
                this.villeOptions = d['Maroc'] || [];
            })
            .catch(e => console.error('getDependentVilleOptions:', e));
    }

    /* ══ DROITS ══ */
    get canCreate() {
        return ALLOWED_PROFILES.includes(this._userProfileName);
    }

    /* ══ DONNÉES ENRICHIES ══ */
    get evenements() {
        return this._wiredEvenementsResult?.data
            ? this._wiredEvenementsResult.data.map(ev => this._enrichRow(ev))
            : [];
    }

    get hasError() { return !!this._wiredEvenementsResult?.error; }

    _enrichRow(ev) {
        const initials = this._getInitials(ev.createdByName);
        const isNat    = ev.categorie === 'Catastrophe Naturelle';
        return {
            Id            : ev.id,
            Code          : ev.code,
            Libelle       : ev.libelle,
            Categorie     : ev.categorie,
            Type          : ev.type,
            DateDebut     : ev.dateDebut    || '—',
            DateFin       : ev.dateFin      || '—',
            Pays          : ev.pays,
            Ville         : ev.ville        || '—',
            DateCreation  : ev.dateCreation || '—',
            CreatedById   : ev.createdById,
            CreatedByName : ev.createdByName || '—',
            initials,
            catShortLabel : isNat ? 'Naturelle' : 'Non naturelle',
            avatarClass   : `ev-avatar ev-avatar--${isNat ? 'nat' : 'nonnat'}`,
            catBadgeClass : `ev-cat-badge ${isNat ? 'ev-cat-badge--nat' : 'ev-cat-badge--nonnat'}`,
            typePillClass : `ev-type-pill--${isNat ? 'nat' : 'nonnat'}`
        };
    }

    _getInitials(name) {
        if (!name) return '??';
        const parts = name.trim().split(/\s+/);
        if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase();
        return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }

    /* ══ FILTRAGE TEXTE ══ */
    get filteredEvenements() {
        const term = this.debouncedSearch.toLowerCase().trim();
        if (!term) return this.evenements;
        return this.evenements.filter(e =>
            (e.Libelle       || '').toLowerCase().includes(term) ||
            (e.Code          || '').toLowerCase().includes(term) ||
            (e.Type          || '').toLowerCase().includes(term) ||
            (e.Ville         || '').toLowerCase().includes(term) ||
            (e.CreatedByName || '').toLowerCase().includes(term)
        );
    }

    /* ══ TRI ══ */
    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        if (this.sortField === field) {
            this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField = field;
            this.sortDir   = 'asc';
        }
        this.currentPage = 1;
    }

    get sortedEvenements() {
        const data = [...this.filteredEvenements];
        if (!this.sortField) return data;
        const dir = this.sortDir === 'asc' ? 1 : -1;
        return data.sort((a, b) => {
            const va = (a[this.sortField] || '').toString().toLowerCase();
            const vb = (b[this.sortField] || '').toString().toLowerCase();
            if (va < vb) return -1 * dir;
            if (va > vb) return  1 * dir;
            return 0;
        });
    }

    /* Classes et icônes par colonne */
    _thClass(field) {
        let cls = 'ev-th ev-th--sortable';
        if (this.sortField === field) {
            cls += ' ev-th--sorted';
            cls += this.sortDir === 'asc' ? ' ev-th--asc' : ' ev-th--desc';
        }
        return cls;
    }

    get thCodeClass()         { return this._thClass('Code'); }
    get thTypeClass()         { return this._thClass('Type'); }
    get thDateDebClass()      { return this._thClass('DateDebut'); }
    get thDateFinClass()      { return this._thClass('DateFin'); }
    get thVilleClass()        { return this._thClass('Ville'); }
    get thCreatedClass()      { return this._thClass('CreatedByName'); }
    get thDateCreationClass() { return this._thClass('DateCreation'); }

    /* ══ STATS ══ */
    get totalCount()     { return this.evenements.length; }
    get catNatCount()    { return this.evenements.filter(e => e.Categorie === 'Catastrophe Naturelle').length; }
    get catNonNatCount() { return this.evenements.filter(e => e.Categorie === 'Catastrophe non Naturelle').length; }

    get catNatPct() {
        return this.totalCount ? Math.round((this.catNatCount / this.totalCount) * 100) : 0;
    }
    get catNonNatPct() {
        return this.totalCount ? Math.round((this.catNonNatCount / this.totalCount) * 100) : 0;
    }

    /* ══ VUE LISTE / CARTES ══ */
    get isListView() { return this.currentView === 'list'; }
    get isCardView() { return this.currentView === 'card'; }

    get btnListClass() { return `ev-view-btn${this.isListView ? ' ev-view-btn--active' : ''}`; }
    get btnCardClass() { return `ev-view-btn${this.isCardView ? ' ev-view-btn--active' : ''}`; }

    switchToList()  { this.currentView = 'list'; this.currentPage = 1; }
    switchToCards() { this.currentView = 'card'; this.currentPage = 1; }

    /* ══ RECHERCHE ══ */
    handleSearch(event) {
        this.searchTerm = event.target.value;
        clearTimeout(this._debounceTimer);
        this._debounceTimer = setTimeout(() => {
            this.debouncedSearch = this.searchTerm;
            this.currentPage     = 1;
        }, 350);
    }

    /* ══ DROPDOWN CATÉGORIE ══ */
    get selectedCatLabel() {
        const found = CAT_FILTER_OPTIONS.find(o => o.value === this.selectedCat);
        return found ? found.label : 'Toutes les catégories';
    }

    get catOptions() {
        return CAT_FILTER_OPTIONS.map(opt => ({
            ...opt,
            optionClass: `ev-dropdown__option${this.selectedCat === opt.value ? ' ev-dropdown__option--active' : ''}`
        }));
    }

    toggleDropdown(event) {
        event.stopPropagation();
        this.periodDropdownOpen   = false;
        this.pageSizeDropdownOpen = false;
        this.dropdownOpen         = !this.dropdownOpen;
    }

    handleCatFilter(event) {
        event.stopPropagation();
        this.selectedCat  = event.currentTarget.dataset.value;
        this.dropdownOpen = false;
        this.currentPage  = 1;
    }

    /* ══ DROPDOWN PÉRIODE ══ */
    get selectedPeriodLabel() {
        if (this.customDateFrom && this.customDateTo && this.selectedPeriod.startsWith('custom|')) {
            const fmt = (d) => {
                if (!d) return '';
                const [y, m, day] = d.split('-');
                return `${day}/${m}/${y}`;
            };
            return `${fmt(this.customDateFrom)} → ${fmt(this.customDateTo)}`;
        }
        const found = PERIOD_FILTER_OPTIONS.find(o => o.value === this.selectedPeriod);
        return found ? found.label : 'Toutes les périodes';
    }

    get showDateRange() {
        return this.selectedPeriod === 'custom';
    }

    get hasPeriodFilter() {
        return !!this.selectedPeriod;
    }

    get periodOptions() {
        return PERIOD_FILTER_OPTIONS.map(opt => ({
            ...opt,
            optionClass: `ev-period-option${
                (this.selectedPeriod === opt.value ||
                (opt.value === '' && !this.selectedPeriod))
                    ? ' ev-period-option--active' : ''
            }`
        }));
    }

    togglePeriodDropdown(event) {
        event.stopPropagation();
        this.dropdownOpen         = false;
        this.pageSizeDropdownOpen = false;
        this.periodDropdownOpen   = !this.periodDropdownOpen;
        if (!this.periodDropdownOpen) {
            this.showCustomDateInputs = false;
        }
    }

    handlePeriodFilter(event) {
        event.stopPropagation();
        const newValue = event.currentTarget.dataset.value;
        this.selectedPeriod = newValue;
        if (newValue !== 'custom') {
            this.periodDropdownOpen = false;
            this.currentPage        = 1;
        }
    }

    handleCustomDateFrom(event) {
        this.customDateFrom = event.detail.value;
    }

    handleCustomDateTo(event) {
        this.customDateTo = event.detail.value;
    }

    handleApplyCustomPeriod(event) {
        event.stopPropagation();
        if (!this.customDateFrom || !this.customDateTo) {
            this._showToast('Validation', 'Veuillez sélectionner les deux dates.', 'warning');
            return;
        }
        if (this.customDateTo < this.customDateFrom) {
            this._showToast('Validation', 'La date de fin doit être postérieure à la date de début.', 'warning');
            return;
        }
        this.selectedPeriod       = 'custom|' + this.customDateFrom + '|' + this.customDateTo;
        this.periodDropdownOpen   = false;
        this.showCustomDateInputs = false;
        this.currentPage          = 1;
    }

    handleResetPeriod(event) {
        event.stopPropagation();
        event.preventDefault();
        this.selectedPeriod       = '';
        this.customDateFrom       = '';
        this.customDateTo         = '';
        this.showCustomDateInputs = false;
        this.periodDropdownOpen   = false;
        this.currentPage          = 1;
    }

    /* ══ PAGINATION ══ */
    get paginatedEvenements() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.sortedEvenements.slice(start, start + this.pageSize);
    }

    get hasRows()    { return this.paginatedEvenements.length > 0; }
    get totalPages() { return Math.ceil(this.sortedEvenements.length / this.pageSize) || 1; }
    get isFirstPage(){ return this.currentPage === 1; }
    get isLastPage() { return this.currentPage === this.totalPages; }

    get rowsInfo() {
        const total = this.sortedEvenements.length;
        if (total === 0) return '0 lignes';
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end   = Math.min(this.currentPage * this.pageSize, total);
        return `${start}-${end} sur ${total} lignes`;
    }

    get pageSizeOptions() {
        return [10, 15, 25, 50].map(n => ({
            value      : n,
            label      : String(n),
            optionClass: `ev-dropdown__option${this.pageSize === n ? ' ev-dropdown__option--active' : ''}`
        }));
    }

    togglePageSizeDropdown(event) {
        event.stopPropagation();
        this.dropdownOpen         = false;
        this.periodDropdownOpen   = false;
        this.pageSizeDropdownOpen = !this.pageSizeDropdownOpen;
    }

    handlePageSizeChange(event) {
        event.stopPropagation();
        this.pageSize             = Number(event.currentTarget.dataset.value);
        this.pageSizeDropdownOpen = false;
        this.currentPage          = 1;
    }

    get pageNumbers() {
        const total   = this.totalPages;
        const current = this.currentPage;
        const pages   = [];

        const addPage = (p) => pages.push({
            key       : `p-${p}`,
            page      : p,
            label     : String(p),
            isEllipsis: false,
            btnClass  : `ev-btn ev-btn--page${current === p ? ' ev-btn--page-active' : ''}`
        });
        const addEllipsis = (key) => pages.push({ key, page: null, label: '…', isEllipsis: true, btnClass: '' });

        if (total <= 7) {
            for (let i = 1; i <= total; i++) addPage(i);
        } else {
            addPage(1);
            if (current > 3) addEllipsis('e1');
            const start = Math.max(2, current - 1);
            const end   = Math.min(total - 1, current + 1);
            for (let i = start; i <= end; i++) addPage(i);
            if (current < total - 2) addEllipsis('e2');
            addPage(total);
        }
        return pages;
    }

    prevPage()  { if (this.currentPage > 1)              this.currentPage--; }
    nextPage()  { if (this.currentPage < this.totalPages) this.currentPage++; }
    firstPage() { this.currentPage = 1; }
    lastPage()  { this.currentPage = this.totalPages; }

    goToPage(event) {
        const page = Number(event.currentTarget.dataset.page);
        if (page && page !== this.currentPage) this.currentPage = page;
    }

    /* ══ MODAL ══ */
    get modalTitle() {
        return this.editId ? "Modifier l'événement" : 'Nouvel événement';
    }

    get saveLabel() {
        return this.editId ? 'Mettre à jour' : 'Enregistrer';
    }

    get typeOptions() {
        if (!this.form.categorie) {
            return [{ label: "— Choisir une catégorie d'abord —", value: '' }];
        }
        const opts = this._dependentTypeOptions[this.form.categorie] || [];
        return opts.length ? opts : [{ label: "— Aucun type disponible —", value: '' }];
    }

    get isTypeDisabled()  { return !this.form.categorie; }
    get isVilleDisabled() { return !this.form.pays; }

    handleAjouter() {
        this.editId        = null;
        this.errors        = EMPTY_ERRORS();
        this.form          = { ...EMPTY_FORM, code: 'Généré après enregistrement' };
        this.villeOptions  = this._dependentVilleOptions['Maroc'] || [];
        this.showFormModal = true;
    }

    handleRowAction(event) {
        const id  = event.currentTarget.dataset.id;
        const row = this.evenements.find(e => e.Id === id);
        if (!row) return;
        this.editId = id;
        this.errors = EMPTY_ERRORS();
        this.form = {
            libelle   : row.Libelle   || '',
            categorie : row.Categorie || '',
            type      : row.Type      || '',
            dateDebut : row.DateDebut !== '—' ? row.DateDebut : '',
            dateFin   : row.DateFin   !== '—' ? row.DateFin   : '',
            pays      : row.Pays      || 'Maroc',
            ville     : row.Ville     !== '—' ? row.Ville     : '',
            code      : row.Code      || ''
        };
        this.villeOptions  = this._dependentVilleOptions[this.form.pays] || [];
        this.showFormModal = true;
    }

    /* ══ GESTION DES CHAMPS ══ */
    handleCategorieChange(event) {
        const val = event.detail.value;
        this.form = { ...this.form, categorie: val, type: '' };
        // Efface les erreurs catégorie et type
        if (val) {
            this.errors = { ...this.errors, categorie: '', type: '' };
        }
    }

    handleFieldChange(event) {
        const field = event.target.name || event.target.dataset.field;
        const value = event.detail?.value ?? event.target.value;
        this.form = { ...this.form, [field]: value };

        // Efface l'erreur du champ modifié
        if (this.errors[field] !== undefined) {
            this.errors = { ...this.errors, [field]: '' };
        }

       if (field === 'pays') {
    this.villeOptions = this._dependentVilleOptions[value] || [];
    this.form         = { ...this.form, ville: '' };
    this.errors       = { ...this.errors, ville: '', pays: '' };
}
    }

    handleFieldBlur(event) {
        const name  = event.target.name;
        const value = event.target.value;
        if (ERROR_MESSAGES[name] && !value?.trim()) {
            this.errors = { ...this.errors, [name]: ERROR_MESSAGES[name] };
        }
    }

    /* ══ VALIDATION ══ */
   _validate() {
    const e = EMPTY_ERRORS();
    let ok = true;

    if (!this.form.libelle?.trim())
        { e.libelle   = ERROR_MESSAGES.libelle;   ok = false; }
    if (!this.form.categorie)
        { e.categorie = ERROR_MESSAGES.categorie; ok = false; }
    if (!this.form.type)
        { e.type      = ERROR_MESSAGES.type;      ok = false; }
    if (!this.form.dateDebut)
        { e.dateDebut = ERROR_MESSAGES.dateDebut; ok = false; }
    if (!this.form.dateFin)
        { e.dateFin   = ERROR_MESSAGES.dateFin;   ok = false; }
    if (!this.form.pays)
        { e.pays      = ERROR_MESSAGES.pays;      ok = false; }
    if (!this.form.ville)
        { e.ville     = ERROR_MESSAGES.ville;     ok = false; }

    // Validation cohérence dates (inline sur dateFin)
    if (this.form.dateFin && this.form.dateDebut &&
        this.form.dateFin < this.form.dateDebut) {
        e.dateFin = 'La date de fin doit être postérieure à la date de début.';
        ok = false;
    }

    this.errors = e;

    if (!ok) {
        setTimeout(() => {
            const firstError = this.template.querySelector('.pm-error');
            if (firstError) {
                firstError.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
        }, 50);
        return false;
    }

    return true;
}

    /* ══ SAUVEGARDE ══ */
    handleSave() {
        if (!this._validate()) return;
        this.isSaving       = true;
        const isNew         = !this.editId;
        const libelleBackup = this.form.libelle;
        const req = {
            id        : this.editId || null,
            libelle   : this.form.libelle,
            categorie : this.form.categorie,
            type      : this.form.type,
            dateDebut : this.form.dateDebut,
            dateFin   : this.form.dateFin   || null,
            pays      : this.form.pays      || 'Maroc',
            ville     : this.form.ville
        };
        saveEvenement({ req })
            .then(() => {
                this.closeModal();
                this._showToast(
                    isNew ? 'Événement créé !' : 'Événement mis à jour !',
                    `${libelleBackup} a été enregistré avec succès.`,
                    'success', 'sticky'
                );
                return refreshApex(this._wiredEvenementsResult);
            })
            .catch(error => {
                this._showToast(
                    "Erreur lors de l'enregistrement",
                    error?.body?.message || "Une erreur inattendue s'est produite.",
                    'error', 'sticky'
                );
            })
            .finally(() => { this.isSaving = false; });
    }

    /* ══ NAVIGATION ══ */
    handleNavigateToEvenement(event) {
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({
            type       : 'standard__recordPage',
            attributes : { recordId: id, objectApiName: 'Evenement__c', actionName: 'view' }
        });
    }

    handleNavigateToUser(event) {
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({
            type       : 'standard__recordPage',
            attributes : { recordId: id, objectApiName: 'User', actionName: 'view' }
        });
    }

    /* ══ UTILITAIRES ══ */
    closeModal() {
        this.showFormModal = false;
        this.editId        = null;
        this.errors        = EMPTY_ERRORS();
    }
    handleOverlayClick() { this.closeModal(); }
    stopPropagation(evt) { evt.stopPropagation(); }

    _showToast(title, message, variant, mode = 'dismissable') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
    }
}