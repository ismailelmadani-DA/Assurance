import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
// import CIVILITE_FIELD from '@salesforce/schema/Account.Civilite__c';
// import CITY_FIELD from '@salesforce/schema/Account.Ville__c';
// import COUNTRY_FIELD from '@salesforce/schema/Account.Pays__c';
// import SEXE_FIELD from '@salesforce/schema/Account.Sexe__c';
// import MARITAL_STATUS_FIELD from '@salesforce/schema/Account.MaritalStatus__c';
import STATE_OF_PERSON_FIELD from '@salesforce/schema/Account.ConditionOfPerson__c';
// import TYPE_CONTACT_FIELD from '@salesforce/schema/Account.TypeContact__c';

import getParticipants from '@salesforce/apex/DA_PassagerAssureController.getParticipants';
import getParticipantById from '@salesforce/apex/DA_PassagerAssureController.getParticipantById';
import upsertPassager from '@salesforce/apex/DA_PassagerAssureController.upsertPassager';
import deletePassager from '@salesforce/apex/DA_PassagerAssureController.deletePassager';
import checkDuplicate from '@salesforce/apex/DA_PassagerAssureController.checkDuplicate';

/* ── constantes ── */
const PAGE_SIZE = 10;

const ROLES_OPTIONS = [
    { label: 'Passager assuré', value: 'Passager assuré' },
    { label: 'Partie adverse', value: 'Partie adverse' },
    { label: 'Conducteur assuré', value: 'Conducteur assuré' },
    { label: 'Piéton', value: 'Piéton' },
];

const CIVILITY_SEX_MAP = { Mr: '1', Mme: '2' };

const EMPTY_FORM = () => ({
    participantId: '',
    accountId: '',
    roles: '',
    civility: '',
    sexe: '',
    nom: '',
    prenom: '',
    dateNaissance: '',
    cni: '',
    situationFamiliale: '',
    pays: '',
    ville: '',
    adresse: '',
    typeContact: '',
    telephone: '',
    email: '',
    etatPassager: '',
    compagnieAdverse: '',
    itt: null,
    ipp: null,
    dateDeces: '',
    revenuAnnuel: null,
    conducteur: false,
});

const EMPTY_ERRORS = () => ({
    roles: '', civility: '', nom: '', prenom: '', cni: '',
    pays: '', ville: '', etatPassager: '',
    telephone: '', email: '', dateNaissance: '', dateDeces: '',
});

export default class PassagerManager extends LightningElement {

    /** Id du sinistre (obligatoire) */
    @api recordId;
    /** Id du véhicule lié (optionnel) */
    @api vehiculeId;
    /** Mode lecture seule */
    @api isReadonly = false;
    /** Nombre de conducteurs déjà enregistrés (pour désactiver la checkbox) */
    @api driverCount = 0;

    /* ─── état interne ─── */
    @track records = [];
    @track filteredRecords = [];
    @track isLoading = false;
    @track isFormLoading = false;
    @track isSaving = false;
    @track hasError = false;
    @track errorMessage = '';

    @track showFormModal = false;
    @track showDeleteModal = false;
    @track isUpdateMode = false;

    @track form = EMPTY_FORM();
    @track errors = EMPTY_ERRORS();

    @track activeFilter = 'all';
    @track currentPage = 1;

    selectedParticipantId = null;
    selectedParticipantName = '';

    /* ─── picklists depuis schema Account ─── */
    @track passagersRecordTypeId;
    // @track civiliteOptions = [];
    // @track sexeOptions = [];
    // @track paysOptions = [];
    // @track allCityOptions = [];
    // @track filteredCityOptions = [];
    // @track situationFamilialeOptions = [];
    @track etatPassagerOptions = [];
    // @track typeContactOptions = [];
    rolesOptions = ROLES_OPTIONS;

    /* ══════════════════════════════════════
       LIFECYCLE
    ══════════════════════════════════════ */
    connectedCallback() {
        this.loadParticipants();
    }

