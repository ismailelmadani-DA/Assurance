import { LightningElement, api, wire } from 'lwc';
import getPassengers from '@salesforce/apex/DA_PassagerController.getPassengers';
import deletePassenger from '@salesforce/apex/DA_PassagerController.deletePassenger';
import getAvailableAccounts from '@salesforce/apex/DA_PassagerController.getAvailableAccounts';
import savePassenger from '@salesforce/apex/DA_PassagerController.savePassenger';
import getAccountPrefillData from '@salesforce/apex/DA_PassagerController.getAccountPrefillData';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import { getObjectInfo, getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';

import CASE_ACCOUNTID_FIELD from '@salesforce/schema/Case.AccountId';
import PASSAGER_OBJECT from '@salesforce/schema/Passager__c';

import PASSAGER_NAME_FIELD from '@salesforce/schema/Passager__c.Name';
import PASSAGER_PAYS_FIELD from '@salesforce/schema/Passager__c.Pays__c';
import PASSAGER_VILLE_FIELD from '@salesforce/schema/Passager__c.Ville__c';
import PASSAGER_TYPECONTACT_FIELD from '@salesforce/schema/Passager__c.TypeContact__c';
import PASSAGER_CONTACT_FIELD from '@salesforce/schema/Passager__c.ContactPassager__c';
import PASSAGER_COMPTE_FIELD from '@salesforce/schema/Passager__c.Compte__c';

const EDIT_FIELDS = [
    PASSAGER_NAME_FIELD,
    PASSAGER_PAYS_FIELD,
    PASSAGER_VILLE_FIELD,
    PASSAGER_TYPECONTACT_FIELD,
    PASSAGER_CONTACT_FIELD,
    PASSAGER_COMPTE_FIELD
];

export default class dA_lwc007_listesPassagerAssure extends LightningElement {
    @api recordId;

    passengers = [];
    isModalOpen = false;

    isAccountModalOpen = false;
    showAccountSelector = true;
    showNewAccountForm = false;

    caseAccountId;
    selectedAccountId = '';
    accounts = [];

    selectedTypeContact = '';
    contactValue = '';

    selectedPays = '';
    selectedVille = '';
    paysOptions = [];
    villeOptions = [];
    allVilleValues = [];
    paysControllerValues = {};
    recordTypeId;

    editedPassengerId = null;
    isEditMode = false;

    prefillName = '';
    prefillCivilite = '';
    prefillSexe = '';
    prefillMaritalStatus = '';
    prefillAdresse = '';
    prefillPays = '';
    prefillVille = '';
    prefillContact = '';

    columns = [
        { label: 'Civilité', fieldName: 'Civilite__c' },
        { label: 'Nom et prénom', fieldName: 'Name' },
        { label: 'CIN', fieldName: 'CIN__c' },
        { label: 'Pays', fieldName: 'Pays__c' },
        { label: 'Ville', fieldName: 'Ville__c' },
        { label: 'Etat du passager', fieldName: 'StateOfPerson__c' },
        { label: 'Est un conducteur', fieldName: 'isDriver__c', type: 'boolean' },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'Modifier', name: 'edit' },
                    { label: 'Supprimer', name: 'delete' }
                ]
            }
        }
    ];

    connectedCallback() {
        this.loadPassengers();
    }

    async loadPassengers() {
        if (!this.recordId) {
            return;
        }

        try {
            const data = await getPassengers({ caseId: this.recordId });
            this.passengers = [...(data || [])];
        } catch (error) {
            console.error('Erreur getPassengers:', error);
            this.showToast('Erreur', 'Impossible de charger les passagers', 'error');
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: [CASE_ACCOUNTID_FIELD] })
    wiredCase({ data, error }) {
        if (data) {
            this.caseAccountId = data.fields.AccountId?.value;
        } else if (error) {
            console.error('Erreur getRecord Case:', error);
        }
    }

    @wire(getAvailableAccounts)
    wiredAccounts({ data, error }) {
        if (data) {
            this.accounts = data;
        } else if (error) {
            console.error('Erreur getAvailableAccounts:', error);
            this.showToast('Erreur', 'Impossible de charger les comptes', 'error');
        }
    }

    @wire(getObjectInfo, { objectApiName: PASSAGER_OBJECT })
    objectInfoHandler({ data, error }) {
        if (data) {
            this.recordTypeId = data.defaultRecordTypeId;
        } else if (error) {
            console.error('Erreur objectInfo:', error);
        }
    }

    @wire(getPicklistValuesByRecordType, {
        objectApiName: PASSAGER_OBJECT,
        recordTypeId: '$recordTypeId'
    })
    wiredPicklists({ data, error }) {
        if (data) {
            const paysField = data.picklistFieldValues.Pays__c;
            const villeField = data.picklistFieldValues.Ville__c;

            this.paysOptions = (paysField.values || []).map(item => ({
                label: item.label,
                value: item.value
            }));

            this.allVilleValues = villeField.values || [];
            this.paysControllerValues = villeField.controllerValues || {};

            if (this.selectedPays) {
                this.filterVilles();
            }
        } else if (error) {
            console.error('Erreur chargement picklists:', error);
            this.showToast('Erreur', 'Impossible de charger les pays et villes', 'error');
        }
    }

    @wire(getRecord, { recordId: '$editedPassengerId', fields: EDIT_FIELDS })
    wiredEditedPassenger({ data, error }) {
        if (data && this.isEditMode) {
            this.selectedPays = data.fields.Pays__c?.value || '';
            this.selectedVille = data.fields.Ville__c?.value || '';
            this.selectedTypeContact = data.fields.TypeContact__c?.value || '';
            this.contactValue = data.fields.ContactPassager__c?.value || '';
            this.selectedAccountId = data.fields.Compte__c?.value || this.caseAccountId || '';

            this.filterVilles();
        } else if (error && this.editedPassengerId) {
            console.error('Erreur getRecord Passager:', error);
            this.showToast('Erreur', 'Impossible de charger le passager à modifier', 'error');
        }
    }

    get hasPassengers() {
        return this.passengers && this.passengers.length > 0;
    }

    get accountOptions() {
        return (this.accounts || []).map(account => ({
            label: account.Name,
            value: account.Id
        }));
    }

    get typeContactOptions() {
        return [
            { label: 'Téléphone', value: 'Téléphone' },
            { label: 'Mail', value: 'Mail' }
        ];
    }

    get isPhoneContact() {
        return this.selectedTypeContact === 'Téléphone';
    }

    get isEmailContact() {
        return this.selectedTypeContact === 'Mail';
    }

    get isVilleDisabled() {
        return !this.selectedPays;
    }

    get modalTitle() {
        return this.isEditMode ? 'Modifier un passager' : 'Ajouter un passager';
    }

    get submitLabel() {
        return this.isEditMode ? 'Mettre à jour' : 'Enregistrer';
    }

    resetFormState() {
        this.selectedTypeContact = '';
        this.contactValue = '';
        this.selectedPays = '';
        this.selectedVille = '';
        this.villeOptions = [];

        this.prefillName = '';
        this.prefillCivilite = '';
        this.prefillSexe = '';
        this.prefillMaritalStatus = '';
        this.prefillAdresse = '';
        this.prefillPays = '';
        this.prefillVille = '';
        this.prefillContact = '';
    }

    handleAdd() {
        this.isEditMode = false;
        this.editedPassengerId = null;
        this.resetFormState();

        if (this.caseAccountId) {
            this.selectedAccountId = this.caseAccountId;
            this.isModalOpen = true;
            return;
        }

        this.selectedAccountId = '';
        this.showAccountSelector = true;
        this.showNewAccountForm = false;
        this.isAccountModalOpen = true;
    }

    closeAccountModal() {
        this.isAccountModalOpen = false;
        this.showAccountSelector = true;
        this.showNewAccountForm = false;
        this.selectedAccountId = '';
    }

    handleAccountChange(event) {
        this.selectedAccountId = event.detail.value;
    }

    async handleContinueWithAccount() {
        if (!this.selectedAccountId) {
            this.showToast('Erreur', 'Veuillez sélectionner un compte', 'error');
            return;
        }

        try {
            const data = await getAccountPrefillData({ accountId: this.selectedAccountId });

            this.prefillName = data?.Name || '';
            this.prefillCivilite = data?.Civilite__c || '';
            this.prefillSexe = data?.Sexe__c || '';
            this.prefillMaritalStatus = data?.MaritalStatus__c || '';
            this.prefillAdresse = data?.Adresse__c || '';
            this.prefillPays = data?.Pays__c || '';
            this.prefillVille = data?.Ville__c || '';
            this.prefillContact = data?.Email__c || data?.Phone || '';

            this.selectedPays = this.prefillPays;
            this.selectedVille = this.prefillVille;
            this.contactValue = this.prefillContact;

            if (data?.Email__c) {
                this.selectedTypeContact = 'Mail';
            } else if (data?.Phone) {
                this.selectedTypeContact = 'Téléphone';
            } else {
                this.selectedTypeContact = '';
            }

            this.filterVilles();

            this.isAccountModalOpen = false;
            this.isModalOpen = true;
        } catch (error) {
            console.error('Erreur pré-remplissage compte:', error);
            this.showToast('Erreur', 'Impossible de charger les informations du compte sélectionné', 'error');
        }
    }

    handleOpenNewAccountForm() {
        this.showAccountSelector = false;
        this.showNewAccountForm = true;
    }

    handleBackToAccountSelector() {
        this.showAccountSelector = true;
        this.showNewAccountForm = false;
    }

    handleAccountCreated(event) {
        const newAccountId = event.detail.id;
        this.selectedAccountId = newAccountId;

        this.showToast('Succès', 'Compte créé avec succès', 'success');
        this.showAccountSelector = true;
        this.showNewAccountForm = false;
        this.isAccountModalOpen = false;
        this.isModalOpen = true;
    }

    handleAccountError(event) {
        const message =
            event?.detail?.detail ||
            event?.detail?.message ||
            'Erreur lors de la création du compte';

        this.showToast('Erreur', message, 'error');
    }

    handlePaysChange(event) {
        this.selectedPays = event.detail.value;
        this.selectedVille = '';
        this.filterVilles();
    }

    filterVilles() {
        this.villeOptions = [];

        if (!this.selectedPays) {
            return;
        }

        const controllerKey = this.paysControllerValues?.[this.selectedPays];

        if (controllerKey === undefined) {
            return;
        }

        this.villeOptions = this.allVilleValues
            .filter(ville => Array.isArray(ville.validFor) && ville.validFor.includes(controllerKey))
            .map(ville => ({
                label: ville.label,
                value: ville.value
            }));
    }

    handleVilleChange(event) {
        this.selectedVille = event.detail.value;
    }

    handleTypeContactChange(event) {
        this.selectedTypeContact = event.detail.value;
        this.contactValue = '';
    }

    handleContactValueChange(event) {
        this.contactValue = event.target.value;
    }

    closeModal() {
        this.isModalOpen = false;
        this.isEditMode = false;
        this.editedPassengerId = null;
        this.resetFormState();
    }

    async handleSubmit(event) {
        event.preventDefault();
        const fields = { ...event.detail.fields };

        const accountIdToUse = this.selectedAccountId || this.caseAccountId;

        if (!accountIdToUse) {
            this.showToast(
                'Erreur',
                'Veuillez sélectionner ou créer un compte avant d’ajouter un passager.',
                'error'
            );
            return;
        }

        if (!fields.Name || !fields.Name.trim()) {
            this.showToast('Erreur', 'Veuillez renseigner le nom et prénom.', 'error');
            return;
        }

        if (!fields.CIN__c || !fields.CIN__c.trim()) {
            this.showToast('Erreur', 'Veuillez renseigner le CIN.', 'error');
            return;
        }

        if (!this.selectedPays) {
            this.showToast('Erreur', 'Veuillez sélectionner un pays.', 'error');
            return;
        }

        if (!this.selectedVille) {
            this.showToast('Erreur', 'Veuillez sélectionner une ville.', 'error');
            return;
        }

        if (!this.selectedTypeContact) {
            this.showToast('Erreur', 'Veuillez sélectionner un type de contact.', 'error');
            return;
        }

        if (!this.contactValue) {
            this.showToast('Erreur', 'Veuillez renseigner la valeur du contact.', 'error');
            return;
        }

        fields.Case__c = this.recordId;
        fields.Compte__c = accountIdToUse;
        fields.Roles__c = 'Passager assuré';
        fields.Pays__c = this.selectedPays;
        fields.Ville__c = this.selectedVille;
        fields.TypeContact__c = this.selectedTypeContact;
        fields.ContactPassager__c = this.contactValue;

        if (this.isEditMode && this.editedPassengerId) {
            fields.Id = this.editedPassengerId;
        }

        try {
            await savePassenger({ passengerData: fields });

            this.isModalOpen = false;
            this.isEditMode = false;
            this.editedPassengerId = null;
            this.resetFormState();

            this.showToast('Succès', 'Passager enregistré avec succès', 'success');
            await this.loadPassengers();
        } catch (error) {
            const message =
                error?.body?.message ||
                error?.message ||
                'Erreur lors de l’enregistrement du passager';

            this.showToast('Erreur', message, 'error');
        }
    }

    handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;

        if (action === 'edit') {
            this.isEditMode = true;
            this.editedPassengerId = row.Id;
            this.resetFormState();
            this.isModalOpen = true;
        } else if (action === 'delete') {
            deletePassenger({ passengerId: row.Id })
                .then(async () => {
                    this.showToast('Succès', 'Passager supprimé', 'success');
                    await this.loadPassengers();
                })
                .catch(error => {
                    const message = error?.body?.message || 'Erreur lors de la suppression';
                    this.showToast('Erreur', message, 'error');
                });
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}