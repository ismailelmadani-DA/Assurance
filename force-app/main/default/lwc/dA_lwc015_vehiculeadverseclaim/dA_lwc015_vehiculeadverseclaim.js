import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getVehiclesAdverses             from '@salesforce/apex/DA_LWC015_VehiculeAdverseClaimController.getVehiclesAdverses';
import getVehicleAdverseById           from '@salesforce/apex/DA_LWC015_VehiculeAdverseClaimController.getVehicleAdverseById';
import upsertVehiculeAdverse           from '@salesforce/apex/DA_LWC015_VehiculeAdverseClaimController.upsertVehiculeAdverse';
import deleteVehiculeAdverse           from '@salesforce/apex/DA_LWC015_VehiculeAdverseClaimController.deleteVehiculeAdverse';
import getPicklistValues               from '@salesforce/apex/DA_LWC015_VehiculeAdverseClaimController.getPicklistValues';
import getDependentModeleOptions       from '@salesforce/apex/DA_LWC015_VehiculeAdverseClaimController.getDependentModeleOptions';
import getDependentVilleOptions        from '@salesforce/apex/DA_LWC015_VehiculeAdverseClaimController.getDependentVilleOptions';
import getCompagnieAdverseRecordTypeId from '@salesforce/apex/DA_LWC015_VehiculeAdverseClaimController.getCompagnieAdverseRecordTypeId';

const PAGE_SIZE = 10;

const ADVERSAIRE_ASSURE_OPTIONS = [
    { label: 'Oui', value: 'true' },
    { label: 'Non', value: 'false' }
];

const USAGE_OPTIONS = [
    { label: 'Personnel',           value: 'Personnel' },
    { label: 'Commercial',          value: 'Commercial' },
    { label: 'Transport en commun', value: 'Transport en commun' }
];

const TYPE_PERSONNE_OPTIONS = [
    { label: 'Personne physique', value: 'Personne physique' },
    { label: 'Personne morale',   value: 'Personne morale' }
];

// ── Messages d'erreur centralisés ──────────────────────
const ERROR_MESSAGES = {
    etatVehicule:          "Ce champ est obligatoire.",
    immatriculation:       "Ce champ est obligatoire.",
    dateMiseEnCirculation: "Ce champ est obligatoire.",
    adversaireAssure:      "Ce champ est obligatoire.",
    nbPassagerBlesses:     "Ce champ est obligatoire.",
    compagnieAdverseId:    "Ce champ est obligatoire.",
    numeroContrat:         "Ce champ est obligatoire.",
    typePersonne:         "Ce champ est obligatoire.",
    nomCompletTiers:       "Ce champ est obligatoire.",
    cniTiers:              "Ce champ est obligatoire.",
    telephone:             "Ce champ est obligatoire.",
    email:                "Ce champ est obligatoire.",
};

const EMPTY_FORM = () => ({
    assignmentId: '',
    vehiculeId: '',
    etatVehicule: '',
    typeVehicule: '',
    immatriculation: '',
    dateMiseEnCirculation: '',
    marque: '',
    modele: '',
    usage: '',
    nbPassagerBlesses: null,
    adversaireAssure: '',
    compagnieAdverseId: '',
    numeroContrat: '',
    typePersonne: '',
    nomCompletTiers: '',
    cniTiers: '',
    tauxResponsabilite: null,
    moyenNotification: '',
    telephone: '',
    email: '',
    adresse: '',
    ville: '',
    pays: ''
});

const EMPTY_ERRORS = () => ({
    etatVehicule: '',
    immatriculation: '',
    adversaireAssure: '',
    nbPassagerBlesses: '',
    compagnieAdverseId: '',
    numeroContrat: '',
    dateMiseEnCirculation: '',
    typePersonne: '',
    nomCompletTiers: '',
    cniTiers: '',
    telephone: '',
    email: ''
});

export default class DA_lwc015_Vehiculeadverseclaim extends NavigationMixin(LightningElement) {

    @api recordId;
    @api isReadonly = false;

    @track records         = [];
    @track filteredRecords = [];
    @track isLoading       = false;
    @track isFormLoading   = false;
    @track isSaving        = false;
    @track hasError        = false;
    @track errorMessage    = '';

    @track showFormModal   = false;
    @track showDeleteModal = false;
    @track isUpdateMode    = false;

    @track form   = EMPTY_FORM();
    @track errors = EMPTY_ERRORS();

    @track currentPage = 1;

    selectedAssignmentId  = null;
    selectedVehiculeLabel = '';

    @track etatVehiculeOptions  = [];
    @track typeVehiculeOptions  = [];
    @track marqueOptions        = [];
    @track modeleOptions        = [];
    @track notificationOptions  = [];
    @track paysOptions          = [];
    @track villeOptions         = [];

