import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { deleteRecord } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAdversePassengers from '@salesforce/apex/DA_PassagerAdverseController.getAdversePassengers';

const COLUMNS = [
    { label: 'Civilité', fieldName: 'Civilite__c' },
    { label: 'Nom et Prénom', fieldName: 'Name' },
    { label: 'CNI', fieldName: 'CNI__c' }, // <-- Correction ici aussi
    { label: 'Pays', fieldName: 'Pays__c' },
    { label: 'Ville', fieldName: 'Ville__c' },
    { label: 'Véhicule', fieldName: 'RegistrationNumber__c' },
    { label: 'État', fieldName: 'StateOfPerson__c' },
    { label: 'Conducteur', fieldName: 'isDriver__c', type: 'boolean' },
    { type: 'action', typeAttributes: { rowActions: [
        { label: 'Modifier', name: 'edit' },
        { label: 'Supprimer', name: 'delete' }
    ]}}
];

export default class DALwc007PassagerAdverseManager extends NavigationMixin(LightningElement) {
    @api recordId; // ID de la Déclaration (Case)
    @track data = [];
    columns = COLUMNS;
    wiredResult;

    @wire(getAdversePassengers, { caseId: '$recordId' })
    wiredPassengers(result) {
        this.wiredResult = result;
        if (result.data) {
            this.data = result.data;
        } else if (result.error) {
            console.error(result.error);
        }
    }

    get hasRecords() {
        return this.data && this.data.length > 0;
    }

    // Création d'un passager
    handleCreate() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Passager__c', actionName: 'new' },
            state: { defaultFieldValues: `Case__c=${this.recordId},Roles__c=Passager adverse` }
        });
    }

    // Gestion des lignes (Modifier/Supprimer)
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const rowId = event.detail.row.Id;
        if (actionName === 'edit') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: rowId, actionName: 'edit' }
            });
        } else if (actionName === 'delete') {
            this.handleDelete(rowId);
        }
    }

    handleDelete(rowId) {
        deleteRecord(rowId)
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Succès', message: 'Passager supprimé', variant: 'success' }));
                return refreshApex(this.wiredResult);
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Erreur', message: error.body.message, variant: 'error' }));
            });
    }
}