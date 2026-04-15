import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getAdverseVehicles from '@salesforce/apex/DA_PassagerAdverseController.getAdverseVehicles';
import getParticipants from '@salesforce/apex/DA_PassagerAdverseController.getParticipants';
import getParticipantById from '@salesforce/apex/DA_PassagerAdverseController.getParticipantById';
import upsertPassager from '@salesforce/apex/DA_PassagerAdverseController.upsertPassager';
import deletePassager from '@salesforce/apex/DA_PassagerAdverseController.deletePassager';
import checkDuplicate from '@salesforce/apex/DA_PassagerAdverseController.checkDuplicate';

const PAGE_SIZE = 10;

const CIVILITY_OPTIONS = [
    { label: 'Mr', value: 'Mr' },
    { label: 'Mme', value: 'Mme' }
];

const SEXE_OPTIONS = [
    { label: 'Male', value: 'Male' },
    { label: 'Femelle', value: 'Femelle' }
];

const CIVILITY_SEX_MAP = { Mr: 'Male', Mme: 'Femelle' };

const SITUATION_OPTIONS = [
    { label: 'Célibataire', value: 'Célibataire' },
    { label: 'Marié(e)', value: 'Marié(e)' },
    { label: 'Divorcé(e)', value: 'Divorcé(e)' },
    { label: 'Séparé(e)', value: 'Séparé(e)' }
];

const NOTIFICATION_OPTIONS = [
    { label: 'Email', value: 'Email' },
    { label: 'SMS', value: 'SMS' },
    { label: 'Téléphone', value: 'Téléphone' }
];

const PAYS_OPTIONS = [
    { label: 'Maroc', value: 'Maroc' }
];

const VILLE_OPTIONS = [
    'Casablanca','Rabat','Fes','Marrakech','Agadir','Tanger','Meknes','Oujda',
    'Kenitra','Tetouan','Safi','Mohammedia','Khouribga','Beni Mellal','El Jadida',
    'Nador','Taza','Settat','Berrechid','Khemisset','Inezgane','Ksar El Kebir',
    'Larache','Guelmim','Berkane','Taourirt','Sidi Slimane','Sidi Kacem',
    'Al Hoceima','Tiznit','Tan-Tan','Taroudant','Ouarzazate','Errachidia',
    'Ifrane','Azrou','Midelt','Tinghir','Zagora','Dakhla','Laayoune',
    'Chefchaouen','Temara','Sale','Sefrou'
].map(v => ({ label: v, value: v }));

const ETAT_OPTIONS = [
    { label: 'Indemne', value: 'Indemne' },
    { label: 'Blessé', value: 'Blessé' },
    { label: 'Décédé', value: 'Décédé' }
];

const EMPTY_FORM = () => ({
    participantId: '',
    vehiculeId: '',
    nom: '',
    prenom: '',
    civility: '',
    sexe: '',
    dateNaissance: '',
    cni: '',
    situationFamiliale: '',
    typeContact: '',
    contactValue: '',
    pays: '',
    ville: '',
    adresse: '',
    etatPassager: '',
    itt: null,
    ipp: null,
    dateDeces: '',
    revenuAnnuel: null,
    conducteur: false,
    isOwner: false
});

const EMPTY_ERRORS = () => ({
    nom: '', prenom: '', civility: '', cni: '',
    pays: '', ville: '', etatPassager: ''
});

export default class DA_lwc010_PassagerAdverse extends LightningElement {

    @api recordId;
    @api isReadonly = false;

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
    @track vehicleOptions = [];

    @track currentPage = 1;

    selectedParticipantId = null;
    selectedParticipantName = '';

    civiliteOptions = CIVILITY_OPTIONS;
    sexeOptions = SEXE_OPTIONS;
    situationFamilialeOptions = SITUATION_OPTIONS;
    notificationOptions = NOTIFICATION_OPTIONS;
    paysOptions = PAYS_OPTIONS;
    villeOptions = VILLE_OPTIONS;
    etatPassagerOptions = ETAT_OPTIONS;

    connectedCallback() {
        this.loadParticipants();
        this.loadVehicles();
    }

    async loadVehicles() {
        try {
            const raw = await getAdverseVehicles({ claimId: this.recordId });
            this.vehicleOptions = raw.map(v => ({
                label: (v.RegistrationNumber__c || v.Vehicule__r?.RegistrationNumber__c || '') +
                       (v.Marque__c || v.Vehicule__r?.Brand__c ? ' - ' + (v.Marque__c || v.Vehicule__r?.Brand__c) : ''),
                value: v.Vehicule__c || v.Id
            }));
        } catch (e) {
            console.error('loadVehicles error', e);
        }
    }

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
            this.errorMessage = this._cleanError(e);
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

