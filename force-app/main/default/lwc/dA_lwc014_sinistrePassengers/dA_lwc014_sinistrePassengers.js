import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getPassengers   from '@salesforce/apex/DA_PassengerController.getPassengers';
import savePassenger   from '@salesforce/apex/DA_PassengerController.savePassenger';
import deletePassenger from '@salesforce/apex/DA_PassengerController.deletePassenger';
import getPicklistValues from '@salesforce/apex/DA_PassengerController.getPicklistValues';
import getClaimAccount   from '@salesforce/apex/DA_PassengerController.getClaimAccount';

const EMPTY_FORM = () => ({
    Id:                   null,
    ParticipantAccount__c: null,
    Sexe__c:              '',
    BirthDay__c:          '',
    Roles__c:             '',
    StateOfPerson__c:     '',
    isDriver__c:          false,
    IPP__c:               null,
    ITT__c:               null,
    DateDeces__c:         '',
    RevenuAnnuel__c:      null,
    TypeContact__c:       '',
    Vehicule__c:          null,
    CompagnieAdverse__c:  null,
    Adresse__c:           '',
    Pays__c:              '',
    Ville__c:             '',
    MaritalStatus__c:     '',
    // Champs locaux pour la création de compte
    _nom:    '',
    _prenom: '',
    _civilite: ''
});

export default class DA_lwc014_sinistrePassengers extends LightningElement {

    @api recordId;
    @api cardTitle = 'Véhicule et passagers assurés';

    @track passengers     = [];
    @track showFormModal  = false;
    @track showDeleteModal = false;
    @track form           = EMPTY_FORM();
    @track errors         = {};
    @track formError      = '';
    @track isLoading      = false;
    @track isSaving       = false;

    isEditMode     = false;
    deleteTargetId = null;
    _wiredResult;
    claimAccountId = null;

    @track sexeOptions        = [];
    @track rolesOptions       = [];
    @track stateOptions       = [];
    @track typeContactOptions = [];
    @track paysOptions        = [];
    @track villeOptions       = [];
    @track maritalOptions     = [];

    async connectedCallback() {
        await this._loadPicklists();
        await this._loadClaimAccount();
    }

    async _loadPicklists() {
        const fields = [
            { key: 'sexeOptions',        field: 'Sexe__c' },
            { key: 'rolesOptions',       field: 'Roles__c' },
            { key: 'stateOptions',       field: 'StateOfPerson__c' },
            { key: 'typeContactOptions', field: 'TypeContact__c' },
            { key: 'paysOptions',        field: 'Pays__c' },
            { key: 'maritalOptions',     field: 'MaritalStatus__c' }
        ];

        for (const { key, field } of fields) {
            try {
                this[key] = await getPicklistValues({
                    objectApiName: 'ClaimParticipant__c',
                    fieldApiName:  field
                });
            } catch (e) {
                console.error(`Erreur picklist ${field}:`, e);
            }
        }
    }

    async _loadClaimAccount() {
        try {
            this.claimAccountId = await getClaimAccount({ claimId: this.recordId });
            console.log('Compte du sinistre:', this.claimAccountId);
        } catch (e) {
            console.error('Erreur chargement compte:', e);
        }
    }

    @wire(getPassengers, { claimId: '$recordId' })
    wiredPassengers(result) {
        this._wiredResult = result;
        if (result.data) {
            this.passengers = result.data.map(p => ({
                ...p,
                displayName:      p.ParticipantAccount__r?.Name || p.Name || '—',
                stateBadgeClass:  this._getStateBadgeClass(p.StateOfPerson__c),
                roleBadgeClass:   this._getRoleBadgeClass(p.Roles__c)
            }));
        } else if (result.error) {
            console.error('Erreur chargement participants:', result.error);
        }
    }

    _getStateBadgeClass(state) {
        const map = {
            'Blessé':  'pm-state pm-state--blesse',
            'Décédé':  'pm-state pm-state--deces',
            'Indemne': 'pm-state pm-state--indemne'
        };
        return map[state] || 'pm-state pm-state--default';
    }

    _getRoleBadgeClass(role) {
        if (!role) return 'pm-role';
        return role.includes('assuré') || role.includes('assure')
            ? 'pm-role pm-role--assure'
            : 'pm-role pm-role--adverse';
    }

    get isEmpty() {
        return !this.passengers || this.passengers.length === 0;
    }

    get isBlesse() {
        return this.form.StateOfPerson__c === 'Blessé';
    }

    get isDeces() {
        return this.form.StateOfPerson__c === 'Décédé';
    }

    get modalTitle() {
        return this.isEditMode ? 'Modifier le participant' : 'Ajouter un participant';
    }

    openAddModal() {
        this.isEditMode = false;
        this.form       = EMPTY_FORM();
        this.errors     = {};
        this.formError  = '';
        this.showFormModal = true;
    }