    /* ══════════════════════════════════════
       WIRE – Object info & picklists
    ══════════════════════════════════════ */
    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    wiredAccountInfo({ data, error }) {
        if (data) {
            const rtis = data.recordTypeInfos;
            this.passagersRecordTypeId = Object.keys(rtis).find(
                id => rtis[id].name === 'Passagers'
            );
        }
        if (error) console.error('getObjectInfo error', error);
    }

        @wire(getPicklistValues, { recordTypeId: '$passagersRecordTypeId', fieldApiName: STATE_OF_PERSON_FIELD })
    wiredState({ data }) { if (data) this.etatPassagerOptions = data.values; }

    /* ══════════════════════════════════════
       CHARGEMENT DONNÉES
    ══════════════════════════════════════ */
    async loadParticipants() {
        if (!this.recordId) return;
        this.isLoading = true;
        this.hasError = false;
        try {
            const raw = await getParticipants({ claimId: this.recordId });
            this.records = raw.map(r => this._enrichRecord(r));
            this._applyFilter();
        } catch (e) {
            this.hasError = true;
            this.errorMessage = e.body?.message || e.message || 'Erreur de chargement';
        } finally {
            this.isLoading = false;
        }
    }

    _enrichRecord(r) {
        const stateClass = {
            'Blessé': 'pm-state pm-state--blesse',
            'Décédé': 'pm-state pm-state--deces',
            'Indemne': 'pm-state pm-state--indemne',
        }[r.StateOfPerson__c] || 'pm-state pm-state--default';

        const roleClass = (r.Roles__c || '').includes('adverse')
            ? 'pm-role pm-role--adverse'
            : 'pm-role pm-role--assure';

        return {
            ...r,
            stateClass,
            roleClass,
            civility: r.ParticipantAccount__r?.Civility__c || '',
            accountName: r.ParticipantAccount__r?.Name || '',
            participantUrl: `/lightning/r/ClaimParticipant__c/${r.Id}/view`,
        };
    }

    /* ══════════════════════════════════════
       FILTRES & PAGINATION
    ══════════════════════════════════════ */
    _applyFilter() {
        const base = this.activeFilter === 'all'
            ? [...this.records]
            : this.records.filter(r => r.Roles__c === this.activeFilter);
        this.filteredRecords = base.slice(
            (this.currentPage - 1) * PAGE_SIZE,
            this.currentPage * PAGE_SIZE
        );
    }

    get totalPages() {
        const base = this.activeFilter === 'all' ? this.records : this.records.filter(r => r.Roles__c === this.activeFilter);
        return Math.max(1, Math.ceil(base.length / PAGE_SIZE));
    }

    get showPagination() { return this.totalPages > 1; }
    get hasRecords() { return this.filteredRecords.length > 0; }
    get isFirstPage() { return this.currentPage === 1; }
    get isLastPage() { return this.currentPage === this.totalPages; }
    get prevClass() { return `pm-btn pm-btn--page${this.isFirstPage ? ' pm-btn--disabled' : ''}`; }
    get nextClass() { return `pm-btn pm-btn--page${this.isLastPage ? ' pm-btn--disabled' : ''}`; }
    get totalLabel() { return `${this.records.length} passager${this.records.length > 1 ? 's' : ''}`; }

    get pillAllClass() { return `pm-pill${this.activeFilter === 'all' ? ' pm-pill--active' : ''}`; }
    get pillAssureClass() { return `pm-pill${this.activeFilter === 'Passager assuré' ? ' pm-pill--active' : ''}`; }
    get pillAdverseClass() { return `pm-pill${this.activeFilter === 'Partie adverse' ? ' pm-pill--active' : ''}`; }

    filterAll() { this.activeFilter = 'all'; this.currentPage = 1; this._applyFilter(); }
    filterRole(e) { this.activeFilter = e.target.dataset.role; this.currentPage = 1; this._applyFilter(); }
    prevPage() { if (!this.isFirstPage) { this.currentPage--; this._applyFilter(); } }
    nextPage() { if (!this.isLastPage) { this.currentPage++; this._applyFilter(); } }