    _dependentModeleOptions = {};
    _dependentVilleOptions  = {};

    @track _compagnieAdverseRtId = null;

    adversaireAssureOptions = ADVERSAIRE_ASSURE_OPTIONS;
    usageOptions            = USAGE_OPTIONS;
    typePersonneOptions     = TYPE_PERSONNE_OPTIONS;

    // ─── Getters ────────────────────────────────────────────────────────────────

    get isMarqueDisabled() { return false; }
    get isModeleDisabled() { return !this.form.marque; }
    get isVilleDisabled()  { return !this.form.pays; }

    get isAdversaireAssureOui() { return this.form.adversaireAssure === 'true'; }
    get isAssuranceRequired()   { return this.isAdversaireAssureOui; }

    get compagnieAdverseFilter() {
        if (!this._compagnieAdverseRtId || this._compagnieAdverseRtId === 'ERROR') {
            return undefined;
        }
        return {
            criteria: [
                {
                    fieldPath: 'RecordTypeId',
                    operator:  'eq',
                    value:     this._compagnieAdverseRtId
                }
            ]
        };
    }

    get isRtLoaded()  { return !!this._compagnieAdverseRtId; }
    get hasRtFilter() { return !!this._compagnieAdverseRtId && this._compagnieAdverseRtId !== 'ERROR'; }

    get isTelephoneRequired() {
        const m = this.form.moyenNotification;
        return m === 'Téléphone' || m === 'Email et Téléphone';
    }

    get isEmailRequired() {
        const m = this.form.moyenNotification;
        return m === 'Email' || m === 'Email et Téléphone';
    }

    get totalPages()     { return Math.max(1, Math.ceil(this.records.length / PAGE_SIZE)); }
    get showPagination() { return this.totalPages > 1; }
    get hasRecords()     { return this.filteredRecords.length > 0; }
    get isFirstPage()    { return this.currentPage === 1; }
    get isLastPage()     { return this.currentPage === this.totalPages; }
    get prevClass()      { return `pm-btn pm-btn--page${this.isFirstPage ? ' pm-btn--disabled' : ''}`; }
    get nextClass()      { return `pm-btn pm-btn--page${this.isLastPage  ? ' pm-btn--disabled' : ''}`; }
    get totalLabel() {
        const n = this.records.length;
        return `${n} véhicule${n > 1 ? 's' : ''} adverse${n > 1 ? 's' : ''}`;
    }

    get modalTitle() { return this.isUpdateMode ? 'Modifier le véhicule adverse' : 'Ajouter un véhicule adverse'; }
    get saveLabel()  { return this.isUpdateMode ? 'Enregistrer' : 'Confirmer'; }

    // ─── Lifecycle ──────────────────────────────────────────────────────────────

    connectedCallback() {
        this.loadPicklists();
        this.loadVehicules();
        this._loadCompagnieAdverseRtId();
    }

    async _loadCompagnieAdverseRtId() {
        try {
            this._compagnieAdverseRtId = await getCompagnieAdverseRecordTypeId();
        } catch (e) {
            console.error('Erreur chargement RecordType Compagnie Adverse :', e);
            this._compagnieAdverseRtId = 'ERROR';
        }
    }

    async loadPicklists() {
        try {
            const [data, depModele, depVille] = await Promise.all([
                getPicklistValues(),
                getDependentModeleOptions(),
                getDependentVilleOptions()
            ]);
            this.etatVehiculeOptions     = data.etatVehicule      || [];
            this.typeVehiculeOptions     = data.typeVehicule      || [];
            this.marqueOptions           = data.marque            || [];
            this.notificationOptions     = data.moyenNotification || [];
            this.paysOptions             = data.pays              || [];
            this._dependentModeleOptions = depModele              || {};
            this._dependentVilleOptions  = depVille               || {};
        } catch (e) {
            console.error('Erreur chargement picklists', e);
        }
    }

    // ─── Chargement liste ───────────────────────────────────────────────────────

    async loadVehicules() {
        if (!this.recordId) return;
        this.isLoading = true;
        this.hasError  = false;
        try {
            const raw = await getVehiclesAdverses({ claimId: this.recordId });
            this.records = raw.map(r => this._enrichRecord(r));
            this._applyFilter();
        } catch (e) {
            this.hasError     = true;
            this.errorMessage = this._cleanError(e);
        } finally {
            this.isLoading = false;
        }
    }

