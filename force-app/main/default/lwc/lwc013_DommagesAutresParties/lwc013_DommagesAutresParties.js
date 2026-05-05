import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import PASSAGER_OBJECT from '@salesforce/schema/Passager__c';
import CASE_OBJECT from '@salesforce/schema/Case';
import OPPOSING_PARTY_FIELD from '@salesforce/schema/Case.OpposingParty__c'; 
import CIVILITE_FIELD from '@salesforce/schema/Passager__c.Civilite__c';
import PAYS_FIELD from '@salesforce/schema/Passager__c.Pays__c';
import VILLE_FIELD from '@salesforce/schema/Passager__c.Ville__c';
import SITUATION_FIELD from '@salesforce/schema/Passager__c.MaritalStatus__c';
import ETAT_PERSONNE_FIELD from '@salesforce/schema/Passager__c.StateOfPerson__c';
import NOTIF_FIELD from '@salesforce/schema/Passager__c.MoyenNotification__c';

export default class Lwc013_DommagesAutresParties extends LightningElement {
    @api claimSummary;
    @track otherParties = [];
    @track isFormVisible = true;
    currentPartyKeyForEdit = null;

    @track formData = {
        OpposingParty__c: '', 
        Nom__c: '',
        Prenom__c: '',
        Civilite__c: '',
        Pays__c: 'Sénégal',
        Ville__c: '',
        Adresse__c: '',
        BirthDay__c: null,
        CIN__c: '',
        MaritalStatus__c: '',
        StateOfPerson__c: '',
        CompagnieAdverse__c: '',
        Numéro_de_contrat__c: '',
        MoyenNotification__c: '',
        Telephone__c: '',
        Email__c: ''
    };

    @track notificationOptions = [];
    @track opposingPartyOptions = [];
    @track civiliteOptions = [];
    @track paysOptions = [];
    @track villeOptions = [];
    @track situationOptions = [];
    @track etatOptions = [];

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT }) caseInfo;
    @wire(getObjectInfo, { objectApiName: PASSAGER_OBJECT }) passagerInfo;

    @wire(getPicklistValues, { recordTypeId: '$passagerInfo.data.defaultRecordTypeId', fieldApiName: NOTIF_FIELD })
    wiredNotif({ data }) { if (data) this.notificationOptions = data.values; }

    @wire(getPicklistValues, { recordTypeId: '$caseInfo.data.defaultRecordTypeId', fieldApiName: OPPOSING_PARTY_FIELD })
    wiredOpposing({ data }) { if (data) this.opposingPartyOptions = data.values; }

    @wire(getPicklistValues, { recordTypeId: '$passagerInfo.data.defaultRecordTypeId', fieldApiName: CIVILITE_FIELD })
    wiredCiv({ data }) { if (data) this.civiliteOptions = data.values; }

    @wire(getPicklistValues, { recordTypeId: '$passagerInfo.data.defaultRecordTypeId', fieldApiName: PAYS_FIELD })
    wiredPays({ data }) { if (data) this.paysOptions = data.values; }

    @wire(getPicklistValues, { recordTypeId: '$passagerInfo.data.defaultRecordTypeId', fieldApiName: VILLE_FIELD })
    wiredVille({ data }) { if (data) this.villeOptions = data.values; }

    @wire(getPicklistValues, { recordTypeId: '$passagerInfo.data.defaultRecordTypeId', fieldApiName: SITUATION_FIELD })
    wiredSitu({ data }) { if (data) this.situationOptions = data.values; }

    @wire(getPicklistValues, { recordTypeId: '$passagerInfo.data.defaultRecordTypeId', fieldApiName: ETAT_PERSONNE_FIELD })
    wiredEtat({ data }) { if (data) this.etatOptions = data.values; }

    get isTelephoneOrSMS() {
        return this.formData.MoyenNotification__c === 'Téléphone' || this.formData.MoyenNotification__c === 'SMS';
    }

    get isEmail() {
        return this.formData.MoyenNotification__c === 'Email';
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.formData[field] = event.target.value;
    }

    handleLookupChange(event) {
        this.formData.CompagnieAdverse__c = event.detail.recordId;
    }

    handleEdit(event) {
        const keyToEdit = event.currentTarget.dataset.key;
        this.currentPartyKeyForEdit = keyToEdit;

        const party = this.otherParties.find(p => p.key.toString() === keyToEdit.toString());
        
        if (party) {
            this.formData = { ...party };
            this.isFormVisible = true;

            setTimeout(() => {
                const picker = this.template.querySelector('lightning-record-picker');
                if (picker && party.CompagnieAdverse__c) {
                    picker.value = party.CompagnieAdverse__c;
                }
            }, 100);
        }
    }

    handleAjouter() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-record-picker')]
            .reduce((v, i) => { 
                if(i.reportValidity) i.reportValidity(); 
                return v && (i.checkValidity ? i.checkValidity() : true); 
            }, true);

        if (allValid) {
            if (this.currentPartyKeyForEdit) {
                this.otherParties = this.otherParties.map(p => {
                    if (p.key.toString() === this.currentPartyKeyForEdit.toString()) {
                        return { ...this.formData, key: p.key }; // On conserve la même clé
                    }
                    return p;
                });
            } else {
                const newParty = { ...this.formData, key: Date.now() };
                this.otherParties = [...this.otherParties, newParty];
            }
            
            const toastMessage = this.currentPartyKeyForEdit ? 'La personne a été mise à jour avec succès.' : 'La personne a été ajoutée à la liste.';
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Succès',
                    message: toastMessage,
                    variant: 'success',
                })
            );

            this.resetForm();
            this.isFormVisible = false;
            this.notifyParent();
        }
    }

    handleDelete(event) {
        const keyToDelete = event.currentTarget.dataset.key;
        this.otherParties = this.otherParties.filter(p => p.key.toString() !== keyToDelete.toString());
        
        if (this.otherParties.length === 0) {
            this.isFormVisible = true; 
        }
        
        this.notifyParent();
    }

    handleAnnuler() {
        this.resetForm();
        if (this.otherParties.length > 0) this.isFormVisible = false;
    }

    showForm() { 
        this.isFormVisible = true;
    }

    resetForm() {
        this.currentPartyKeyForEdit = null; 
        this.formData = { 
            OpposingParty__c: '', Nom__c: '', Prenom__c: '', Civilite__c: '', 
            Pays__c: 'Sénégal', Ville__c: '', Adresse__c: '', BirthDay__c: null, 
            CIN__c: '', MaritalStatus__c: '', StateOfPerson__c: '', 
            CompagnieAdverse__c: '', Numéro_de_contrat__c: '', MoyenNotification__c: '',
            Telephone__c: '', Email__c: ''
        };
        const picker = this.template.querySelector('lightning-record-picker');
        if (picker) {
            picker.clearSelection();
        }
    }

    notifyParent() {
        this.dispatchEvent(new CustomEvent('otherpartiesupdate', { detail: this.otherParties }));
    }

    @api validate() {
       return true;
    }
}