import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';

// Imports Objets et Champs
import PASSAGER_OBJECT from '@salesforce/schema/Passager__c';
import CLAIM_OBJECT from '@salesforce/schema/Claim__c';
import OPPOSING_PARTY_FIELD from '@salesforce/schema/Claim__c.OpposingParty__c';
import CIVILITE_FIELD from '@salesforce/schema/Passager__c.Civilite__c';
import PAYS_FIELD from '@salesforce/schema/Passager__c.Pays__c';
import VILLE_FIELD from '@salesforce/schema/Passager__c.Ville__c';
import SITUATION_FIELD from '@salesforce/schema/Passager__c.MaritalStatus__c';
import ETAT_PERSONNE_FIELD from '@salesforce/schema/Passager__c.StateOfPerson__c';

// CORRECTION DU NOM D'API : MoyenNotification__c
import NOTIF_FIELD from '@salesforce/schema/Passager__c.MoyenNotification__c';

export default class Lwc013_DommagesAutresParties extends LightningElement {
    @api claimSummary;
    @track otherParties = []; // Liste des personnes ajoutées
    @track isFormVisible = true;

    // CORRECTION DU NOM D'API DANS LE FORM DATA
    @track formData = {
        OpposingParty__c: '', // Champ sur Claim
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
        MoyenNotification__c: '' 
    };

    // Options Picklists
    @track notificationOptions = [];
    @track opposingPartyOptions = [];
    @track civiliteOptions = [];
    @track paysOptions = [];
    @track villeOptions = [];
    @track situationOptions = [];
    @track etatOptions = [];

    // --- Wire Metadata ---
    @wire(getObjectInfo, { objectApiName: CLAIM_OBJECT }) claimInfo;
    @wire(getObjectInfo, { objectApiName: PASSAGER_OBJECT }) passagerInfo;

    // Récupération des valeurs pour Moyen de notification
    @wire(getPicklistValues, { 
        recordTypeId: '$passagerInfo.data.defaultRecordTypeId', 
        fieldApiName: NOTIF_FIELD 
    })
    wiredNotif({ data }) { 
        if (data) {
            this.notificationOptions = data.values; 
        } 
    }

    @wire(getPicklistValues, { recordTypeId: '$claimInfo.data.defaultRecordTypeId', fieldApiName: OPPOSING_PARTY_FIELD })
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

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.formData[field] = event.target.value;
    }

    handleLookupChange(event) {
        this.formData.CompagnieAdverse__c = event.detail.recordId;
    }

    handleAjouter() {
        // Validation incluant le lightning-record-picker
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-record-picker')]
            .reduce((v, i) => { 
                if(i.reportValidity) i.reportValidity(); 
                return v && (i.checkValidity ? i.checkValidity() : true); 
            }, true);

        if (allValid) {
            const newParty = { ...this.formData, key: Date.now() };
            this.otherParties = [...this.otherParties, newParty];
            this.resetForm();
            this.isFormVisible = false;
            this.notifyParent();
        }
    }

    handleAnnuler() {
        this.resetForm();
        if (this.otherParties.length > 0) this.isFormVisible = false;
    }

    showForm() { this.isFormVisible = true; }

    resetForm() {
        // Remise à zéro avec les bons noms d'API
        this.formData = { 
            OpposingParty__c: '', Nom__c: '', Prenom__c: '', Civilite__c: '', 
            Pays__c: 'Sénégal', Ville__c: '', Adresse__c: '', BirthDay__c: null, 
            CIN__c: '', MaritalStatus__c: '', StateOfPerson__c: '', 
            CompagnieAdverse__c: '', Numéro_de_contrat__c: '', MoyenNotification__c: '' 
        };

        // Vider le champ de recherche de compagnie proprement
        const picker = this.template.querySelector('lightning-record-picker');
        if (picker) {
            picker.clearSelection();
        }
    }

    notifyParent() {
        this.dispatchEvent(new CustomEvent('otherpartiesupdate', { detail: this.otherParties }));
    }

    @api validate() {
       // return this.otherParties.length > 0;
       return true; // Permet de passer à l'étape suivante même sans ajouter d'autres parties
    }
}