    _enrichRecord(r) {
        const etatClass = {
            'Endommagé':      'pm-state pm-state--blesse',
            'Pas de dommage': 'pm-state pm-state--indemne',
        }[r.EtatVehicule__c] || 'pm-state pm-state--default';

        return {
            ...r,
            etatClass,
            registrationNumber:    r.Vehicule__r?.RegistrationNumber__c || ' ',
            marque:                r.Vehicule__r?.Brand__c || ' ',
            typeVehicule:          r.TypeVehicule__c || ' ',
            nomCompletTiers:       r.Vehicule__r?.ProprietaireDuVehicule__r?.Name || ' ',
            dateMiseEnCirculation: r.DateMiseEnCirculation__c
                ? new Date(r.DateMiseEnCirculation__c + 'T00:00:00').toLocaleDateString('fr-FR')
                : '',
            vehiculeId: r.Vehicule__c || null,
        };
    }

    _applyFilter() {
        this.filteredRecords = this.records.slice(
            (this.currentPage - 1) * PAGE_SIZE,
            this.currentPage * PAGE_SIZE
        );
    }

    prevPage() { if (!this.isFirstPage) { this.currentPage--; this._applyFilter(); } }
    nextPage() { if (!this.isLastPage)  { this.currentPage++; this._applyFilter(); } }

    // ─── Navigation ─────────────────────────────────────────────────────────────

