import { LightningElement, api, track } from 'lwc';
import { NavigationMixin }              from 'lightning/navigation';  // ══ AJOUT NavigationMixin ══

import getClaimParticipants from '@salesforce/apex/ClaimParticipantController.getClaimParticipants';
import getParticipantById   from '@salesforce/apex/ClaimParticipantController.getParticipantById';
import createPassager       from '@salesforce/apex/ClaimParticipantController.createPassager';
import updatePassager       from '@salesforce/apex/ClaimParticipantController.updatePassager';
import deletePassager       from '@salesforce/apex/ClaimParticipantController.deletePassager';
import isCinAlreadyUsed     from '@salesforce/apex/ClaimParticipantController.isCinAlreadyUsed';
import getPicklistValues    from '@salesforce/apex/ClaimParticipantController.getPicklistValues';
import { ShowToastEvent }   from 'lightning/platformShowToastEvent';

// ══ CORRECTION : NavigationMixin appliqué à la classe ══
export default class DAlwc014PassagerAssure extends NavigationMixin(LightningElement) {
    @api recordId;

    @track participants          = [];
    @track isLoading             = false;
    @track isSaving              = false;
    @track error                 = null;
    @track isModalOpen           = false;
    @track isDeleteModalOpen     = false;
    @track isEditMode            = false;
    @track isLoadingDetail       = false;
    @track participantToDeleteId = null;
    @track editParticipantId     = null;
    @track editAccountId         = null;

    @track formData = {
        participantName : '',
        birthDate       : '',
        cni             : '',
        civility        : '',
        email           : '',
        phone           : '',
        address         : '',
        city            : '',
        country         : '',
        stateOfPerson   : '',
        maritalStatus   : '',
        sexe            : '',
        isDriver        : false,
        ipp             : null,
        itt             : null,
        dateDeces       : '',
        revenuAnnuel    : null,
        contactMode     : 'tel_email'
    };

    @track picklistOptions = {
        stateOfPerson : [],
        maritalStatus : [],
        sexe          : [],
        country       : [],
        city          : [],
        roles         : [],
        civility      : []
    };

    @track formErrors = {};

    @track activeFilter    = 'all';
    @track pageSize        = 10;
    @track currentPage     = 1;
    @track roleAssureValue = 'Passager assuré';
    @track picklistsLoaded = false;

    _cinCheckTimer = null;

    // ── Titre modal ───────────────────────────────────────────────────────
    get modalTitle() {
        return this.isEditMode ? 'Modifier le passager assuré' : 'Ajouter un passager assuré';
    }

    // ── Mode de contact ───────────────────────────────────────────────────
    get contactModeOptions() {
        return [
            { label: 'Téléphone et Email', value: 'tel_email' },
            { label: 'Téléphone',          value: 'tel'       },
            { label: 'Email',              value: 'email'     }
        ];
    }
    get showTelField()   { return this.formData.contactMode === 'tel'   || this.formData.contactMode === 'tel_email'; }
    get showEmailField() { return this.formData.contactMode === 'email' || this.formData.contactMode === 'tel_email'; }

    // ── Ville désactivée tant qu'aucun pays n'est choisi ─────────────────
    get isCityDisabled() { return !this.formData.country; }

    // ── Filter pills ──────────────────────────────────────────────────────
    get allButtonClass()     { return this.activeFilter === 'all'    ? 'pm-pill pm-pill--active' : 'pm-pill'; }
    get blesseButtonClass()  { return this.activeFilter === 'blesse' ? 'pm-pill pm-pill--active' : 'pm-pill'; }
    get decedeButtonClass()  { return this.activeFilter === 'decede' ? 'pm-pill pm-pill--active' : 'pm-pill'; }
    get indemneButtonClass() { return this.activeFilter === 'indemne'? 'pm-pill pm-pill--active' : 'pm-pill'; }

    // ── Picklist options ──────────────────────────────────────────────────
    get stateOfPersonOptions() { return this.picklistOptions.stateOfPerson; }
    get maritalStatusOptions()  { return this.picklistOptions.maritalStatus;  }
    get sexeOptions()           { return this.picklistOptions.sexe;           }
    get countryOptions()        { return this.picklistOptions.country;        }
    get cityOptions()           { return this.picklistOptions.city;           }
    get civilityOptions()       { return this.picklistOptions.civility;       }

