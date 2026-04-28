import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getMissionsByPrestataire from '@salesforce/apex/DA_lwc017_PrestataireMissionsController.getMissionsByPrestataire';

const PAGE_SIZE = 10;

export default class DA_lwc017_prestataireMissions extends NavigationMixin(LightningElement) {

    @api recordId;

    @track records = [];
    @track filteredRecords = [];
    @track isLoading = false;
    @track hasError = false;
    @track errorMessage = '';
    @track currentPage = 1;

    @wire(getMissionsByPrestataire, { accountId: '$recordId' })
    wiredMissions({ data, error }) {
        this.isLoading = true;
        
        if (data) {
            console.log('Missions reçues:', data.length);
            this.records = data.map(r => ({
                id: r.id,
                caseNumber: r.caseNumber,
                natureMission: r.natureMission || '—',
                status: r.status || '—',
                createdDate: r.createdDate,
                createdById: r.createdById,
                createdByName: r.createdByName || '—',
                hasCreatedBy: !!r.createdById,
                statusClass: this._getStatusClass(r.status),
                natureClass: this._getNatureClass(r.natureMission)
            }));
            this.currentPage = 1;
            this._applyPage();
            this.hasError = false;
            this.errorMessage = '';
        } else if (error) {
            console.error('Erreur:', error);
            this.hasError = true;
            this.errorMessage = error?.body?.message || 'Une erreur est survenue lors du chargement des missions.';
            this.records = [];
            this.filteredRecords = [];
        }
        
        this.isLoading = false;
    }

    _getStatusClass(status) {
        if (!status) return 'slds-badge';
        
        const lowerStatus = status.toLowerCase();
        if (lowerStatus.includes('clos') || lowerStatus.includes('fermé') || lowerStatus.includes('closed') || lowerStatus.includes('termine')) {
            return 'slds-badge slds-theme_success';
        } else if (lowerStatus.includes('cours') || lowerStatus.includes('progress') || lowerStatus.includes('en cours')) {
            return 'slds-badge slds-theme_warning';
        } else if (lowerStatus.includes('nouveau') || lowerStatus.includes('new')) {
            return 'slds-badge slds-theme_info';
        } else if (lowerStatus.includes('annul') || lowerStatus.includes('cancel')) {
            return 'slds-badge slds-theme_error';
        } else {
            return 'slds-badge slds-theme_light';
        }
    }

    _getNatureClass(natureMission) {
        if (!natureMission) return 'slds-badge slds-theme_light';
        
        const lowerNature = natureMission.toLowerCase();
        if (lowerNature.includes('expertise automobile') || lowerNature.includes('expertise classique') || 
            lowerNature.includes('expertise additive') || lowerNature.includes('expertise contradictoire') ||
            lowerNature.includes('expertise sur document')) {
            return 'slds-badge slds-theme_info';
        } else if (lowerNature.includes('réparation')) {
            return 'slds-badge slds-theme_warning';
        } else if (lowerNature.includes('judiciaire') || lowerNature.includes('procédure') || 
                   lowerNature.includes('consultation') || lowerNature.includes('recours') ||
                   lowerNature.includes('sommation')) {
            return 'slds-badge slds-theme_error';
        } else if (lowerNature.includes('médical') || lowerNature.includes('medicolégal')) {
            return 'slds-badge slds-theme_success';
        } else if (lowerNature.includes('fraude') || lowerNature.includes('suspicion')) {
            return 'slds-badge slds-theme_alert';
        } else {
            return 'slds-badge slds-theme_default';
        }
    }

    _applyPage() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        const end = start + PAGE_SIZE;
        this.filteredRecords = this.records.slice(start, end);
    }

    // Getters
    get hasRecords() {
        return this.records && this.records.length > 0;
    }

    get totalLabel() {
        return `${this.records.length} mission${this.records.length > 1 ? 's' : ''}`;
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.records.length / PAGE_SIZE));
    }

    get showPagination() {
        return this.totalPages > 1;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    get isEmpty() {
        return !this.isLoading && !this.hasError && this.records.length === 0;
    }

    // Méthodes de navigation
    navigateToCase(event) {
        const caseId = event.currentTarget.dataset.id;
        if (caseId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: caseId,
                    objectApiName: 'Case',
                    actionName: 'view'
                }
            });
        }
    }

    navigateToUser(event) {
        const userId = event.currentTarget.dataset.id;
        if (userId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: userId,
                    objectApiName: 'User',
                    actionName: 'view'
                }
            });
        }
    }

    // Pagination
    previousPage() {
        if (!this.isFirstPage) {
            this.currentPage--;
            this._applyPage();
        }
    }

    nextPage() {
        if (!this.isLastPage) {
            this.currentPage++;
            this._applyPage();
        }
    }
}