    handleNavigateToVehicule(e) {
        e.preventDefault();
        const vehiculeId = e.currentTarget.dataset.id;
        if (!vehiculeId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId:      vehiculeId,
                objectApiName: 'Vehicule__c',
                actionName:    'view'
            }
        });
    }

    // ─── Ouverture modales ──────────────────────────────────────────────────────

    handleAdd() {
        this.isUpdateMode  = false;
        this.form          = EMPTY_FORM();
        this.errors        = EMPTY_ERRORS();
        this.modeleOptions = [];
        this.villeOptions  = [];
        this.showFormModal = true;
    }

    handleRefresh() { this.loadVehicules(); }

    async handleRowAction(e) {
        const { id, action } = e.currentTarget.dataset;
        if (action === 'edit')   this._openEditModal(id);
        if (action === 'delete') this._openDeleteModal(id);
    }

    async _openEditModal(assignmentId) {
        this.isFormLoading = true;
        this.showFormModal = true;
        this.isUpdateMode  = true;
        this.errors        = EMPTY_ERRORS();
        try {
            const data = await getVehicleAdverseById({ assignmentId });
            this.form = { ...EMPTY_FORM(), ...data, assignmentId };

            if (this.form.marque) {
                this.modeleOptions = this._dependentModeleOptions[this.form.marque] || [];
            } else {
                this.modeleOptions = [];
            }

            if (this.form.pays) {
                this.villeOptions = this._dependentVilleOptions[this.form.pays] || [];
            } else {
                this.villeOptions = [];
            }
        } catch (e) {
            this._toast('Erreur', this._cleanError(e), 'error');
            this.showFormModal = false;
        } finally {
            this.isFormLoading = false;
        }
    }

    _openDeleteModal(assignmentId) {
        this.selectedAssignmentId = assignmentId;
        const rec = this.records.find(r => r.Id === assignmentId);
        this.selectedVehiculeLabel = rec?.registrationNumber || assignmentId;
        this.showDeleteModal = true;
    }

    // ─── Gestion des champs ─────────────────────────────────────────────────────

    handleFieldChange(e) {
        const name  = e.target.name;
        const value = e.target.value;
        this.form = { ...this.form, [name]: value };

        if (name === 'marque') {
            this.modeleOptions = this._dependentModeleOptions[value] || [];
            this.form = { ...this.form, modele: '' };
        }

        if (name === 'pays') {
            this.villeOptions = this._dependentVilleOptions[value] || [];
            this.form = { ...this.form, ville: '' };
        }

        if (name === 'adversaireAssure' && value === 'false') {
            this.form   = { ...this.form,   compagnieAdverseId: '', numeroContrat: '' };
            this.errors = { ...this.errors, compagnieAdverseId: '', numeroContrat: '' };
        }

        if (name === 'moyenNotification') {
            this.errors = { ...this.errors, telephone: '', email: '' };
        }

        if (this.errors[name] !== undefined) {
            this.errors = { ...this.errors, [name]: '' };
        }
    }

    handleFieldBlur(e) {
        const name  = e.target.name;
        const value = e.target.value;

        // Pour nbPassagerBlesses, vérifier null aussi
        const isEmpty = name === 'nbPassagerBlesses'
            ? (value === null || value === '' || value === undefined)
            : !value?.trim();

        if (ERROR_MESSAGES[name] && isEmpty) {
            this.errors = { ...this.errors, [name]: ERROR_MESSAGES[name] };
        }
    }

    handleLookupChange(e) {
        const id = e.detail?.recordId || '';
        this.form = { ...this.form, compagnieAdverseId: id };
        if (id) {
            this.errors = { ...this.errors, compagnieAdverseId: '' };
        } else if (this.isAssuranceRequired) {
            this.errors = { ...this.errors, compagnieAdverseId: ERROR_MESSAGES.compagnieAdverseId };
        }
    }

    handleFormSubmit(e) { e.preventDefault(); }

    // ─── Validation ─────────────────────────────────────────────────────────────

    _validate() {
        const e = EMPTY_ERRORS();
        let ok = true;

        if (!this.form.etatVehicule)
            { e.etatVehicule = ERROR_MESSAGES.etatVehicule; ok = false; }
        if (!this.form.immatriculation?.trim())
            { e.immatriculation = ERROR_MESSAGES.immatriculation; ok = false; }
        if (!this.form.dateMiseEnCirculation)
            { e.dateMiseEnCirculation = ERROR_MESSAGES.dateMiseEnCirculation; ok = false; }
        if (!this.form.adversaireAssure)
            { e.adversaireAssure = ERROR_MESSAGES.adversaireAssure; ok = false; }
        if (this.form.nbPassagerBlesses === null || this.form.nbPassagerBlesses === '')
            { e.nbPassagerBlesses = ERROR_MESSAGES.nbPassagerBlesses; ok = false; }

        if (this.isAdversaireAssureOui) {
            if (!this.form.compagnieAdverseId)
                { e.compagnieAdverseId = ERROR_MESSAGES.compagnieAdverseId; ok = false; }
            if (!this.form.numeroContrat?.trim())
                { e.numeroContrat = ERROR_MESSAGES.numeroContrat; ok = false; }
        }

        if (!this.form.typePersonne)
            { e.typePersonne = ERROR_MESSAGES.typePersonne; ok = false; }
        if (!this.form.nomCompletTiers?.trim())
            { e.nomCompletTiers = ERROR_MESSAGES.nomCompletTiers; ok = false; }
        if (!this.form.cniTiers?.trim())
            { e.cniTiers = ERROR_MESSAGES.cniTiers; ok = false; }

        if (this.isTelephoneRequired && !this.form.telephone?.trim())
            { e.telephone = ERROR_MESSAGES.telephone; ok = false; }
        if (this.isEmailRequired && !this.form.email?.trim())
            { e.email = ERROR_MESSAGES.email; ok = false; }

        this.errors = e;
        return ok;
    }

    // ─── Sauvegarde ─────────────────────────────────────────────────────────────

    async handleSave() {
        if (!this._validate()) {
            this._scrollToFirstError();
            return;
        }
        this.isSaving = true;
        try {
            const result = await upsertVehiculeAdverse({
                formData:     this.form,
                claimId:      this.recordId,
                isUpdateMode: this.isUpdateMode
            });
            if (result.success) {
                this._toast('Succès', result.message, 'success');
                this.closeModal();
                await this.loadVehicules();
            } else if (result.fieldError === 'dateMiseEnCirculation') {
                this.errors = { ...this.errors, dateMiseEnCirculation: result.message };
                this._scrollToFirstError();
            } else {
                this._toast('Erreur', result.message, 'error', 'sticky');
            }
        } catch (e) {
            this._toast('Erreur', this._cleanError(e), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    _scrollToFirstError() {
        setTimeout(() => {
            const firstError = this.template.querySelector('.pm-error');
            if (firstError) {
                firstError.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
        }, 50);
    }

    // ─── Suppression ────────────────────────────────────────────────────────────

    async confirmDelete() {
        this.isSaving = true;
        try {
            const result = await deleteVehiculeAdverse({ assignmentId: this.selectedAssignmentId });
            if (result.success) {
                this._toast('Succès', result.message, 'success');
                this.closeDeleteModal();
                await this.loadVehicules();
            } else {
                this._toast('Erreur', result.message, 'error');
            }
        } catch (e) {
            this._toast('Erreur', this._cleanError(e), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // ─── Helpers ────────────────────────────────────────────────────────────────

    closeModal()          { this.showFormModal   = false; }
    closeDeleteModal()    { this.showDeleteModal = false; }
    handleOverlayClick(e) { if (e.target === e.currentTarget) this.closeModal(); }
    stopPropagation(e)    { e.stopPropagation(); }

    _cleanError(e) {
        const raw = e?.body?.message || e?.message || '';
        if (!raw || raw.includes('FIELD_INTEGRITY') || raw.includes('EXCEPTION')) {
            return 'Une erreur est survenue lors du traitement. Veuillez réessayer.';
        }
        if (raw.includes('INSUFFICIENT_ACCESS')) {
            return "Vous n'avez pas les droits nécessaires pour effectuer cette action.";
        }
        if (raw.includes('DUPLICATE_VALUE')) {
            return 'Un enregistrement avec ces informations existe déjà.';
        }
        return raw;
    }

    _toast(title, message, variant, mode = 'dismissable') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
    }
}