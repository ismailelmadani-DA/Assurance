import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';  // ✅ AJOUT
import { refreshApex } from '@salesforce/apex';
import getRibs          from '@salesforce/apex/DA_lwc018_prestataireRibController.getRibs';
import getBanqueOptions from '@salesforce/apex/DA_lwc018_prestataireRibController.getBanqueOptions';

const PAGE_SIZE = 10;

export default class DA_lwc018_prestataireRibs extends NavigationMixin(LightningElement) {


    @api recordId;

    @track records      = [];
    @track isLoading    = false;
    @track hasError     = false;
    @track errorMessage = '';
    @track currentPage  = 1;

    _wiredResult;
    _rawRibData    = [];          // données brutes RIB avant résolution des labels
    _banqueLabels  = {};          // map { value -> label } picklist banques
    _banquesReady  = false;       // flag : picklist chargée
    _ribsReady     = false;       // flag : ribs chargés

    /* ── Wire : picklist banques ───────────────────────── */

    @wire(getBanqueOptions)
    wiredBanques({ data, error }) {
        if (data) {
            this._banqueLabels = data.reduce((acc, opt) => {
                acc[opt.value] = opt.label;
                return acc;
            }, {});
            this._banquesReady = true;
            // Si les RIBs étaient déjà arrivés, on peut résoudre les labels maintenant
            if (this._ribsReady) {
                this._resolveRecords();
            }
        }
        if (error) {
            // Picklist non critique : on continue sans les labels
            this._banquesReady = true;
            if (this._ribsReady) {
                this._resolveRecords();
            }
        }
    }

    /* ── Wire : liste des RIBs ─────────────────────────── */

    @wire(getRibs, { accountId: '$recordId' })
    wiredData(result) {
        this._wiredResult = result;

        if (result.data) {
            this._rawRibData = result.data;
            this._ribsReady  = true;
            this.hasError    = false;

            // Résoudre uniquement si la picklist est aussi prête
            if (this._banquesReady) {
                this._resolveRecords();
            }
        }

        if (result.error) {
            this.hasError     = true;
            this.errorMessage = result.error?.body?.message || 'Une erreur est survenue.';
            this.records      = [];
            this.isLoading    = false;
        }
    }

    /* ── Résolution des labels banque ──────────────────── */

    _resolveRecords() {
        this.records = this._rawRibData.map(r => ({
            id:         r.Id,
            rib:        r.RIB__c        || '',
            banque:     this._banqueLabels[r.CodeBanque__c] || r.CodeBanque__c || '—',
            codeBanque: r.CodeBanque__c || '—',
            actifLabel: r.Actif__c ? 'Oui' : 'Non',
            actifClass: r.Actif__c
                ? 'rib-badge rib-badge--actif'
                : 'rib-badge rib-badge--inactif'
        }));
        this.currentPage = 1;
        this.isLoading   = false;
    }

    /* ── Getters ───────────────────────────────────────── */

    get hasRecords()     { return this.records.length > 0; }
    get totalLabel()     { return `${this.records.length} RIB${this.records.length > 1 ? 's' : ''}`; }
    get totalPages()     { return Math.max(1, Math.ceil(this.records.length / PAGE_SIZE)); }
    get showPagination() { return this.totalPages > 1; }
    get isFirstPage()    { return this.currentPage === 1; }
    get isLastPage()     { return this.currentPage === this.totalPages; }
    get prevClass()      { return `rib-btn rib-btn--page${this.isFirstPage ? ' rib-btn--disabled' : ''}`; }
    get nextClass()      { return `rib-btn rib-btn--page${this.isLastPage  ? ' rib-btn--disabled' : ''}`; }

    get paginatedRecords() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        return this.records.slice(start, start + PAGE_SIZE);
    }

    /* ── Actions ───────────────────────────────────────── */

    handleRefresh() {
    this.isLoading = true;
    this._ribsReady = false;

    refreshApex(this._wiredResult)
        .then(() => {
            // Si le wire ne s'est pas re-déclenché (données identiques),
            // on force la résolution avec les données déjà présentes
            if (!this._ribsReady && this._rawRibData.length >= 0) {
                this._ribsReady = true;
                if (this._banquesReady) {
                    this._resolveRecords();
                }
            }
        })
        .catch(() => {
            this.isLoading = false;
        })
        .finally(() => {
            // Filet de sécurité : stopper le spinner dans tous les cas
            if (this.isLoading) {
                this.isLoading = false;
            }
        });
}

handleNavigateToRib(event) {
        event.preventDefault();
        const ribId = event.currentTarget.dataset.id;
        if (!ribId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId:      ribId,
                objectApiName: 'RIB__c',
                actionName:    'view'
            }
        });
    }

    prevPage() { if (!this.isFirstPage) { this.currentPage--; } }
    nextPage() { if (!this.isLastPage)  { this.currentPage++; } }
}