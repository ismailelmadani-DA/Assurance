import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import CASE_CREATED_DATE from '@salesforce/schema/Case.CreatedDate';

import CLAIM_PARTICIPANT_OBJECT from '@salesforce/schema/ClaimParticipant__c';
import PAYS_FIELD from '@salesforce/schema/ClaimParticipant__c.Pays__c';
import VILLE_FIELD from '@salesforce/schema/ClaimParticipant__c.Ville__c';
import STATE_OF_PERSON_FIELD from '@salesforce/schema/ClaimParticipant__c.StateOfPerson__c';
import SEXE_FIELD from '@salesforce/schema/ClaimParticipant__c.Sexe__c';
import MARITAL_STATUS_FIELD from '@salesforce/schema/ClaimParticipant__c.MaritalStatus__c';
import TYPE_CONTACT_FIELD from '@salesforce/schema/ClaimParticipant__c.TypeContact__c';
import TYPE_PARTIE_ADVERSE_FIELD from '@salesforce/schema/ClaimParticipant__c.TypePartieAdverse__c';
import PAYS_COMPAGNIE_FIELD from '@salesforce/schema/ClaimParticipant__c.PaysCompagnieAdverse__c';
import CIVILITE_FIELD from '@salesforce/schema/ClaimParticipant__c.Civilite__c';

import getParticipants from '@salesforce/apex/DA_AutrePartieAdverseController.getParticipants';
import getParticipantById from '@salesforce/apex/DA_AutrePartieAdverseController.getParticipantById';
import upsertPartie from '@salesforce/apex/DA_AutrePartieAdverseController.upsertPartie';
import deletePartie from '@salesforce/apex/DA_AutrePartieAdverseController.deletePartie';
import checkDuplicate from '@salesforce/apex/DA_AutrePartieAdverseController.checkDuplicate';
import searchCompagnies from '@salesforce/apex/DA_AutrePartieAdverseController.searchCompagnies';
import resolveAccountByCIN from '@salesforce/apex/DA_PassagerController.resolveAccountByCIN';

const PAGE_SIZE = 10;

const ETAT_ALLOWED = {
    'Indemne': ['Indemne', 'Blessé', 'Décédé'],
    'Blessé': ['Blessé', 'Décédé'],
    'Décédé': ['Décédé']
};

const EMPTY_FORM = () => ({
    participantId: '',
    typePartieAdverse: '',
    nomComplet: '',
    civility: '',
    sexe: '',
    dateNaissance: '',
    cin: '',
    situationFamiliale: '',
    pays: '',
    ville: '',
    adresse: '',
    etatPassager: '',
    compagnieAdverseId: '',
    paysCompagnieAdverse: '',
    numeroContrat: '',
    typeContact: '',
    email: '',
    telephone: '',
    itt: null,
    ipp: null,
    dateDeces: '',
    revenuAnnuel: null,
    description: ''
});

const EMPTY_ERRORS = () => ({
    typePartieAdverse: '', nomComplet: '', civility: '',
    pays: '', ville: '', etatPassager: '',
    paysCompagnieAdverse: '',
    email: '', telephone: '',
    itt: '', ipp: '',
    dateNaissance: '', dateDeces: '', revenuAnnuel: ''
});

export default class DA_lwc011_AutrePartieAdverse extends NavigationMixin(LightningElement) {

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
    @track isUpdateMode = false;
    @track originalEtatPassager = '';

    @track showDeleteModal = false;
    @track deleteRecordId = null;
    @track deleteRecordName = '';
    @track isDeleting = false;

    @track form = EMPTY_FORM();
    @track errors = EMPTY_ERRORS();

    @track currentPage = 1;

    // Picklist options from wire
    @track typePartieOptions = [];
    @track sexeOptions = [];
    @track situationFamilialeOptions = [];
    @track paysOptions = [];
    @track allVilleOptions = [];
    @track filteredVilleOptions = [];
    @track etatOptions = [];
    @track paysCompagnieOptions = [];
    @track typeContactOptions = [];
    @track civiliteOptions = [];

    // Compagnie adverse lookup
    @track compagnieSearchTerm = '';
    @track showCompagnieDropdown = false;
    @track compagnieSearchResults = [];
    @track selectedCompagnieName = '';