    /* ══════════════════════════════════════
       FORMULAIRE – helpers getters
    ══════════════════════════════════════ */
    get showIttIpp() { return this.form.etatPassager === 'Blessé'; }
    get showDecesFields() { return this.form.etatPassager === 'Décédé'; }
    get isAdverse() { return (this.form.roles || '').toLowerCase().includes('adverse'); }
    get isPhoneRequired() { return this.form.typeContact === 'Téléphone'; }
    get isEmailRequired() { return this.form.typeContact === 'Mail'; }
    get isDriverDisabled() { return this.driverCount >= 1 && !this.form.conducteur; }
    get modalTitle() { return this.isUpdateMode ? 'Modifier le passager' : 'Ajouter un passager'; }
    get saveLabel() { return this.isUpdateMode ? 'Enregistrer les modifications' : 'Ajouter le passager'; }

    /* ══════════════════════════════════════
       ACTIONS HEADER
    ══════════════════════════════════════ */
    handleAdd() {
        this.isUpdateMode = false;
        this.form = EMPTY_FORM();
        this.errors = EMPTY_ERRORS();
        this.filteredCityOptions = [];
        this.showFormModal = true;
    }

    handleRefresh() { this.loadParticipants(); }

    /* ══════════════════════════════════════
       ACTIONS LIGNES
    ══════════════════════════════════════ */
    async handleRowAction(e) {
        const { id, action } = e.currentTarget.dataset;
        if (action === 'edit') this._openEditModal(id);
        if (action === 'delete') this._openDeleteModal(id);
    }

    async _openEditModal(participantId) {
        this.isFormLoading = true;
        this.showFormModal = true;
        this.isUpdateMode = true;
        this.errors = EMPTY_ERRORS();
        try {
            const data = await getParticipantById({ participantId });
            const fmtDate = v => {
                if (!v) return '';
                // Format dd/mm/yyyy → yyyy-mm-dd
                if (/^\d{2}\/\d{2}\/\d{4}$/.test(v)) {
                    const [d, m, y] = v.split('/');
                    return `${y}-${m}-${d}`;
                }
                return v;
            };
            this.form = {
                ...EMPTY_FORM(),
                ...data,
                participantId,
                dateNaissance: fmtDate(data.dateNaissance),
                dateDeces: fmtDate(data.dateDeces),
            };
            this._updateCityOptions();
        } catch (e) {
            this._toast('Erreur', 'Impossible de charger les données du passager', 'error');
            this.showFormModal = false;
        } finally {
            this.isFormLoading = false;
        }
    }

    _openDeleteModal(participantId) {
        this.selectedParticipantId = participantId;
        const rec = this.records.find(r => r.Id === participantId);
        this.selectedParticipantName = rec?.accountName || rec?.ParticipantAccount__r?.Name || participantId;
        this.showDeleteModal = true;
    }

    /* ══════════════════════════════════════
       HANDLERS CHAMPS FORMULAIRE
    ══════════════════════════════════════ */
    handleFieldChange(e) {
        const name = e.target.name;
        const value = e.target.value;
        this.form = { ...this.form, [name]: value };

        // Civility → auto sexe
        if (name === 'civility' && CIVILITY_SEX_MAP[value]) {
            this.form = { ...this.form, sexe: CIVILITY_SEX_MAP[value] };
        }
        // Pays → reset ville + filtrer villes
        if (name === 'pays') {
            this.form = { ...this.form, ville: '' };
            this._updateCityOptions();
        }
        // Réinitialiser erreur du champ
        if (this.errors[name] !== undefined) {
            this.errors = { ...this.errors, [name]: '' };
        }
    }

    handleCheckbox(e) {
        this.form = { ...this.form, conducteur: e.target.checked };
    }

    handleFormSubmit(e) { e.preventDefault(); }

    _updateCityOptions() {
        if (!this.form.pays || !this.allCityOptions.length) {
            this.filteredCityOptions = [];
            return;
        }
        const idx = this.paysOptions.findIndex(p => p.value === this.form.pays);
        this.filteredCityOptions = this.allCityOptions.filter(c => c.validFor?.includes(idx));
    }

