import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation'; // ← 1. AJOUTER cet import
import getPassagersAdverses from '@salesforce/apex/DA_LWC008_ListPassagerAdverseController.getPassagersAdverses';

const PAGE_SIZE = 10;

export default class DA_lwc008_ListPassagerAdverse extends NavigationMixin(LightningElement) { // ← 2. MODIFIER cette ligne

    @api recordId;
    @api isReadonly = false;
    @track records         = [];
    @track filteredRecords = [];
    @track isLoading       = false;
    @track hasError        = false;
    @track errorMessage    = '';
    @track currentPage     = 1;

    connectedCallback() {
        this.loadPassagers();
    }

    async loadPassagers() {
        if (!this.recordId) return;
        this.isLoading = true;
        this.hasError  = false;
        try {
            const raw = await getPassagersAdverses({ caseId: this.recordId });
            this.records = raw.map(r => this._enrichRecord(r));
            this._applyFilter();
        } catch (e) {
            this.hasError     = true;
            this.errorMessage = this._cleanError(e);
        } finally {
            this.isLoading = false;
        }
    }

   _enrichRecord(r) {
    const stateClass = {
        'Blessé':  'pm-state pm-state--blesse',
        'Décédé':  'pm-state pm-state--deces',
        'Indemne': 'pm-state pm-state--indemne',
    }[r.StateOfPerson__c] || 'pm-state pm-state--default';

    return {
        ...r,
        stateClass,
        fullName: r.Name || '—',  // ✅ Name = vrai nom saisi
        RegistrationNumber__c: r.Vehicule__r?.RegistrationNumber__c || '—'
    };
}

    // ← 4. AJOUTER cette méthode
    handleNameClick(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                actionName: 'view'
            }
        });
    }

    _applyFilter() {
        this.filteredRecords = this.records.slice(
            (this.currentPage - 1) * PAGE_SIZE,
            this.currentPage * PAGE_SIZE
        );
    }

    get totalPages()     { return Math.max(1, Math.ceil(this.records.length / PAGE_SIZE)); }
    get showPagination() { return this.totalPages > 1; }
    get hasRecords()     { return this.filteredRecords.length > 0; }
    get isFirstPage()    { return this.currentPage === 1; }
    get isLastPage()     { return this.currentPage === this.totalPages; }
    get prevClass()      { return `pm-btn pm-btn--page${this.isFirstPage ? ' pm-btn--disabled' : ''}`; }
    get nextClass()      { return `pm-btn pm-btn--page${this.isLastPage  ? ' pm-btn--disabled' : ''}`; }
    get totalLabel() {
        const n = this.records.length;
        return `${n} passager${n > 1 ? 's' : ''} adverse${n > 1 ? 's' : ''}`;
    }

    prevPage() { if (!this.isFirstPage) { this.currentPage--; this._applyFilter(); } }
    nextPage() { if (!this.isLastPage)  { this.currentPage++; this._applyFilter(); } }

    handleRefresh() { this.loadPassagers(); }

    _cleanError(e) {
        const raw = e?.body?.message || e?.message || '';
        if (!raw || raw.includes('FIELD_INTEGRITY') || raw.includes('EXCEPTION') || raw.includes('first error')) {
            return 'Une erreur est survenue lors du traitement. Veuillez réessayer.';
        }
        if (raw.includes('INSUFFICIENT_ACCESS')) {
            return "Vous n'avez pas les droits nécessaires pour effectuer cette action.";
        }
        return raw;
    }
}