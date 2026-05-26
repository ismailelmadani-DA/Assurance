import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin }             from 'lightning/navigation';
import { refreshApex }                 from '@salesforce/apex';  // ✅ AJOUT
import getClaimData                    from '@salesforce/apex/DA_lwc024_ClaimCompactLayoutController.getClaimData';
import getClaimFlagData                from '@salesforce/apex/DA_FlagSinistreController.getClaimFlagData';

const FLAG_STYLES = {
    Sensible: 'ccl-flag--sensible',
    Majeur: 'ccl-flag--majeur',
    Grave: 'ccl-flag--grave',
    Frauduleux: 'ccl-flag--frauduleux',
    Douteux: 'ccl-flag--douteux'
};

export default class DA_lwc024_ClaimCompactLayout extends NavigationMixin(LightningElement) {

    @api recordId;

    _data    = null;
    _error   = null;
    _loading = true;
    _wiredDataResult = null; // ✅ AJOUT : stocker le résultat wire

    @track currentFlags = [];
    @track pendingRequests = [];

    @wire(getClaimData, { recordId: '$recordId' })
    wiredData(result) { // ✅ MODIFIÉ : recevoir result complet
        this._wiredDataResult = result; // ✅ AJOUT : sauvegarder pour refreshApex
        const { data, error } = result;
        this._loading = false;
        if (data) {
            this._data = {
                ...data,
                fields: (data.fields || []).map(f => {
                    const recordUrl = (f.isLookup && f.lookupId)
                        ? '/' + f.lookupId
                        : null;
                    return { ...f, recordUrl };
                })
            };
            this._error = null;
        } else if (error) {
            this._error = error;
            this._data  = null;
        }
    }

    // ✅ AJOUT : écouter l'événement depuis le composant flag
    connectedCallback() {
        this.loadFlagData();
        window.addEventListener('evenementassocie', this._handleEvenementAssocie.bind(this));
    }

    // ✅ AJOUT : nettoyer le listener
    disconnectedCallback() {
        window.removeEventListener('evenementassocie', this._handleEvenementAssocie.bind(this));
    }

    // ✅ AJOUT : rafraîchir le wire quand un événement est associé
    _handleEvenementAssocie() {
        refreshApex(this._wiredDataResult);
    }

    async loadFlagData() {
        try {
            const data = await getClaimFlagData({ claimId: this.recordId });
            this.currentFlags = data.currentFlags || [];
            this.pendingRequests = data.pendingRequests || [];
        } catch (error) {
            console.error('dA_lwc024_claimCompactLayout – flag error:', error);
        }
    }

    // ... reste inchangé
    get hasFlags()     { return (this.currentFlags && this.currentFlags.length > 0) || this.hasPendingRequests; }
    get hasPendingRequests() { return this.pendingRequests && this.pendingRequests.length > 0; }
    get flagBadges() {
        const pendingFlags = this.pendingRequests.map(r => r.flag);
        const badges = this.currentFlags.map(flag => ({
            value: flag, label: flag,
            class: 'ccl-flag ' + (FLAG_STYLES[flag] || '')
        }));
        for (const pFlag of pendingFlags) {
            if (!this.currentFlags.includes(pFlag)) {
                badges.push({ value: pFlag + '-pending', label: pFlag + ' - En attente', class: 'ccl-flag ccl-flag--pending' });
            }
        }
        return badges;
    }
    navigateToRecord(event) {
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: id, actionName: 'view' } });
    }
    get hasError()     { return this._error   !== null; }
    get isLoading()    { return this._loading && !this._data && !this._error; }
    get isLoaded()     { return this._data    !== null; }
    get errorMessage() { return this._error?.body?.message || JSON.stringify(this._error || ''); }
    get claimName()    { return this._data?.claimName || '—'; }
    get fieldItems()   { return this._data?.fields    || []; }
}