        return {
            ...r,
            stateClass,
            civility: r.ParticipantAccount__r?.Civility__c || '',
            accountName: r.ParticipantAccount__r?.Name || '',
            vehicleName: r.Vehicule__r?.RegistrationNumber__c || '',
            participantUrl: `/lightning/r/ClaimParticipant__c/${r.Id}/view`,
        };
    }

    _applyFilter() {
        this.filteredRecords = this.records.slice(
            (this.currentPage - 1) * PAGE_SIZE,
            this.currentPage * PAGE_SIZE
        );
    }

    get totalPages() { return Math.max(1, Math.ceil(this.records.length / PAGE_SIZE)); }
    get showPagination() { return this.totalPages > 1; }
    get hasRecords() { return this.filteredRecords.length > 0; }
    get isFirstPage() { return this.currentPage === 1; }
    get isLastPage() { return this.currentPage === this.totalPages; }
    get prevClass() { return `pm-btn pm-btn--page${this.isFirstPage ? ' pm-btn--disabled' : ''}`; }
    get nextClass() { return `pm-btn pm-btn--page${this.isLastPage ? ' pm-btn--disabled' : ''}`; }
    get totalLabel() { return `${this.records.length} passager${this.records.length > 1 ? 's' : ''} adverse${this.records.length > 1 ? 's' : ''}`; }

    prevPage() { if (!this.isFirstPage) { this.currentPage--; this._applyFilter(); } }
    nextPage() { if (!this.isLastPage) { this.currentPage++; this._applyFilter(); } }

    get isVilleDisabled() { return !this.form.pays; }
    get showIttIpp() { return this.form.etatPassager === 'Blessé'; }
    get showDecesFields() { return this.form.etatPassager === 'Décédé'; }
    get showContactField() { return !!this.form.typeContact; }
    get modalTitle() { return this.isUpdateMode ? 'Modifier le passager adverse' : 'Ajouter un passager adverse'; }
    get saveLabel() { return this.isUpdateMode ? 'Enregistrer les modifications' : 'Confirmer'; }

    handleAdd() {
        this.isUpdateMode = false;
        this.form = EMPTY_FORM();
        this.errors = EMPTY_ERRORS();
        this.showFormModal = true;
    }

    handleRefresh() { this.loadParticipants(); }

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
            this.form = { ...EMPTY_FORM(), ...data, participantId };
        } catch (e) {
            this._toast('Erreur', this._cleanError(e), 'error');
            this.showFormModal = false;
        } finally {
            this.isFormLoading = false;
        }
    }

    _openDeleteModal(participantId) {
        this.selectedParticipantId = participantId;
        const rec = this.records.find(r => r.Id === participantId);
        this.selectedParticipantName = rec?.accountName || participantId;
        this.showDeleteModal = true;
    }

    handleFieldChange(e) {
        const name = e.target.name;
        const value = e.target.value;
        this.form = { ...this.form, [name]: value };

        if (name === 'civility' && CIVILITY_SEX_MAP[value]) {
            this.form = { ...this.form, sexe: CIVILITY_SEX_MAP[value] };
        }
        if (name === 'pays') {
            this.form = { ...this.form, ville: '' };
        }
        if (this.errors[name] !== undefined) {
            this.errors = { ...this.errors, [name]: '' };
        }
    }

    handleCheckbox(e) {
        this.form = { ...this.form, [e.target.name]: e.target.checked };
    }

    handleFormSubmit(e) { e.preventDefault(); }

    _validate() {
        const e = EMPTY_ERRORS();
        let ok = true;

        if (!this.form.nom?.trim()) { e.nom = 'Obligatoire'; ok = false; }
        if (!this.form.prenom?.trim()) { e.prenom = 'Obligatoire'; ok = false; }
        if (!this.form.civility) { e.civility = 'Obligatoire'; ok = false; }
        if (!this.form.cni?.trim()) { e.cni = 'Obligatoire'; ok = false; }
        if (!this.form.pays) { e.pays = 'Obligatoire'; ok = false; }
        if (!this.form.ville) { e.ville = 'Obligatoire'; ok = false; }
        if (!this.form.etatPassager) { e.etatPassager = 'Obligatoire'; ok = false; }

        this.errors = e;
        return ok;
    }

    async handleSave() {
        if (!this._validate()) return;
        this.isSaving = true;
        try {
            if (!this.isUpdateMode) {
                const isDup = await checkDuplicate({
                    nom: this.form.nom,
                    prenom: this.form.prenom,
                    claimId: this.recordId,
                    excludeId: null,
                });
                if (isDup) {
                    this._toast('Doublon détecté', `Un passager adverse "${this.form.nom} ${this.form.prenom}" existe déjà.`, 'warning', 'sticky');
                    this.isSaving = false;
                    return;
                }
            }

            const result = await upsertPassager({
                formData: this.form,
                claimId: this.recordId,
                isUpdateMode: this.isUpdateMode,
            });

            if (result.success) {
                this._toast('Succès', result.message, 'success');
                this.closeModal();
                await this.loadParticipants();
            } else {
                this._toast('Erreur', result.message, 'error', 'sticky');
            }
        } catch (e) {
            this._toast('Erreur', this._cleanError(e), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async confirmDelete() {
        this.isSaving = true;
        try {
            const result = await deletePassager({ participantId: this.selectedParticipantId });
            if (result.success) {
                this._toast('Succès', result.message, 'success');
                this.closeDeleteModal();
                await this.loadParticipants();
            } else {
                this._toast('Erreur', result.message, 'error');
            }
        } catch (e) {
            this._toast('Erreur', this._cleanError(e), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    closeModal() { this.showFormModal = false; }
    closeDeleteModal() { this.showDeleteModal = false; }
    handleOverlayClick(e) { if (e.target === e.currentTarget) this.closeModal(); }
    stopPropagation(e) { e.stopPropagation(); }

    _cleanError(e) {
        const raw = e?.body?.message || e?.message || '';
        if (!raw || raw.includes('FIELD_INTEGRITY') || raw.includes('EXCEPTION') || raw.includes('first error')) {
            return 'Une erreur est survenue lors du traitement. Veuillez réessayer.';
        }
        if (raw.includes('INSUFFICIENT_ACCESS')) {
            return 'Vous n\'avez pas les droits nécessaires pour effectuer cette action.';
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