    // ── Pagination / filter ───────────────────────────────────────────────
    get hasParticipants()  { return this.filteredParticipants.length > 0; }
    get hasMultiplePages() { return this.totalPages > 1; }

    get filteredParticipants() {
        let f = this.participants;
        if      (this.activeFilter === 'blesse') f = f.filter(p => p.StateOfPerson__c === 'Blessé');
        else if (this.activeFilter === 'decede') f = f.filter(p => p.StateOfPerson__c === 'Décédé');
        else if (this.activeFilter === 'indemne')f = f.filter(p => p.StateOfPerson__c === 'Indemne');
        return f;
    }

    get paginatedParticipants() {
        const s = (this.currentPage - 1) * this.pageSize;
        return this.filteredParticipants.slice(s, s + this.pageSize);
    }

    get totalPages()  { return Math.ceil(this.filteredParticipants.length / this.pageSize) || 1; }
    get isFirstPage() { return this.currentPage === 1; }
    get isLastPage()  { return this.currentPage === this.totalPages || this.totalPages === 0; }

    // ── Champs conditionnels sinistre ─────────────────────────────────────
    get showIppIttFields()          { return this.formData.stateOfPerson === 'Blessé';  }
    get showDateDecesRevenuFields() { return this.formData.stateOfPerson === 'Décédé'; }

    // ── Lifecycle ─────────────────────────────────────────────────────────
    connectedCallback() {
        this.loadPicklistValues();
        this.loadParticipants();
    }

    // ── Picklists ─────────────────────────────────────────────────────────
    async loadPicklistValues() {
        try {
            const fields  = ['StateOfPerson__c','MaritalStatus__c','Sexe__c','Pays__c','Ville__c','Roles__c'];
            const results = await getPicklistValues({ objectApiName: 'ClaimParticipant__c', fields });

            if (results.StateOfPerson__c) this.picklistOptions = { ...this.picklistOptions, stateOfPerson: results.StateOfPerson__c };
            if (results.MaritalStatus__c) this.picklistOptions = { ...this.picklistOptions, maritalStatus: results.MaritalStatus__c };
            if (results.Sexe__c)          this.picklistOptions = { ...this.picklistOptions, sexe:          results.Sexe__c          };
            if (results.Pays__c)          this.picklistOptions = { ...this.picklistOptions, country:       results.Pays__c          };
            if (results.Ville__c)         this.picklistOptions = { ...this.picklistOptions, city:          results.Ville__c         };

            if (results.Roles__c?.length) {
                this.picklistOptions = { ...this.picklistOptions, roles: results.Roles__c };
                const found = results.Roles__c.find(r => r.value === 'Passager assuré' || r.label === 'Passager assuré');
                if (found) this.roleAssureValue = found.value;
            }

            const accountResults = await getPicklistValues({ objectApiName: 'Account', fields: ['Civility__c'] });
            if (accountResults.Civility__c) {
                this.picklistOptions = { ...this.picklistOptions, civility: accountResults.Civility__c };
            }

            this.picklistsLoaded = true;
        } catch (err) {
            console.error('Erreur picklists:', err);
        }
    }

