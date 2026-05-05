import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getPrestataires          from '@salesforce/apex/DA_lwc016_prestataireListController.getPrestataires';
import generateCode             from '@salesforce/apex/DA_lwc016_prestataireListController.generateCode';
import savePrestataire          from '@salesforce/apex/DA_lwc016_prestataireListController.savePrestataire';
import getBanqueOptions         from '@salesforce/apex/DA_lwc016_prestataireListController.getBanqueOptions';
import getPaysOptions           from '@salesforce/apex/DA_lwc016_prestataireListController.getPaysOptions';
import getDependentVilleOptions from '@salesforce/apex/DA_lwc016_prestataireListController.getDependentVilleOptions';

const TYPE_KEY_MAP = {
    'Médecin'             : 'med',
    'Clinique'            : 'clin',
    'Hôpital'             : 'clin',
    'Centre radiologique' : 'clin',
    'Pharmacie'           : 'pharm',
    'Garagiste'           : 'gar',
    'Expert Automobile'   : 'exp',
    'Avocat'              : 'avo',
    'Enquêteur'           : 'enq'
};

const TYPE_OPTIONS = [
    { label: 'Tous les types',       value: '' },
    { label: 'Médecin',              value: 'Médecin' },
    { label: 'Clinique',             value: 'Clinique' },
    { label: 'Hôpital',             value: 'Hôpital' },
    { label: 'Centre radiologique',  value: 'Centre radiologique' },
    { label: 'Pharmacie',            value: 'Pharmacie' },
    { label: 'Garagiste',            value: 'Garagiste' },
    { label: 'Expert Automobile',    value: 'Expert Automobile' },
    { label: 'Avocat',               value: 'Avocat' },
    { label: 'Enquêteur',            value: 'Enquêteur' }
];

const EMPTY_FORM = {
    type       : '',
    oldType    : '',
    name       : '',
    code       : '',
    phone      : '',
    email      : '',
    banque     : '',
    codeBanque : '',
    rib        : '',
    ribId      : '',
    statutRib  : 'RIB Saisi',
    actif      : true,
    pays       : '',
    ville      : '',
    adresse    : ''
};

// ── Messages d'erreur centralisés ──────────────────────
const ERROR_MESSAGES = {
    name : 'Ce champ est obligatoire.',
};

const EMPTY_ERRORS = () => ({
    name : '',
});

export default class DA_lwc016_prestataireList extends NavigationMixin(LightningElement) {

    /* ── Liste / filtres ── */
    @track searchTerm           = '';
    @track selectedType         = '';
    @track currentPage          = 1;
    @track pageSize             = 10;
    @track pageSizeDropdownOpen = false;
    @track showFormModal        = false;
    @track currentStep          = 1;
    @track form                 = { ...EMPTY_FORM };
    @track errors               = EMPTY_ERRORS();
    @track isSaving             = false;
    @track isLoading            = false;
    @track editId               = null;
    @track banqueOptions        = [];
    @track paysOptions          = [];
    @track villeOptions         = [];
    @track dropdownOpen         = false;

    _wiredResult;
    _allResult;
    _closeDropdown;
    _dependentVilleOptions = {};
    _banqueCodeMap         = {};

