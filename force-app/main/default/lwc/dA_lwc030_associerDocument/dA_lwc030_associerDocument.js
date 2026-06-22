import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAvailableDocumentsForInstruction from '@salesforce/apex/DocumentGEDController.getAvailableDocumentsForInstruction';
import associateDocumentsToInstruction from '@salesforce/apex/DocumentGEDController.associateDocumentsToInstruction';

export default class DA_lwc030_associerDocument extends NavigationMixin(LightningElement) {
    @api recordId;

    @track availableDocs = [];
    @track isLoading = false;
    @track selectedIds = new Set();

    connectedCallback() {
        this.loadAvailableDocs();
    }

    loadAvailableDocs() {
        this.isLoading = true;
        getAvailableDocumentsForInstruction({ instructionId: this.recordId })
            .then(result => {
                this.availableDocs = (result || []).map(d => ({
                    ...d,
                    selected: false,
                    rowClass: 'assoc-row'
                }));
            })
            .catch(error => {
                this.showToast('Erreur', this.extractError(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get hasDocuments() {
        return this.availableDocs && this.availableDocs.length > 0;
    }

    get isConfirmDisabled() {
        return this.selectedIds.size === 0 || this.isLoading;
    }

    handleToggle(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        const checked = event.currentTarget.checked;
        this.applySelection(id, checked);
    }

    handleRowClick(event) {
        if (event.target.tagName === 'A' || event.target.closest('lightning-input')) {
            return;
        }
        const id = event.currentTarget.dataset.id;
        const doc = this.availableDocs.find(d => d.Id === id);
        if (!doc) {
            return;
        }
        this.applySelection(id, !doc.selected);
    }

    applySelection(id, checked) {
        const next = new Set(this.selectedIds);
        if (checked) {
            next.add(id);
        } else {
            next.delete(id);
        }
        this.selectedIds = next;
        this.availableDocs = this.availableDocs.map(d =>
            d.Id === id
                ? { ...d, selected: checked, rowClass: checked ? 'assoc-row assoc-row--selected' : 'assoc-row' }
                : d
        );
    }

    handleOpenDoc(event) {
        const docId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: docId, actionName: 'view' }
        });
    }

    handleConfirm() {
        if (this.selectedIds.size === 0) {
            return;
        }
        this.isLoading = true;
        associateDocumentsToInstruction({
            instructionId: this.recordId,
            documentIds: Array.from(this.selectedIds)
        })
            .then(count => {
                this.showToast(
                    'Succès',
                    count + ' document(s) associé(s) à l\'instruction.',
                    'success'
                );
                this.dispatchEvent(new CustomEvent('success', { detail: { count } }));
            })
            .catch(error => {
                this.showToast('Erreur', this.extractError(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    extractError(error) {
        if (!error) {
            return 'Erreur inconnue.';
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        return error.message || 'Erreur inconnue.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}