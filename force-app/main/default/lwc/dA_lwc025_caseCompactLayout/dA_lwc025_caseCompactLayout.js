import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin }             from 'lightning/navigation';
import { refreshApex }                 from '@salesforce/apex';
import { ShowToastEvent }              from 'lightning/platformShowToastEvent';
import getRecordData from '@salesforce/apex/DA_lwc025_CaseCompactLayoutController.getRecordData';
import closeCase     from '@salesforce/apex/DA_lwc025_CaseCompactLayoutController.closeCase';
import cancelCase    from '@salesforce/apex/DA_lwc025_CaseCompactLayoutController.cancelCase';
import takeOverCase  from '@salesforce/apex/DA_lwc025_CaseCompactLayoutController.takeOverCase';

export default class DA_lwc025_caseCompactLayout extends NavigationMixin(LightningElement) {

    /* ── Propriétés configurables (Lightning App Builder) ── */
    @api recordId;
    @api objectApiName;
    @api cardTitle;
    @api defaultRecordType;
    @api fields;

    /* ── OBSOLÈTES — conservées pour compatibilité org, ne sont plus utilisées ── */
    @api recordObjectApiName;
    @api fieldsDeclaration;
    @api fieldsMission;
    @api fieldsRequete;

    /* ── État interne ── */
    _data    = null;
    _error   = null;
    _loading = true;
    _wired   = null;

    @wire(getRecordData, {
        recordId       : '$recordId',
        objectApiName  : '$objectApiName',
        fieldsCsv      : '$fields',
        recordTypeName : '$defaultRecordType'
    })
    wiredData(result) {
        this._wired   = result;
        this._loading = false;
        const { data, error } = result;
        if (data) {
            this._error = null;
            this._data  = {
                ...data,
                fields: (data.fields || []).map(f => ({
                    ...f,
                    recordUrl: (f.isLookup && f.lookupId) ? '/' + f.lookupId : null
                }))
            };
        } else if (error) {
            this._error = error;
            this._data  = null;
        }
    }

    /* ── Getters ── */
    get hasError()     { return this._error !== null; }
    get isLoading()    { return this._loading && !this._data && !this._error; }
    get isLoaded()     { return this._data !== null; }
    get errorMessage() { return this._error?.body?.message || JSON.stringify(this._error || ''); }
    get displayTitle() { return (this.cardTitle && this.cardTitle.trim()) || this._data?.headerLabel || 'Case'; }
    get caseNumber()   { return this._data?.caseNumber || '—'; }
    get iconName()     { return this._data?.iconName   || 'standard:record'; }
    get fieldItems()   { return this._data?.fields     || []; }
    get actionItems()  { return this._data?.actions    || []; }

    /* ── Navigation lookup ── */
    navigateToRecord(event) {
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({
            type      : 'standard__recordPage',
            attributes: { recordId: id, actionName: 'view' }
        });
    }

    /* ── Actions ── */
    handleAction(event) {
        const action = event.currentTarget.dataset.name;
        switch (action) {
            case 'close':               return this.runClose();
            case 'cancel':              return this.runCancel();
            case 'takeOver':            return this.runTakeOver();
            case 'reassign':            return this.runReassign();
            case 'continueDeclaration': return this.runContinueDeclaration();
            default: this.toast('Action', 'Action non implémentée : ' + action, 'info');
        }
    }

    async runClose() {
        try {
            await closeCase({ recordId: this.recordId });
            this.toast('Succès', 'Case clôturé.', 'success');
            await refreshApex(this._wired);
        } catch (e) { this.toast('Erreur', this.extract(e), 'error'); }
    }

    async runCancel() {
        try {
            await cancelCase({ recordId: this.recordId });
            this.toast('Succès', 'Mission annulée.', 'success');
            await refreshApex(this._wired);
        } catch (e) { this.toast('Erreur', this.extract(e), 'error'); }
    }

    async runTakeOver() {
        try {
            await takeOverCase({ recordId: this.recordId });
            this.toast('Succès', 'Requête prise en charge.', 'success');
            await refreshApex(this._wired);
        } catch (e) { this.toast('Erreur', this.extract(e), 'error'); }
    }

    runReassign() {
        this[NavigationMixin.Navigate]({
            type      : 'standard__quickAction',
            attributes: { apiName: 'Case.ChangeOwnerOne' }
        });
    }

    runContinueDeclaration() {
        this[NavigationMixin.Navigate]({
            type      : 'standard__recordPage',
            attributes: { recordId: this.recordId, objectApiName: 'Case', actionName: 'edit' }
        });
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extract(e) {
        return e?.body?.message || e?.message || JSON.stringify(e || '');
    }
}