    /* ══════════════════════════════════════
       LIFECYCLE
    ══════════════════════════════════════ */
    connectedCallback() {
        this._closeDropdown = () => {
            this.dropdownOpen         = false;
            this.pageSizeDropdownOpen = false;
        };
        document.addEventListener('click', this._closeDropdown);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this._closeDropdown);
    }

    renderedCallback() {
    if (this._styleInjected) return;
    this._styleInjected = true;

    const style = document.createElement('style');
    style.textContent = `
        .slds-listbox.slds-dropdown.slds-dropdown_fluid,
        .slds-listbox_vertical.slds-dropdown.slds-dropdown_fluid {
            max-height: 150px !important;
            height: auto !important;
            overflow-y: auto !important;
            overflow-x: hidden !important;
        }
    `;
    document.head.appendChild(style);
}

    /* ══════════════════════════════════════
       WIRE
    ══════════════════════════════════════ */
    @wire(getPrestataires, { typeFilter: '$selectedType', searchTerm: '$debouncedSearch' })
    wiredPrestataires(result) {
        this._wiredResult = result;
        this.isLoading    = false;
    }

    @wire(getPrestataires, { typeFilter: '', searchTerm: '' })
    wiredAllPrestataires(result) {
        this._allResult = result;
    }

    get prestataires() {
        return this._wiredResult?.data
            ? this._wiredResult.data.map(p => this._enrichRow(p))
            : [];
    }

    get allPrestataires() {
        return this._allResult?.data
            ? this._allResult.data.map(p => this._enrichRow(p))
            : [];
    }

    get hasError() { return !!this._wiredResult?.error; }
    get errorMsg()  { return this._wiredResult?.error?.body?.message || 'Erreur inconnue'; }

    /* ══════════════════════════════════════
       STATS
    ══════════════════════════════════════ */
    get totalCount()      { return this.allPrestataires.length; }
    get medecinCount()    { return this.allPrestataires.filter(p => p.Type === 'Médecin').length; }
    get cliniqueCount()   { return this.allPrestataires.filter(p => p.Type === 'Clinique').length; }
    get hopitalCount()    { return this.allPrestataires.filter(p => p.Type === 'Hôpital').length; }
    get centreRadioCount(){ return this.allPrestataires.filter(p => p.Type === 'Centre radiologique').length; }
    get pharmacieCount()  { return this.allPrestataires.filter(p => p.Type === 'Pharmacie').length; }
    get garagisteCount()  { return this.allPrestataires.filter(p => p.Type === 'Garagiste').length; }
    get expertCount()     { return this.allPrestataires.filter(p => p.Type === 'Expert Automobile').length; }
    get avocatCount()     { return this.allPrestataires.filter(p => p.Type === 'Avocat').length; }
    get enqueteurCount()  { return this.allPrestataires.filter(p => p.Type === 'Enquêteur').length; }
    get filteredCount()   { return this.prestataires.length; }

    /* ══════════════════════════════════════
       VILLE disabled
    ══════════════════════════════════════ */
    get isVilleDisabled() { return !this.form.pays; }

    /* ══════════════════════════════════════
       DROPDOWN TYPE
    ══════════════════════════════════════ */
    get selectedTypeLabel() {
        const found = TYPE_OPTIONS.find(o => o.value === this.selectedType);
        return found ? found.label : 'Tous les types';
    }

    get typeOptions() {
        return TYPE_OPTIONS.map(opt => ({
            ...opt,
            optionClass: `pm-dropdown__option${this.selectedType === opt.value ? ' pm-dropdown__option--active' : ''}`
        }));
    }

    toggleDropdown(event) {
        event.stopPropagation();
        this.dropdownOpen = !this.dropdownOpen;
    }

    handleTypeFilter(event) {
        event.stopPropagation();
        this.selectedType = event.currentTarget.dataset.value;
        this.dropdownOpen = false;
        this.currentPage  = 1;
        this.isLoading    = true;
    }

    /* ══════════════════════════════════════
       RECHERCHE DEBOUNCE
    ══════════════════════════════════════ */
    _debounceTimer;
    @track debouncedSearch = '';

    handleSearch(event) {
        this.searchTerm = event.target.value;
        clearTimeout(this._debounceTimer);
        this._debounceTimer = setTimeout(() => {
            this.debouncedSearch = this.searchTerm;
            this.currentPage     = 1;
        }, 350);
    }

    /* ══════════════════════════════════════
       PAGINATION
    ══════════════════════════════════════ */
    get filteredPrestataires() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.prestataires.slice(start, start + this.pageSize);
    }
    get hasRows()    { return this.filteredPrestataires.length > 0; }
    get totalPages() { return Math.ceil(this.prestataires.length / this.pageSize) || 1; }
    get isFirstPage(){ return this.currentPage === 1; }
    get isLastPage() { return this.currentPage === this.totalPages; }

    get rowsInfo() {
        const total = this.prestataires.length;
        if (total === 0) return '0 rows';
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end   = Math.min(this.currentPage * this.pageSize, total);
        return `${start}-${end} sur ${total} Lignes`;
    }

    get pageSizeOptions() {
        return [10, 15, 25, 50].map(n => ({
            value      : n,
            label      : String(n),
            optionClass: `pm-dropdown__option${this.pageSize === n ? ' pm-dropdown__option--active' : ''}`
        }));
    }

    togglePageSizeDropdown(event) {
        event.stopPropagation();
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
            key        : `p-${p}`,
            page       : p,
            label      : String(p),
            isEllipsis : false,
            btnClass   : `pm-btn pm-btn--page${current === p ? ' pm-btn--page-active' : ''}`
        });
        const addEllipsis = (key) => pages.push({
            key, page: null, label: '…', isEllipsis: true, btnClass: ''
        });

        if (total <= 7) {
            for (let i = 1; i <= total; i++) addPage(i);
        } else {
            addPage(1);
            if (current > 3)         addEllipsis('e1');
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

    /* ══════════════════════════════════════
       STEPPER
    ══════════════════════════════════════ */
    get isStep1()        { return this.currentStep === 1; }
    get isStep2()        { return this.currentStep === 2; }
    get isNextDisabled() { return !this.form.type; }
    get step1Class()     { return 'pm-step pm-step--active'; }
    get step2Class()     { return this.isStep2 ? 'pm-step pm-step--active' : 'pm-step'; }
    get lineClass()      { return this.isStep2 ? 'pm-step__line pm-step__line--active' : 'pm-step__line'; }

    get modalTitle() {
        if (this.editId) return 'Modifier le prestataire';
        return this.currentStep === 1 ? 'Nouveau prestataire' : `Informations — ${this.form.type}`;
    }
    get saveLabel() { return this.editId ? 'Mettre à jour' : 'Confirmer'; }

    /* ══════════════════════════════════════
       TYPE OPTIONS FORMULAIRE
    ══════════════════════════════════════ */
    get typeOptionsForForm() {
        return TYPE_OPTIONS
            .filter(o => o.value !== '')
            .map(o => ({ ...o, checked: this.form.type === o.value }));
    }

    handleTypeRadioClick(event) {
        const value = event.target.dataset.value;
        this.form = { ...this.form, type: value };
        if (!this.editId || value !== this.form.oldType) {
            generateCode({ type: value })
                .then(code => { this.form = { ...this.form, code }; });
        }
    }

    /* ══════════════════════════════════════
       OUVRIR MODALE — AJOUT
    ══════════════════════════════════════ */
    handleAjouter() {
        this.editId        = null;
        this.errors        = EMPTY_ERRORS();
        this.form          = { ...EMPTY_FORM };
        this.villeOptions  = [];
        this.currentStep   = 1;
        this._loadPicklists();
        this.showFormModal = true;
    }

    /* ══════════════════════════════════════
       NAVIGATION VERS PAGE DÉTAILS
    ══════════════════════════════════════ */
    handleNavigateToPrestataire(e) {
        e.preventDefault();
        const prestataireId = e.currentTarget.dataset.id;
        if (!prestataireId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: prestataireId, objectApiName: 'Account', actionName: 'view' }
        });
    }

    /* ══════════════════════════════════════
       OUVRIR MODALE — MODIFICATION
    ══════════════════════════════════════ */
    handleRowAction(event) {
        const id  = event.currentTarget.dataset.id;
        const row = this.prestataires.find(p => p.Id === id);
        if (!row) return;

        this.editId = id;
        this.errors = EMPTY_ERRORS();
        this.form   = {
            type       : row.type       || '',
            oldType    : row.type       || '',
            name       : row.name       || '',
            code       : row.code       || '',
            phone      : row.phone      || '',
            email      : row.email      || '',
            banque     : row.banque     || '',
            codeBanque : row.codeBanque || '',
            rib        : row.rib        || '',
            ribId      : row.ribId      || '',
            statutRib  : row.statutRib  || 'RIB Saisi',
            actif      : row.actif      !== undefined ? row.actif : true,
            pays       : row.pays       || '',
            ville      : row.ville      || '',
            adresse    : row.adresse    || ''
        };
        this.currentStep = 2;
        this._loadPicklists().then(() => {
            if (this.form.pays) {
                this.villeOptions = this._dependentVilleOptions[this.form.pays] || [];
            }
            if (this.form.banque && !this.form.codeBanque) {
                this.form = { ...this.form, codeBanque: this._banqueCodeMap[this.form.banque] || '' };
            }
        });
        this.showFormModal = true;
    }

    /* ══════════════════════════════════════
       CHARGEMENT PICKLISTS
    ══════════════════════════════════════ */
    _loadPicklists() {
        const p1 = getBanqueOptions().then(data => {
            this._banqueCodeMap = {};
            this.banqueOptions  = data.map(o => {
                this._banqueCodeMap[o.value] = o.code ?? o.value;
                return { label: o.label, value: o.value };
            });
        });
        const p2 = getPaysOptions().then(data => {
            this.paysOptions = data.map(o => ({ label: o.label, value: o.value }));
        });
        const p3 = getDependentVilleOptions().then(data => {
            this._dependentVilleOptions = data;
        });
        return Promise.all([p1, p2, p3]);
    }

    /* ══════════════════════════════════════
       CHANGEMENTS CHAMPS
    ══════════════════════════════════════ */
    handleBanqueChange(event) {
        const banqueValue = event.detail.value;
        const codeBanque  = this._banqueCodeMap[banqueValue] || '';
        this.form = { ...this.form, banque: banqueValue, codeBanque };
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
            this.form = { ...this.form, ville: '' };
        }
    }

    handleFieldBlur(event) {
        const name  = event.target.name;
        const value = event.target.value;
        if (ERROR_MESSAGES[name] && !value?.trim()) {
            this.errors = { ...this.errors, [name]: ERROR_MESSAGES[name] };
        }
    }

    /* ══════════════════════════════════════
       NAVIGATION STEPPER
    ══════════════════════════════════════ */
    handleNextStep() { this.currentStep = 2; }
    handlePrevStep() { this.currentStep = 1; }

    /* ══════════════════════════════════════
       SAUVEGARDE
    ══════════════════════════════════════ */
    handleSave() {
        if (!this._validateStep2()) return;

        this.isSaving = true;
        const isNew      = !this.editId;
        const nomPresta  = this.form.name;
        const codePresta = this.form.code;
        const currentId  = this.editId;

        const req = {
            id         : this.editId || null,
            type       : this.form.type,
            oldType    : this.form.oldType || null,
            name       : this.form.name,
            phone      : this.form.phone,
            email      : this.form.email,
            banque     : this.form.banque,
            codeBanque : this.form.codeBanque,
            rib        : this.form.rib,
            ribId      : this.form.ribId || null,
            statutRib  : this.form.statutRib,
            actif      : this.form.actif,
            pays       : this.form.pays || '',
            ville      : this.form.ville,
            adresse    : this.form.adresse
        };

        savePrestataire({ req })
            .then((newId) => {
                this.closeModal();
                const recordId = isNew ? newId : currentId;
                const url      = `/lightning/r/Account/${recordId}/view`;
                this._showToast(
                    isNew ? 'Prestataire créé !' : 'Prestataire mis à jour !',
                    '{0} ({1}) a été enregistré avec succès.',
                    'success',
                    'sticky',
                    [{ url, label: nomPresta }, codePresta]
                );
                return Promise.all([
                    refreshApex(this._wiredResult),
                    refreshApex(this._allResult)
                ]);
            })
            .catch(error => {
                this._showToast(
                    'Erreur lors de l\'enregistrement',
                    error?.body?.message || 'Une erreur inattendue s\'est produite.',
                    'error',
                    'sticky'
                );
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    /* ══════════════════════════════════════
       VALIDATION ÉTAPE 2
    ══════════════════════════════════════ */
    _validateStep2() {
        const e = EMPTY_ERRORS();
        let ok = true;

        if (!this.form.name?.trim()) {
            e.name = ERROR_MESSAGES.name;
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

        if (this.form.rib && this.form.rib.length > 24) {
            this._showToast('Validation', 'Le RIB ne peut pas dépasser 24 caractères.', 'warning');
            return false;
        }

        return true;
    }

    /* ══════════════════════════════════════
       UTILITAIRES
    ══════════════════════════════════════ */
    closeModal() {
        this.showFormModal = false;
        this.errors        = EMPTY_ERRORS();
    }
    handleOverlayClick() { this.closeModal(); }
    stopPropagation(evt) { evt.stopPropagation(); }

    _showToast(title, message, variant, mode = 'dismissable', messageData = []) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode, messageData }));
    }

    _enrichRow(p) {
        const typeKey  = TYPE_KEY_MAP[p.type] || 'def';
        const initials = this._getInitials(p.name);
        return {
            ...p,
            Id         : p.id,
            Name       : p.name,
            Type       : p.type,
            Code       : p.code,
            Phone      : p.phone || '—',
            Ville      : p.ville || '—',
            initials,
            avatarClass: `pm-avatar pm-avatar--${typeKey}`,
            badgeClass : `pm-role pm-role--${this._getBadgeVariant(p.type)}`
        };
    }

    _getBadgeVariant(type) {
        if (['Médecin','Clinique','Hôpital','Centre radiologique','Pharmacie'].includes(type)) return 'assure';
        if (['Avocat','Enquêteur'].includes(type)) return 'adverse';
        if (type === 'Garagiste')         return 'orange';
        if (type === 'Expert Automobile') return 'blue';
        return 'assure';
    }

    _getInitials(name) {
        if (!name) return '??';
        const parts = name.trim().split(/\s+/);
        if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase();
        return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
}