    openEditModal(event) {
        const id          = event.currentTarget.dataset.id;
        const participant = this.passengers.find(p => p.Id === id);
        if (!participant) return;

        this.isEditMode = true;
        this.form = {
            Id:                    participant.Id,
            ParticipantAccount__c: participant.ParticipantAccount__c || null,
            Sexe__c:               participant.Sexe__c               || '',
            BirthDay__c:           participant.BirthDay__c           || '',
            Roles__c:              participant.Roles__c              || '',
            StateOfPerson__c:      participant.StateOfPerson__c      || '',
            isDriver__c:           participant.isDriver__c           || false,
            IPP__c:                participant.IPP__c,
            ITT__c:                participant.ITT__c,
            DateDeces__c:          participant.DateDeces__c          || '',
            RevenuAnnuel__c:       participant.RevenuAnnuel__c,
            TypeContact__c:        participant.TypeContact__c        || '',
            Vehicule__c:           participant.Vehicule__c           || null,
            CompagnieAdverse__c:   participant.CompagnieAdverse__c   || null,
            Adresse__c:            participant.Adresse__c            || '',
            Pays__c:               participant.Pays__c               || '',
            Ville__c:              participant.Ville__c              || '',
            MaritalStatus__c:      participant.MaritalStatus__c      || '',
            _nom:     '',
            _prenom:  '',
            _civilite: ''
        };
        this.errors    = {};
        this.formError = '';
        this.showFormModal = true;
    }

    closeFormModal() {
        this.showFormModal = false;
    }

    handleOverlayClick() {
        this.closeFormModal();
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this.form = { ...this.form, [field]: event.detail.value };

        if (this.errors[field]) {
            const newErrors = { ...this.errors };
            delete newErrors[field];
            this.errors = newErrors;
        }
    }

    handleToggleChange(event) {
        this.form = { ...this.form, isDriver__c: event.detail.checked };
    }

    _validate() {
        const newErrors = {};

        if (!this.form._nom?.trim() && !this.form.ParticipantAccount__c) {
            newErrors._nom = 'Le nom du participant est obligatoire.';
        }
        if (!this.form.Roles__c) {
            newErrors.Roles__c = 'Le rôle est obligatoire.';
        }
        if (!this.form.StateOfPerson__c) {
            newErrors.StateOfPerson__c = "L'état du participant est obligatoire.";
        }

        this.errors = newErrors;
        return Object.keys(newErrors).length === 0;
    }

    async savePassenger() {
        console.log('=== SAVE PARTICIPANT ===');

        if (!this._validate()) {
            console.log('Validation échouée:', this.errors);
            return;
        }

        this.isSaving  = true;
        this.formError = '';

        // ✅ Ne pas inclure Id si création
        const payload = {
            ...(this.form.Id ? { Id: this.form.Id } : {}),
            Claim__c:              this.recordId,
            ParticipantAccount__c: this.form.ParticipantAccount__c || this.claimAccountId || null,
            Sexe__c:               this.form.Sexe__c               || null,
            BirthDay__c:           this.form.BirthDay__c           || null,
            Roles__c:              this.form.Roles__c,
            StateOfPerson__c:      this.form.StateOfPerson__c,
            isDriver__c:           this.form.isDriver__c,
            TypeContact__c:        this.form.TypeContact__c        || null,
            Adresse__c:            this.form.Adresse__c            || null,
            Pays__c:               this.form.Pays__c               || null,
            Ville__c:              this.form.Ville__c              || null,
            MaritalStatus__c:      this.form.MaritalStatus__c      || null
        };

        if (this.isBlesse) {
            payload.IPP__c = this.form.IPP__c || null;
            payload.ITT__c = this.form.ITT__c || null;
        }

        if (this.isDeces) {
            payload.DateDeces__c    = this.form.DateDeces__c    || null;
            payload.RevenuAnnuel__c = this.form.RevenuAnnuel__c || null;
        }

        console.log('Payload:', JSON.stringify(payload));

        try {
            await savePassenger({
                participant:     payload,
                nomContact:      this.form._nom      || null,
                prenomContact:   this.form._prenom   || null,
                civiliteContact: this.form._civilite || null,
                sexeContact:     this.form.Sexe__c   || null,
                birthDayContact: this.form.BirthDay__c || null
            });

            await this._loadClaimAccount();
            await refreshApex(this._wiredResult);

            this.showFormModal = false;
            this._showToast('Succès', 'Participant enregistré avec succès.', 'success');

        } catch (error) {
            console.error('Erreur:', error);
            const errorMessage = error?.body?.message || error?.message || "Erreur lors de l'enregistrement";
            this.formError = errorMessage;
            this._showToast('Erreur', errorMessage, 'error');

        } finally {
            this.isSaving = false;
        }
    }

    openDeleteModal(event) {
        this.deleteTargetId = event.currentTarget.dataset.id;
        this.showDeleteModal = true;
    }

    closeDeleteModal() {
        this.showDeleteModal = false;
        this.deleteTargetId = null;
    }

    async confirmDelete() {
        this.isSaving = true;
        try {
            await deletePassenger({ participantId: this.deleteTargetId });
            await refreshApex(this._wiredResult);
            this.showDeleteModal = false;
            this._showToast('Supprimé', 'Le participant a été supprimé.', 'success');
        } catch (error) {
            console.error('Erreur suppression:', error);
            this._showToast('Erreur', 'Erreur lors de la suppression.', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}