    /* ══════════════════════════════════════
       VALIDATION
    ══════════════════════════════════════ */
    _validate() {
        const e = EMPTY_ERRORS();
        let ok = true;

        if (!this.form.roles) { e.roles = 'Obligatoire'; ok = false; }
        if (!this.form.civility) { e.civility = 'Obligatoire'; ok = false; }
        if (!this.form.nom?.trim()) { e.nom = 'Obligatoire'; ok = false; }
        if (!this.form.prenom?.trim()) { e.prenom = 'Obligatoire'; ok = false; }
        if (!this.form.pays) { e.pays = 'Obligatoire'; ok = false; }
        if (this.form.pays && !this.form.ville) { e.ville = 'Obligatoire'; ok = false; }
        if (!this.form.cni?.trim()) { e.cni = 'Le CNI est obligatoire'; ok = false; }
        if (!this.form.etatPassager) { e.etatPassager = 'Obligatoire'; ok = false; }

        if ((this.form.nom?.trim().length || 0) + (this.form.prenom?.trim().length || 0) > 35) {
            this._toast('Validation', 'Le nom complet dépasse 35 caractères', 'warning');
            ok = false;
        }

        if (this.isPhoneRequired && !this.form.telephone) {
            e.telephone = 'Obligatoire (notification par téléphone)'; ok = false;
        }
        if (this.isEmailRequired && !this.form.email) {
            e.email = 'Obligatoire (notification par mail)'; ok = false;
        }
        if (this.form.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.form.email)) {
            e.email = 'Format email invalide'; ok = false;
        }

        this.errors = e;
        return ok;
    }

    /* ══════════════════════════════════════
       SAUVEGARDER
    ══════════════════════════════════════ */
    async handleSave() {
        if (!this._validate()) return;
        this.isSaving = true;
        try {
            // Vérification doublon (seulement en création)
            if (!this.isUpdateMode) {
                const isDup = await checkDuplicate({
                    nom: this.form.nom,
                    prenom: this.form.prenom,
                    claimId: this.recordId,
                    excludeId: null,
                });
                if (isDup) {
                    this._toast('Doublon détecté', `Un passager "${this.form.nom} ${this.form.prenom}" existe déjà sur ce sinistre.`, 'warning', 'sticky');
                    this.isSaving = false;
                    return;
                }
            }

            const result = await upsertPassager({
                formData: this.form,
                claimId: this.recordId,
                vehiculeId: this.vehiculeId || null,
                isUpdateMode: this.isUpdateMode,
            });

            if (result.success) {
                this._toast('Succès', result.message, 'success');
                this.closeModal();
                await this.loadParticipants();
                this.dispatchEvent(new CustomEvent('refresh'));
            } else {
                this._toast('Erreur', result.message, 'error', 'sticky');
            }
        } catch (e) {
            this._toast('Erreur', e.body?.message || e.message || 'Erreur inconnue', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    /* ══════════════════════════════════════
       SUPPRIMER
    ══════════════════════════════════════ */
    async confirmDelete() {
        this.isSaving = true;
        try {
            const result = await deletePassager({ participantId: this.selectedParticipantId });
            if (result.success) {
                this._toast('Succès', result.message, 'success');
                this.closeDeleteModal();
                await this.loadParticipants();
                this.dispatchEvent(new CustomEvent('refresh'));
            } else {
                this._toast('Erreur', result.message, 'error');
            }
        } catch (e) {
            this._toast('Erreur', e.body?.message || e.message || 'Erreur inconnue', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    /* ══════════════════════════════════════
       FERMETURE MODALES
    ══════════════════════════════════════ */
    closeModal() { this.showFormModal = false; }
    closeDeleteModal() { this.showDeleteModal = false; }

    handleOverlayClick(e) {
        if (e.target === e.currentTarget) this.closeModal();
    }
    stopPropagation(e) { e.stopPropagation(); }

    /* ══════════════════════════════════════
       TOAST HELPER
    ══════════════════════════════════════ */
    _toast(title, message, variant, mode = 'dismissable') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
    }
}