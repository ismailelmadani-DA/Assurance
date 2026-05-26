import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; 
import getDocumentsBySinistre from '@salesforce/apex/DocumentGEDController.getDocumentsBySinistre';
import deleteDocument from '@salesforce/apex/DocumentGEDController.deleteDocument'; 

export default class Da_documentsList extends NavigationMixin(LightningElement) {
    @api recordId;
    @track documents = [];
    @track isLoading = true;
    @track showFormModal = false; 
    @track selectedDocumentId = null;
    @track selectedDocumentId = null;

    wiredResult;
    @wire(getDocumentsBySinistre, { sinistreId: '$recordId' })
        wiredDocs(result) {
            this.wiredResult = result;
            
            console.log('--- DEBUG CHARGEMENT DOCUMENTS ---');
            console.log('1. ID de la page (recordId) :', this.recordId);

            if (result.data) {
                console.log('2. Succès ! Documents reçus :', JSON.stringify(result.data));
                this.documents = result.data;
                this.isLoading = false;
            } else if (result.error) {
                console.error('2. ERREUR APEX détectée :', JSON.stringify(result.error));
                this.isLoading = false;
            }
        }

    get hasRecords() { return this.documents && this.documents.length > 0; }
    get totalLabel() { 
        const count = this.documents ? this.documents.length : 0;
        return `${count} DOCUMENT${count > 1 ? 'S' : ''}`; 
    }

    get modalTitle() {
        return this.selectedDocumentId ? 'Modification de document' : 'Numérisation de Documents';
    }
    handleAdd() {
        this.selectedDocumentId = null; 
        this.showFormModal = true;
    }

    handleEditRecord(event) {
        this.selectedDocumentId = event.currentTarget.dataset.id; 
        
        this.showFormModal = true; 
    }

    closeModal() {
        this.showFormModal = false;
        this.selectedDocumentId = null; 
    }

    handleModalClose() {
        this.closeModal();
        this.handleRefresh(); 
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredResult).finally(() => { this.isLoading = false; });
    }

    handleViewRecordStandard(event) {
        const docId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: docId, actionName: 'view' }
        });
    }

    handleViewRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        
        const doc = this.documents.find(item => item.Id === recordId);
        
        if (doc && doc.IdDocument__c) {
            const googleDriveUrl = `https://drive.google.com/file/d/${doc.IdDocument__c}/view`;
            
            window.open(googleDriveUrl, '_blank');
        } else {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Erreur',
                message: 'Lien Google Drive introuvable pour ce document.',
                variant: 'error'
            }));
        }
    }

   

    handleDeleteRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        
        if(confirm('Êtes-vous sûr de vouloir supprimer ce document ? Cette action est irréversible.')) {
            this.isLoading = true;
            
            deleteDocument({ documentId: recordId })
                .then(() => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Succès',
                        message: 'Le document a été supprimé.',
                        variant: 'success'
                    }));
                    this.handleRefresh();
                })
                .catch(error => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Erreur',
                        message: 'Impossible de supprimer le document : ' + error.body.message,
                        variant: 'error'
                    }));
                    this.isLoading = false;
                });
        }
    }
}