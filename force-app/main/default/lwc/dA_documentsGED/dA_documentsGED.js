import { LightningElement, api, track, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import GED_OBJECT from '@salesforce/schema/Document__c'; 

import DIRECTORY_FIELD from '@salesforce/schema/Document__c.Directory__c';
import TYPE_DOC_FIELD from '@salesforce/schema/Document__c.Type_de_document__c';
import NATURE_FIELD from '@salesforce/schema/Document__c.Nature__c';
import ISSUER_FIELD from '@salesforce/schema/Document__c.Issuer__c';

export default class DA_documentsGED extends LightningElement {
    @api recordId; 
    @track currentDate = new Date().toISOString().split('T')[0];

    @track repertoireOptions = [];
    @track typeDocOptions = [];
    @track natureOptions = [];
    @track emetteurOptions = [];

    @wire(getObjectInfo, { objectApiName: GED_OBJECT })
    objectInfo;

    get recordTypeId() {
        return this.objectInfo.data ? this.objectInfo.data.defaultRecordTypeId : null;
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: DIRECTORY_FIELD })
    wiredDirectory({ data, error }) {
        if (data) this.repertoireOptions = data.values;
        else if (error) console.error('Erreur chargement Répertoire', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: TYPE_DOC_FIELD })
    wiredTypeDoc({ data, error }) {
        if (data) this.typeDocOptions = data.values;
        else if (error) console.error('Erreur chargement Type de document', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: NATURE_FIELD })
    wiredNature({ data, error }) {
        if (data) this.natureOptions = data.values;
        else if (error) console.error('Erreur chargement Nature', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: ISSUER_FIELD })
    wiredIssuer({ data, error }) {
        if (data) this.emetteurOptions = data.values;
        else if (error) console.error('Erreur chargement Émetteur', error);
    }

    get entiteOptions() { return [{ label: 'AUTO', value: 'AUTO' }]; }

    get uniteGestionOptions() { return [{ label: 'UG Centre', value: 'UG Centre' }]; }

    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg'];
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        console.log('Fichiers uploadés : ', JSON.stringify(uploadedFiles));
    }

    handleEnvoyer() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);

        if (allValid) {
            const formData = {
                Directory__c: this.template.querySelector('[name="Directory__c"]').value,
                Type_de_document__c: this.template.querySelector('[name="Type_de_document__c"]').value,
                Nature__c: this.template.querySelector('[name="Nature__c"]').value,
                NumeroDeclaration__c: this.template.querySelector('[name="NumeroDeclaration__c"]').value,
                Sinistre__c: this.template.querySelector('[name="Sinistre__c"]').value,
                Police__c: this.template.querySelector('[name="Police__c"]').value,
                RegistrationNumber__c: this.template.querySelector('[name="RegistrationNumber__c"]').value,
                OccurrenceDate__c: this.template.querySelector('[name="OccurrenceDate__c"]').value,
                dateOfReceipt__c: this.template.querySelector('[name="dateOfReceipt__c"]').value,
                ScanDate__c: this.template.querySelector('[name="ScanDate__c"]').value,
                Issuer__c: this.template.querySelector('[name="Issuer__c"]').value
            };
            
            console.log('Payload prêt pour Apex : ', JSON.parse(JSON.stringify(formData)));
            
        } else {
            console.error('Validation échouée : Veuillez remplir tous les champs obligatoires.');
        }
    }
}