    // ── Participants ──────────────────────────────────────────────────────
    async loadParticipants() {
        this.isLoading = true;
        this.error     = null;
        try {
            const result   = await getClaimParticipants({ claimId: this.recordId });
            const filtered = result.filter(p => p.Roles__c === this.roleAssureValue);
            this.participants = filtered.map(p => ({
                ...p,
                isDriver        : p.isDriver__c || false,
                stateLabel      : this.getStateLabel(p.StateOfPerson__c),
                stateClass      : this.getStateClass(p.StateOfPerson__c),
                participantName : p.ParticipantAccount__r?.Name || p.Name || 'N/A',
                civilite        : p.ParticipantAccount__r?.Civility__c || '—',
                accountId       : p.ParticipantAccount__c || null   // ══ AJOUT : ID Account pour la navigation ══
            }));
        } catch (err) {
            this.error = 'Erreur lors du chargement des participants';
            this.showToast('Erreur', this.error, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    getStateLabel(state) {
        return { 'Blessé':'Blessé', 'Décédé':'Décédé', 'Indemne':'Indemne' }[state] || state || 'Non défini';
    }
    getStateClass(state) {
        return {
            'Blessé' : 'pm-state pm-state--blesse',
            'Décédé' : 'pm-state pm-state--deces',
            'Indemne': 'pm-state pm-state--indemne'
        }[state] || 'pm-state pm-state--default';
    }

    // ══ AJOUT : Navigation vers l'Account via NavigationMixin ══
    handleNavigateToAccount(event) {
        event.preventDefault();
        const accountId = event.currentTarget.dataset.accountId;
        if (!accountId) return;
        this[NavigationMixin.Navigate]({
            type       : 'standard__recordPage',
            attributes : {
                recordId      : accountId,
                objectApiName : 'Account',
                actionName    : 'view'
            }
        });
    }

    // ── Mode de contact → reset champs non utilisés ───────────────────────
    handleContactModeChange(event) {
        const mode = event.target.value;
        let updated = { ...this.formData, contactMode: mode };
        if (mode === 'tel')   updated = { ...updated, email: '' };
        if (mode === 'email') updated = { ...updated, phone: '' };
        this.formData   = updated;
        this.formErrors = { ...this.formErrors, phone: null, email: null };
    }

    // ── Pays → reset ville ────────────────────────────────────────────────
    handleCountryChange(event) {
        this.formData = { ...this.formData, country: event.target.value, city: '' };
        if (this.formErrors.country) this.formErrors = { ...this.formErrors, country: null };
    }

    // ── Input générique ───────────────────────────────────────────────────
    handleInputChange(event) {
        const field = event.target.name;
        let value   = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        if (['ipp','itt','revenuAnnuel'].includes(field)) {
            value = value === '' ? null : parseFloat(value);
        }
        this.formData = { ...this.formData, [field]: value };
        if (this.formErrors[field]) this.formErrors = { ...this.formErrors, [field]: null };

        // Vérification unicité CIN avec debounce (600 ms)
        if (field === 'cni') {
            clearTimeout(this._cinCheckTimer);
            if (value?.trim()) {
                this._cinCheckTimer = setTimeout(() => {
                    this.checkCinUniqueness(value.trim());
                }, 600);
            }
        }
    }

    async checkCinUniqueness(cin) {
        try {
            const excludeId = this.isEditMode ? this.editAccountId : null;
            const isDuplicate = await isCinAlreadyUsed({ cin, excludeAccountId: excludeId });
            if (isDuplicate) {
                this.formErrors = { ...this.formErrors, cni: `Le CIN « ${cin} » est déjà utilisé par un autre passager.` };
            } else {
                this.formErrors = { ...this.formErrors, cni: null };
            }
        } catch (err) {
            console.error('Erreur vérification CIN:', err);
        }
    }

    // ── Validation ────────────────────────────────────────────────────────
    validateForm() {
        const e = { ...this.formErrors };
        if (!this.formData.participantName?.trim()) e.participantName = 'Le nom est requis';
        if (!this.formData.cni?.trim())             e.cni             = e.cni || 'Le CIN est requis';
        if (!this.formData.stateOfPerson)           e.stateOfPerson   = "L'état du passager est requis";

        const mode = this.formData.contactMode;
        if (mode === 'tel' || mode === 'tel_email') {
            if (!this.formData.phone?.trim()) e.phone = 'Le téléphone est requis';
        }
        if (mode === 'email' || mode === 'tel_email') {
            if (!this.formData.email?.trim()) e.email = "L'email est requis";
        }

        if (this.formData.stateOfPerson === 'Décédé') {
            if (!this.formData.dateDeces) e.dateDeces = "La date de décès est requise";
        }

        this.formErrors = e;
        return Object.keys(e).filter(k => !!e[k]).length === 0;
    }

    // ── Sauvegarde ────────────────────────────────────────────────────────
    async handleSave() {
        if (!this.validateForm()) {
            this.showToast('Erreur de validation', 'Veuillez remplir tous les champs requis', 'error');
            return;
        }
        this.isSaving = true;
        try {
            let result;

            if (this.isEditMode && this.editParticipantId) {
                result = await updatePassager({
                    formData      : this.formData,
                    participantId : this.editParticipantId,
                    accountId     : this.editAccountId
                });
            } else {
                result = await createPassager({
                    formData : this.formData,
                    claimId  : this.recordId
                });
            }

            if (result.success) {
                this.showToast('Succès', result.message, 'success');
                this.closeModal();
                await this.loadParticipants();
            } else {
                if (result.message?.startsWith('CIN_DUPLICATE:')) {
                    const cinMsg = result.message.replace('CIN_DUPLICATE:', '');
                    this.formErrors = { ...this.formErrors, cni: cinMsg };
                    this.showToast('CIN déjà utilisé', cinMsg, 'error');
                } else {
                    this.showToast('Erreur', result.message, 'error');
                }
            }
        } catch (err) {
            const msg = err.body?.message || err.message || "Erreur lors de l'enregistrement";
            this.showToast('Erreur', msg, 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // ── Édition ───────────────────────────────────────────────────────────
    async handleEdit(event) {
        const id = event.currentTarget.dataset.id;
        this.isEditMode        = true;
        this.editParticipantId = id;
        this.formErrors        = {};
        this.isLoadingDetail   = true;
        this.isModalOpen       = true;

        try {
            const detail = await getParticipantById({ participantId: id });

            this.editAccountId = detail.accountId || null;

            const hasPhone = !!detail.phone;
            const hasEmail = !!detail.email;
            let contactMode = 'tel_email';
            if (hasPhone && !hasEmail)      contactMode = 'tel';
            else if (!hasPhone && hasEmail) contactMode = 'email';

            this.formData = {
                participantName : detail.participantName || '',
                birthDate       : detail.birthDate       || '',
                cni             : detail.cni             || '',
                civility        : detail.civility        || '',
                email           : detail.email           || '',
                phone           : detail.phone           || '',
                address         : detail.address         || '',
                city            : detail.city            || '',
                country         : detail.country         || '',
                stateOfPerson   : detail.stateOfPerson   || '',
                maritalStatus   : detail.maritalStatus   || '',
                sexe            : detail.sexe            || '',
                isDriver        : detail.isDriver        || false,
                ipp             : detail.ipp             ?? null,
                itt             : detail.itt             ?? null,
                dateDeces       : detail.dateDeces       || '',
                revenuAnnuel    : detail.revenuAnnuel    ?? null,
                contactMode     : contactMode
            };
        } catch (err) {
            this.showToast('Erreur', 'Impossible de charger les données du participant.', 'error');
            this.closeModal();
        } finally {
            this.isLoadingDetail = false;
        }
    }

    // ── Suppression ───────────────────────────────────────────────────────
    handleDelete(event) {
        this.participantToDeleteId = event.currentTarget.dataset.id;
        this.isDeleteModalOpen     = true;
    }

    async confirmDelete() {
        if (!this.participantToDeleteId) return;
        this.isSaving = true;
        try {
            const result = await deletePassager({ participantId: this.participantToDeleteId });
            if (result.success) {
                this.showToast('Succès', result.message, 'success');
                this.closeDeleteModal();
                await this.loadParticipants();
            } else {
                this.showToast('Erreur', result.message, 'error');
            }
        } catch (err) {
            this.showToast('Erreur', err.body?.message || err.message || 'Erreur lors de la suppression', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    closeDeleteModal() {
        this.isDeleteModalOpen     = false;
        this.participantToDeleteId = null;
    }

    // ── Modal ─────────────────────────────────────────────────────────────
    openAddModal() {
        this.isEditMode        = false;
        this.editParticipantId = null;
        this.editAccountId     = null;
        this.resetForm();
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.resetForm();
    }

    handleModalClick(event) { event.stopPropagation(); }

    resetForm() {
        this.formData = {
            participantName:'', birthDate:'', cni:'', civility:'', email:'', phone:'',
            address:'', city:'', country:'', stateOfPerson:'', maritalStatus:'',
            sexe:'', isDriver:false, ipp:null, itt:null, dateDeces:'', revenuAnnuel:null,
            contactMode:'tel_email'
        };
        this.formErrors      = {};
        this.editAccountId   = null;
        this.isLoadingDetail = false;
    }

    // ── Pagination / filtres ──────────────────────────────────────────────
    handleFilterChange(event) { this.activeFilter = event.currentTarget.dataset.filter; this.currentPage = 1; }
    handlePreviousPage() { if (!this.isFirstPage) this.currentPage--; }
    handleNextPage()     { if (!this.isLastPage)  this.currentPage++; }

    // ── Toast ─────────────────────────────────────────────────────────────
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}