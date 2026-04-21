import { LightningElement, api, track, wire } from 'lwc';
import getPicklistValues from '@salesforce/apex/ClaimSearchController.getPicklistValues';
// IMPORT POUR LES NOTIFICATIONS TOAST
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Lwc011_PassagersAssure extends LightningElement {
    @api claimSummary;
    
    // --- Liste des passagers ajoutés ---
    @track passengers = [];
    
    // --- État du formulaire ---
    @track isFormVisible = false;
    
    // --- Modèle pour un nouveau passager ---
    @track newPassager = {
        Name__c: '', 
        CIN__c: '',
        Civilite__c: '',
        BirthDay__c: null,
        MaritalStatus__c: '',
        Pays__c: '',
        Ville__c: '',
        Adresse__c: '',
        StateOfPerson__c: ''
    };

    // --- Options pour les listes déroulantes ---
    @track civilityOptions = []; 
    @track paysOptions = [];
    @track villeOptions = [];
    @track maritalOptions = []; 
    @track stateOptions = [];

    // --- Récupération des valeurs de Picklist via Apex ---
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

    // --- Actions sur le formulaire ---
    showForm() { 
        this.isFormVisible = true;
    }
    
    hideForm() { 
        this.isFormVisible = false; 
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
            const newEntry = { ...this.newPassager, key: Date.now() };
            this.passengers = [...this.passengers, newEntry];
            
            // DÉCLENCHEMENT DU TOAST DE SUCCÈS
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Succès',
                    message: 'Le passager a été ajouté à la liste.',
                    variant: 'success',
                })
            );
            
            this.resetForm();
            this.hideForm();
            this.notifyParent();
        }
    }

    // --- NOUVELLE MÉTHODE : Suppression d'un passager ---
    handleDelete(event) {
        // On récupère la clé du passager via le dataset du bouton cliqué
        const keyToDelete = event.currentTarget.dataset.key;
        
        // On filtre la liste pour ne garder que les passagers dont la clé est différente
        this.passengers = this.passengers.filter(p => p.key.toString() !== keyToDelete.toString());
        
        // On notifie le parent de la mise à jour
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

    @api validate() {
        return true;
    }
    
    get passengersCount() {
        return this.passengers.length;
    }

    get hasPassengers() {
        return this.passengers.length > 0;
    }
}