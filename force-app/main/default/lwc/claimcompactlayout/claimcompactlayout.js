import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin }             from 'lightning/navigation';
import getClaimData                    from '@salesforce/apex/ClaimCompactLayoutController.getClaimData';
import getClaimFlagData                from '@salesforce/apex/DA_FlagSinistreController.getClaimFlagData';

const FLAG_STYLES = {
    Sensible: 'ccl-flag--sensible',
    Majeur: 'ccl-flag--majeur',
    Grave: 'ccl-flag--grave',
    Frauduleux: 'ccl-flag--frauduleux',
    Douteux: 'ccl-flag--douteux'
};

export default class ClaimCompactLayout extends NavigationMixin(LightningElement) {

    @api recordId;

    _data    = null;
    _error   = null;
    _loading = true;

    @track currentFlags = [];
    @track pendingRequests = [];

    @wire(getClaimData, { recordId: '$recordId' })
    wiredData({ data, error }) {
        this._loading = false;
        if (data) {
            this._data = {
                ...data,
                fields: (data.fields || []).map(f => {
                    const recordUrl = (f.isLookup && f.lookupId)
                        ? '/' + f.lookupId
                        : null;
                    if (f.isLookup) {
                        console.log(
                            `[LOOKUP] ${f.fieldPath}` +
                            ` | lookupId=${f.lookupId}` +
                            ` | display=${f.displayValue}` +
                            ` | url=${recordUrl}`
                        );
                    }
                    return { ...f, recordUrl };
                })
            };
            this._error = null;
        } else if (error) {
            this._error = error;
            this._data  = null;
            console.error('claimCompactLayout – erreur Apex :', JSON.stringify(error));
        }
    }

    connectedCallback() {
        this.loadFlagData();
    }

    async loadFlagData() {
        try {
            const data = await getClaimFlagData({ claimId: this.recordId });
            this.currentFlags = data.currentFlags || [];
            this.pendingRequests = data.pendingRequests || [];
        } catch (error) {
            console.error('claimCompactLayout – flag error:', error);
        }
    }

    get hasFlags() {
        return (this.currentFlags && this.currentFlags.length > 0) || this.hasPendingRequests;
    }

    get hasPendingRequests() {
        return this.pendingRequests && this.pendingRequests.length > 0;
    }

    get flagBadges() {
        const pendingFlags = this.pendingRequests.map(r => r.flag);
        const badges = this.currentFlags.map(flag => ({
            value: flag,
            label: flag,
            class: 'ccl-flag ' + (FLAG_STYLES[flag] || '')
        }));
        for (const pFlag of pendingFlags) {
            if (!this.currentFlags.includes(pFlag)) {
                badges.push({
                    value: pFlag + '-pending',
                    label: pFlag + ' - En attente',
                    class: 'ccl-flag ccl-flag--pending'
                });
            }
        }
        return badges;
    }

    navigateToRecord(event) {
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({
            type       : 'standard__recordPage',
            attributes : { recordId: id, actionName: 'view' }
        });
    }

    get hasError()     { return this._error   !== null; }
    get isLoading()    { return this._loading && !this._data && !this._error; }
    get isLoaded()     { return this._data    !== null; }
    get errorMessage() { return this._error?.body?.message || JSON.stringify(this._error || ''); }
    get claimName()    { return this._data?.claimName || '—'; }
    get fieldItems()   { return this._data?.fields    || []; }
}