import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDocumentsBySinistre from '@salesforce/apex/DocumentGEDController.getDocumentsBySinistre';
import deleteDocument from '@salesforce/apex/DocumentGEDController.deleteDocument';
import getDocumentsByInstruction from '@salesforce/apex/DocumentGEDController.getDocumentsByInstruction';
import getClaimIdForInstruction from '@salesforce/apex/DocumentGEDController.getClaimIdForInstruction';
import unlinkDocumentFromInstruction from '@salesforce/apex/DocumentGEDController.unlinkDocumentFromInstruction';
import moveRecentDocumentLinksToInstruction from '@salesforce/apex/DocumentGEDController.moveRecentDocumentLinksToInstruction';

export default class Da_documentsList extends NavigationMixin(LightningElement) {
    @api recordId;
    @api enableAssociate = false;
    @api parentObjectApi;
    @api parentLinkField;
    @api claimLookupField;

    @track documents = [];
    @track isLoading = true;
    @track showFormModal = false;
    @track showAssociateModal = false;
    @track selectedDocumentId = null;
    @track claimId;

    wiredResult;
    uploadStartedAt = null;

    get isInstructionMode() {
        return this.enableAssociate === true || this.enableAssociate === 'true';
    }

    get effectiveRecordIdForModal() {
        if (this.isInstructionMode && this.claimId) {
            return this.claimId;
        }
        return this.recordId;
    }

    get instructionIdForWire() {
        return this.isInstructionMode ? this.recordId : null;
    }

    @wire(getClaimIdForInstruction, { instructionId: '$instructionIdForWire' })
    wiredClaimId({ data, error }) {
        if (!this.isInstructionMode) {
            return;
        }
        if (data) {
            this.claimId = data;
        } else if (error) {
            console.error('Erreur résolution sinistre depuis instruction :', JSON.stringify(error));
        }
    }

    @wire(getDocumentsBySinistre, { sinistreId: '$recordId' })
    wiredSinistreDocs(result) {
        if (this.isInstructionMode) {
            return;
        }
        this.wiredResult = result;
        if (result.data) {
            this.documents = result.data;
            this.isLoading = false;
        } else if (result.error) {
            console.error('Erreur chargement documents (sinistre):', JSON.stringify(result.error));
            this.isLoading = false;
        }
    }

    @wire(getDocumentsByInstruction, { instructionId: '$instructionIdForWire' })
    wiredParentDocs(result) {
        if (!this.isInstructionMode) {
            return;
        }
        this.wiredResult = result;
        if (result.data) {
            this.documents = result.data;
            this.isLoading = false;
        } else if (result.error) {
            console.error('Erreur chargement documents (parent):', JSON.stringify(result.error));
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
        if (this.isInstructionMode && !this.claimId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Erreur',
                message: 'Sinistre lié à cette instruction introuvable.',
                variant: 'error'
            }));
            return;
        }
        this.selectedDocumentId = null;
        this.uploadStartedAt = Date.now();
        this.showFormModal = true;
    }

    handleEditRecord(event) {
        this.selectedDocumentId = event.currentTarget.dataset.id;
        this.uploadStartedAt = null;
        this.showFormModal = true;
    }

    closeModal() {
        this.showFormModal = false;
        this.selectedDocumentId = null;
    }

    handleModalClose() {
        const wasAdd = !this.selectedDocumentId;
        const startedAt = this.uploadStartedAt;
        this.closeModal();
        this.uploadStartedAt = null;

        if (wasAdd && this.isInstructionMode && this.claimId && startedAt) {
            moveRecentDocumentLinksToInstruction({
                instructionId: this.recordId,
                claimId: this.claimId,
                sinceMillis: startedAt
            })
                .then(count => {
                    if (count > 0) {
                        this.dispatchEvent(new ShowToastEvent({
                            title: 'Succès',
                            message: count + ' document(s) ajouté(s) à l\'instruction.',
                            variant: 'success'
                        }));
                    }
                })
                .catch(error => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Erreur',
                        message: error && error.body && error.body.message
                            ? error.body.message
                            : 'Erreur lors du rattachement à l\'instruction.',
                        variant: 'error'
                    }));
                })
                .finally(() => this.handleRefresh());
        } else {
            this.handleRefresh();
        }
    }

    handleAssociate() {
        this.showAssociateModal = true;
    }

    closeAssociateModal() {
        this.showAssociateModal = false;
    }

    handleAssociateSuccess() {
        this.closeAssociateModal();
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
        const docId = event.currentTarget.dataset.id;

        if (this.isInstructionMode) {
            if (!confirm('Voulez-vous dissocier ce document de cette instruction ? Le document reste disponible sur le sinistre.')) {
                return;
            }
            this.isLoading = true;
            unlinkDocumentFromInstruction({
                instructionId: this.recordId,
                documentId: docId
            })
                .then(() => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Succès',
                        message: 'Document dissocié de l\'instruction.',
                        variant: 'success'
                    }));
                    this.handleRefresh();
                })
                .catch(error => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Erreur',
                        message: error && error.body && error.body.message
                            ? error.body.message
                            : 'Erreur lors de la dissociation.',
                        variant: 'error'
                    }));
                    this.isLoading = false;
                });
            return;
        }

        if (confirm('Êtes-vous sûr de vouloir supprimer ce document ? Cette action est irréversible.')) {
            this.isLoading = true;

            deleteDocument({ documentId: docId })
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
