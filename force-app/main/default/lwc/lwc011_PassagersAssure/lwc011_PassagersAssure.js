import { LightningElement, api, track, wire } from 'lwc';
import getPicklistValues from '@salesforce/apex/ClaimSearchController.getPicklistValues';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Lwc011_PassagersAssure extends LightningElement {
    @api claimSummary;

    @api
    get savedPassengers() {
        return this._savedPassengers;
    }
    set savedPassengers(value) {
        if (value && value.length > 0) {
            this._savedPassengers = value;
            this.passengers = [...value];
        }
    }
    _savedPassengers = [];

    @track passengers = [];
    @track isFormVisible = false;
    currentPassengerKey = null;

    @track newPassager = {
        Name__c: '', CIN__c: '', Civilite__c: '', BirthDay__c: null,
        MaritalStatus__c: '', Pays__c: '', Ville__c: '', Adresse__c: '', StateOfPerson__c: ''
    };

    @track civilityOptions = [];
    @track paysOptions = [];
    @track villeOptions = [];
    @track maritalOptions = [];
    @track stateOptions = [];

    @wire(getPicklistValues, { objectName: 'Passager__c', fieldName: 'Civilite__c' })
    wiredCiv({ data }) { if (data) this.civilityOptions = data; }

    @wire(getPicklistValues, { objectName: 'Passager__c', fieldName: 'Pays__c' })
    wiredPays({ data }) { if (data) this.paysOptions = data; }

    @wire(getPicklistValues, { objectName: 'Passager__c', fieldName: 'Ville__c' })
    wiredVille({ data }) { if (data) this.villeOptions = data; }

    @wire(getPicklistValues, { objectName: 'Passager__c', fieldName: 'StateOfPerson__c' })
    wiredState({ data }) { if (data) this.stateOptions = data; }

    @wire(getPicklistValues, { objectName: 'Passager__c', fieldName: 'MaritalStatus__c' })
    wiredMarital({ data }) { if (data) this.maritalOptions = data; }

    showForm() { this.isFormVisible = true; }

    hideForm() {
        this.isFormVisible = false;
        this.currentPassengerKey = null;
        this.resetForm();
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.newPassager[field] = event.target.value;
    }

    handleAjouter() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);

        if (allValid) {
            if (this.currentPassengerKey) {
                this.passengers = this.passengers.map(p => {
                    if (p.key.toString() === this.currentPassengerKey.toString()) {
                        return { ...this.newPassager, key: p.key };
                    }
                    return p;
                });
            } else {
                const newEntry = { ...this.newPassager, key: Date.now() };
                this.passengers = [...this.passengers, newEntry];
            }

            this.dispatchEvent(new ShowToastEvent({
                title: 'Succès',
                message: this.currentPassengerKey ? 'Passager mis à jour.' : 'Passager ajouté.',
                variant: 'success'
            }));

            this.resetForm();
            this.hideForm();
            this.notifyParent();
        }
    }

    handleEdit(event) {
        const keyToEdit = event.currentTarget.dataset.key;
        this.currentPassengerKey = keyToEdit;
        const passengerToEdit = this.passengers.find(p => p.key.toString() === keyToEdit.toString());
        if (passengerToEdit) {
            this.newPassager = { ...passengerToEdit };
            this.isFormVisible = true;
        }
    }

    handleDelete(event) {
        const keyToDelete = event.currentTarget.dataset.key;
        this.passengers = this.passengers.filter(p => p.key.toString() !== keyToDelete.toString());
        this.notifyParent();
    }

    resetForm() {
        this.newPassager = {
            Name__c: '', CIN__c: '', Civilite__c: '', BirthDay__c: null,
            MaritalStatus__c: '', Pays__c: '', Ville__c: '', Adresse__c: '', StateOfPerson__c: ''
        };
    }

    notifyParent() {
        this.dispatchEvent(new CustomEvent('passengersupdate', { detail: this.passengers }));
    }

    @api validate() { return true; }

    get passengersCount() { return this.passengers.length; }
    get hasPassengers() { return this.passengers.length > 0; }
}