    /* ══════════════════════════════════════
       WIRE - Object info & picklists
    ══════════════════════════════════════ */
    @wire(getObjectInfo, { objectApiName: CLAIM_PARTICIPANT_OBJECT })
    claimParticipantInfo;

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantInfo.data.defaultRecordTypeId', fieldApiName: TYPE_PARTIE_ADVERSE_FIELD })
    wiredTypePartie({ data, error }) {
        if (data) this.typePartieOptions = data.values;
        if (error) console.error('TypePartieAdverse picklist error', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantInfo.data.defaultRecordTypeId', fieldApiName: SEXE_FIELD })
    wiredSexe({ data, error }) {
        if (data) this.sexeOptions = data.values;
        if (error) console.error('Sexe picklist error', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantInfo.data.defaultRecordTypeId', fieldApiName: MARITAL_STATUS_FIELD })
    wiredMarital({ data, error }) {
        if (data) this.situationFamilialeOptions = data.values;
        if (error) console.error('MaritalStatus picklist error', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantInfo.data.defaultRecordTypeId', fieldApiName: PAYS_FIELD })
    wiredPays({ data, error }) {
        if (data) this.paysOptions = data.values;
        if (error) console.error('Pays picklist error', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantInfo.data.defaultRecordTypeId', fieldApiName: VILLE_FIELD })
    wiredVille({ data, error }) {
        if (data) {
            this.allVilleOptions = data;
            if (this.form.pays) {
                this._updateVilleOptions();
            }
        }
        if (error) console.error('Ville picklist error', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantInfo.data.defaultRecordTypeId', fieldApiName: STATE_OF_PERSON_FIELD })
    wiredState({ data, error }) {
        if (data) this.etatOptions = data.values;
        if (error) console.error('StateOfPerson picklist error', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantInfo.data.defaultRecordTypeId', fieldApiName: PAYS_COMPAGNIE_FIELD })
    wiredPaysCompagnie({ data, error }) {
        if (data) this.paysCompagnieOptions = data.values;
        if (error) console.error('PaysCompagnieAdverse picklist error', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantInfo.data.defaultRecordTypeId', fieldApiName: TYPE_CONTACT_FIELD })
    wiredTypeContact({ data, error }) {
        if (data) this.typeContactOptions = data.values;
        if (error) console.error('TypeContact picklist error', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantInfo.data.defaultRecordTypeId', fieldApiName: CIVILITE_FIELD })
    wiredCivilite({ data, error }) {
        if (data) this.civiliteOptions = data.values;
        if (error) console.error('Civilite picklist error', error);
    }

    @wire(getRecord, { recordId: '$recordId', fields: [CASE_CREATED_DATE] })
    caseRecord;

    get caseCreatedDate() {
        const val = this.caseRecord?.data?.fields?.CreatedDate?.value;
        return val ? val.substring(0, 10) : null;
    }

    /* ══════════════════════════════════════
       VILLE DEPENDENT PICKLIST
    ══════════════════════════════════════ */
    _updateVilleOptions() {
        if (!this.allVilleOptions || !this.form.pays) {
            this.filteredVilleOptions = [];
            return;
        }
        const key = this.form.pays;
        const controllerValues = this.allVilleOptions.controllerValues || {};
        const controllerIndex = controllerValues[key];
        if (controllerIndex === undefined) {
            this.filteredVilleOptions = this.allVilleOptions.values || [];
            return;
        }
        this.filteredVilleOptions = (this.allVilleOptions.values || []).filter(
            opt => opt.validFor && opt.validFor.includes(controllerIndex)
        );
    }

    /* ══════════════════════════════════════
       LIFECYCLE
    ══════════════════════════════════════ */
    connectedCallback() {
        this.loadParticipants();
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
            'Blessé': 'ap-state ap-state--blesse',
            'Décédé': 'ap-state ap-state--deces',
            'Indemne': 'ap-state ap-state--indemne',
        }[r.StateOfPerson__c] || 'ap-state ap-state--default';

        return {
            ...r,
            stateClass,
            civility: r.ParticipantAccount__r?.Civility__c || '',
            nom: r.ParticipantAccount__r?.Nom__c || '',
            prenom: r.ParticipantAccount__r?.Prenom__c || '',
            accountName: r.ParticipantAccount__r?.Name || '',
            compagnieName: r.CompagnieAdverse__r?.Name || '',
            hasCompagnie: !!r.CompagnieAdverse__c,
            participantUrl: r.Id,
        };
    }

    _applyFilter() {
        this.filteredRecords = this.records.slice(
            (this.currentPage - 1) * PAGE_SIZE,
            this.currentPage * PAGE_SIZE
        );
    }

    /* ══════════════════════════════════════
       GETTERS
    ══════════════════════════════════════ */
    get totalPages() { return Math.max(1, Math.ceil(this.records.length / PAGE_SIZE)); }
    get showPagination() { return this.totalPages > 1; }
    get hasRecords() { return this.filteredRecords.length > 0; }
    get isFirstPage() { return this.currentPage === 1; }
    get isLastPage() { return this.currentPage === this.totalPages; }
    get prevClass() { return `ap-btn ap-btn--page${this.isFirstPage ? ' ap-btn--disabled' : ''}`; }
    get nextClass() { return `ap-btn ap-btn--page${this.isLastPage ? ' ap-btn--disabled' : ''}`; }
    get totalLabel() { return `${this.records.length} autre${this.records.length > 1 ? 's' : ''} partie${this.records.length > 1 ? 's' : ''} adverse${this.records.length > 1 ? 's' : ''}`; }

    prevPage() { if (!this.isFirstPage) { this.currentPage--; this._applyFilter(); } }
    nextPage() { if (!this.isLastPage) { this.currentPage++; this._applyFilter(); } }

    get isVilleDisabled() { return !this.form.pays; }
    get isAnimal() { return this.form.typePartieAdverse === 'Animal'; }
    get showIttIpp() { return this.form.etatPassager === 'Blessé'; }
    get showDecesFields() { return this.form.etatPassager === 'Décédé'; }
    get showEmailField() {
        return this.form.typeContact === 'Mail' || this.form.typeContact === 'Mail et Téléphone';
    }
    get showPhoneField() {
        return this.form.typeContact === 'Téléphone' || this.form.typeContact === 'Mail et Téléphone';
    }
    get modalTitle() { return this.isUpdateMode ? 'Modifier autre partie adverse' : 'Ajouter autre partie adverse'; }
    get saveLabel() { return this.isUpdateMode ? 'Enregistrer' : 'Confirmer'; }

    // Compagnie adverse lookup getters
    get hasSelectedCompagnie() { return !!this.form.compagnieAdverseId; }
    get selectedCompagnieUrl() {
        return this.form.compagnieAdverseId ? `/lightning/r/Account/${this.form.compagnieAdverseId}/view` : '';
    }
    get hasCompagnieResults() { return this.compagnieSearchResults.length > 0; }

    /* ══════════════════════════════════════
       ACTIONS
    ══════════════════════════════════════ */
    handleAdd() {
        this.isUpdateMode = false;
        this.originalEtatPassager = '';
        this.form = EMPTY_FORM();
        this.errors = EMPTY_ERRORS();
        this.selectedCompagnieName = '';
        this.compagnieSearchTerm = '';
        this.compagnieSearchResults = [];
        this.showFormModal = true;
    }

    handleRefresh() { this.loadParticipants(); }

    navigateToRecord(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.currentTarget.dataset.id,
                actionName: 'view'
            }
        });
    }

    async handleEdit(event) {
        const participantId = event.currentTarget.dataset.id;
        this.isUpdateMode = true;
        this.form = EMPTY_FORM();
        this.errors = EMPTY_ERRORS();
        this.showFormModal = true;
        this.isFormLoading = true;
        try {
            const data = await getParticipantById({ participantId });
            this.form = {
                participantId: data.participantId || '',
                typePartieAdverse: data.typePartieAdverse || '',
                nomComplet: data.nomComplet || '',
                civility: data.civility || '',
                sexe: data.sexe || '',
                dateNaissance: data.dateNaissance || '',
                cin: data.cin || '',
                situationFamiliale: data.situationFamiliale || '',
                pays: data.pays || '',
                ville: data.ville || '',
                adresse: data.adresse || '',
                etatPassager: data.etatPassager || '',
                compagnieAdverseId: data.compagnieAdverseId || '',
                paysCompagnieAdverse: data.paysCompagnieAdverse || '',
                numeroContrat: data.numeroContrat || '',
                typeContact: data.typeContact || '',
                email: data.email || '',
                telephone: data.telephone || '',
                itt: data.itt != null ? data.itt : null,
                ipp: data.ipp != null ? data.ipp : null,
                dateDeces: data.dateDeces || '',
                revenuAnnuel: data.revenuAnnuel != null ? data.revenuAnnuel : null,
                description: data.description || ''
            };
            this.originalEtatPassager = data.etatPassager || '';

            // Resolve compagnie name for the pill
            if (data.compagnieAdverseId) {
                const rec = this.records.find(r => r.CompagnieAdverse__c === data.compagnieAdverseId);
                this.selectedCompagnieName = rec?.compagnieName || data.compagnieAdverseId;
            } else {
                this.selectedCompagnieName = '';
            }

            // Update ville options for the selected pays
            if (data.pays) {
                this._updateVilleOptions();
            }
        } catch (e) {
            this._toast('Erreur', this._cleanError(e), 'error');
            this.showFormModal = false;
        } finally {
            this.isFormLoading = false;
        }
    }

    handleDeleteClick(event) {
        const recId = event.currentTarget.dataset.id;
        const rec = this.records.find(r => r.Id === recId);
        this.deleteRecordId = recId;
        this.deleteRecordName = rec?.accountName || '';
        this.showDeleteModal = true;
    }

    handleCancelDelete() {
        this.showDeleteModal = false;
        this.deleteRecordId = null;
        this.deleteRecordName = '';
    }

    async handleConfirmDelete() {
        this.isDeleting = true;
        try {
            const result = await deletePartie({ participantId: this.deleteRecordId });
            if (result.success) {
                this._toast('Succès', result.message, 'success');
                this.showDeleteModal = false;
                this.deleteRecordId = null;
                this.deleteRecordName = '';
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => { window.location.reload(); }, 800);
            } else {
                this._toast('Erreur', result.message, 'error');
            }
        } catch (e) {
            this._toast('Erreur', this._cleanError(e), 'error');
        } finally {
            this.isDeleting = false;
        }
    }

    /* ══════════════════════════════════════
       FORM HANDLERS
    ══════════════════════════════════════ */
    handleFieldChange(e) {
        const name = e.target.name;
        const value = e.target.value;
        this.form = { ...this.form, [name]: value };

        if (name === 'pays') {
            this.form = { ...this.form, ville: '' };
            this._updateVilleOptions();
        }
        // Validate état transition on edit
        if (name === 'etatPassager' && this.isUpdateMode && this.originalEtatPassager) {
            const allowed = ETAT_ALLOWED[this.originalEtatPassager] || [];
            if (!allowed.includes(value)) {
                this.errors = {
                    ...this.errors,
                    etatPassager: `Transition non autorisée : impossible de passer de "${this.originalEtatPassager}" à "${value}".`
                };
                return;
            }
        }
        if (this.errors[name] !== undefined) {
            this.errors = { ...this.errors, [name]: '' };
        }
    }

    handleFormSubmit(e) { e.preventDefault(); }

    /* ══════════════════════════════════════
       COMPAGNIE ADVERSE LOOKUP
    ══════════════════════════════════════ */
    async handleCompagnieSearch(e) {
        this.compagnieSearchTerm = e.target.value;
        if (this.compagnieSearchTerm.length < 2) {
            this.compagnieSearchResults = [];
            this.showCompagnieDropdown = false;
            return;
        }
        try {
            const results = await searchCompagnies({ searchTerm: this.compagnieSearchTerm });
            this.compagnieSearchResults = results;
            this.showCompagnieDropdown = true;
        } catch (err) {
            console.error('searchCompagnies error', err);
            this.compagnieSearchResults = [];
        }
    }

    handleCompagnieSearchFocus() {
        if (this.compagnieSearchResults.length > 0) {
            this.showCompagnieDropdown = true;
        }
    }

    handleCompagnieSearchBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showCompagnieDropdown = false; }, 200);
    }

    handleCompagnieSelect(e) {
        const selectedId = e.currentTarget.dataset.value;
        const selectedLabel = e.currentTarget.dataset.label;
        this.form = { ...this.form, compagnieAdverseId: selectedId };
        this.selectedCompagnieName = selectedLabel;
        this.compagnieSearchTerm = '';
        this.compagnieSearchResults = [];
        this.showCompagnieDropdown = false;
    }

    handleCompagnieRemove() {
        this.form = { ...this.form, compagnieAdverseId: '' };
        this.selectedCompagnieName = '';
        this.compagnieSearchTerm = '';
    }

    /* ══════════════════════════════════════
       VALIDATION
    ══════════════════════════════════════ */
    _validate() {
        const e = EMPTY_ERRORS();
        let ok = true;

        if (!this.form.nomComplet?.trim()) { e.nomComplet = 'Obligatoire'; ok = false; }
        if (!this.form.civility) { e.civility = 'Obligatoire'; ok = false; }
        if (!this.form.pays) { e.pays = 'Obligatoire'; ok = false; }
        if (!this.form.ville) { e.ville = 'Obligatoire'; ok = false; }
        if (!this.form.etatPassager) { e.etatPassager = 'Obligatoire'; ok = false; }
        if (!this.form.paysCompagnieAdverse) { e.paysCompagnieAdverse = 'Obligatoire'; ok = false; }

        // Contact fields
        if (this.showEmailField && !this.form.email?.trim()) { e.email = 'Obligatoire'; ok = false; }
        if (this.showPhoneField && !this.form.telephone?.trim()) { e.telephone = 'Obligatoire'; ok = false; }

        // Décédé
        if (this.form.etatPassager === 'Décédé') {
            if (!this.form.dateDeces) { e.dateDeces = 'Obligatoire'; ok = false; }
            if (this.form.revenuAnnuel == null || this.form.revenuAnnuel === '') { e.revenuAnnuel = 'Obligatoire'; ok = false; }
        }

        // État transition validation
        if (this.isUpdateMode && this.originalEtatPassager && this.form.etatPassager) {
            const allowed = ETAT_ALLOWED[this.originalEtatPassager] || [];
            if (!allowed.includes(this.form.etatPassager)) {
                e.etatPassager = `Transition non autorisée : impossible de passer de "${this.originalEtatPassager}" à "${this.form.etatPassager}".`;
                ok = false;
            }
        }

        // Date validations
        if (this.form.dateNaissance && this.caseCreatedDate) {
            if (this.form.dateNaissance > this.caseCreatedDate) {
                e.dateNaissance = 'La date de naissance ne peut pas être postérieure à la date du sinistre';
                ok = false;
            }
        }
        if (this.form.dateDeces && this.caseCreatedDate) {
            if (this.form.dateDeces > this.caseCreatedDate) {
                e.dateDeces = 'La date de décès ne peut pas être postérieure à la date du sinistre';
                ok = false;
            }
        }

        this.errors = e;
        return ok;
    }

    /* ══════════════════════════════════════
       SAVE
    ══════════════════════════════════════ */
    async handleSave() {
        if (!this._validate()) return;
        this.isSaving = true;
        try {
            const isDup = await checkDuplicate({
                cin: this.form.cin?.trim(),
                claimId: this.recordId,
                excludeId: this.isUpdateMode ? this.form.participantId : null
            });
            if (isDup) {
                this._toast('Doublon détecté', `Une autre partie adverse avec le CIN "${this.form.cin}" existe déjà.`, 'warning', 'sticky');
                this.isSaving = false;
                return;
            }

            const fullName = this.form.nomComplet.trim();
            let accountId;
            try {
                accountId = await resolveAccountByCIN({
                    cin: this.form.cin ? this.form.cin.trim() : fullName,
                    nom: fullName
                });
            } catch (err) {
                this._toast('Erreur', err.body?.message || 'Erreur lors de la résolution du compte.', 'error');
                this.isSaving = false;
                return;
            }

            const result = await upsertPartie({
                formData: this.form,
                claimId: this.recordId,
                isUpdateMode: this.isUpdateMode,
                accountId: accountId
            });

            if (result.success) {
                this._toast('Succès', result.message, 'success');
                this.closeModal();
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => { window.location.reload(); }, 800);
            } else {
                this._toast('Erreur', result.message, 'error', 'sticky');
            }
        } catch (e) {
            this._toast('Erreur', this._cleanError(e), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    closeModal() { this.showFormModal = false; }
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