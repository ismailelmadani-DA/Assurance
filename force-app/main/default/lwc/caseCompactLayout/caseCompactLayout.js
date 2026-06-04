import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin }             from 'lightning/navigation';
import { IsConsoleNavigation, openTab } from 'lightning/platformWorkspaceApi';
import { ShowToastEvent }              from 'lightning/platformShowToastEvent';
import USER_ID                         from '@salesforce/user/Id';
import getRecordData from '@salesforce/apex/DA_lwc025_CaseCompactLayoutController.getRecordData';
import closeCase     from '@salesforce/apex/DA_lwc025_CaseCompactLayoutController.closeCase';
import cancelCase    from '@salesforce/apex/DA_lwc025_CaseCompactLayoutController.cancelCase';
import takeOverCase  from '@salesforce/apex/DA_lwc025_CaseCompactLayoutController.takeOverCase';

const STATUS_CLASSES = {
    'Rejetée'  : 'ccl-status-badge ccl-status--rejetee',
    'Initiale' : 'ccl-status-badge ccl-status--initiale',
    'En cours' : 'ccl-status-badge ccl-status--en-cours',
    'Clôturée' : 'ccl-status-badge ccl-status--cloturee',
};

export default class CaseCompactLayout extends NavigationMixin(LightningElement) {

    @api recordId;
    @api objectApiName;
    @api cardTitle;
    @api defaultRecordType;
    @api fields;

    _data    = null;
    _error   = null;
    _loading = true;
    _wired   = null;
    _showValidateReassign = false;
    _showRejectReassign   = false;

    @wire(IsConsoleNavigation) isConsoleNavigation;

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        this._loading = true;
        try {
            const data = await getRecordData({
                recordId       : this.recordId,
                objectApiName  : this.objectApiName,
                fieldsCsv      : this.fields,
                recordTypeName : this.defaultRecordType
            });
            this._error = null;
            this._data  = {
                ...data,
                fields: (data.fields || []).map(f => ({
                    ...f,
                    recordUrl   : (f.isLookup && f.lookupId) ? '/' + f.lookupId : null,
                    isStatus    : f.fieldPath === 'Status',
                    statusClass : f.fieldPath === 'Status'
                        ? (STATUS_CLASSES[f.displayValue] || 'ccl-status-badge ccl-status--default')
                        : null
                }))
            };
        } catch (error) {
            this._error = error;
            this._data  = null;
        } finally {
            this._loading = false;
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
    get hasRequeteInitiale() { return !!this._data?.requeteInitialeId; }
    get requeteInitialeId()  { return this._data?.requeteInitialeId || null; }

    get isDeclarationButtonVisible() {
        if (!this._data) return false;
        const reaffecterAId = this._data.reaffecterAId;
        if (reaffecterAId) {
            return reaffecterAId === USER_ID;
        }
        if (this._data.requeteInitialeId) {
            return false;
        }
        return this._data.declarationOwnerId === USER_ID;
    }

    get actionItems() {
        const actions = this._data?.actions || [];
        return actions.filter(a => {
            if (a.name === 'continueDeclaration' && this._data?.recordTypeName === 'Declaration') {
                return true;
            }
            if (a.name === 'reassign' && this._data?.recordTypeName === 'Declaration') {
                return true;
            }
            if (a.name === 'validateReassign') return this._showValidateReassign;
            if (a.name === 'rejectReassign')   return this._showRejectReassign;
            return true;
        });
    }

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
            case 'validateReassign':    return this.runValidateReassign();
            case 'rejectReassign':      return this.runRejectReassign();
            case 'continueDeclaration': return this.runContinueDeclaration();
            default: this.toast('Action', 'Action non implémentée : ' + action, 'info');
        }
    }

    async runClose() {
        try {
            await closeCase({ recordId: this.recordId });
            this.toast('Succès', 'Case clôturé.', 'success');
            this.loadData();
        } catch (e) { this.toast('Erreur', this.extract(e), 'error'); }
    }

    async runCancel() {
        try {
            await cancelCase({ recordId: this.recordId });
            this.toast('Succès', 'Mission annulée.', 'success');
            this.loadData();
        } catch (e) { this.toast('Erreur', this.extract(e), 'error'); }
    }

    async runTakeOver() {
        try {
            await takeOverCase({ recordId: this.recordId });
            this.toast('Succès', 'Requête prise en charge.', 'success');
            this.loadData();
        } catch (e) { this.toast('Erreur', this.extract(e), 'error'); }
    }

    runReassign() {
        const modal = this.refs.reassignModal;
        if (modal) {
            modal.handleOpenModal();
        } else {
            const fallback = this.template.querySelector('c-d-a_lwc026_-reaffecter-declaration');
            if (fallback) fallback.handleOpenModal();
        }
    }

    runValidateReassign() {
        const modal = this.refs.validateReassignModal;
        if (modal) {
            modal.handleOpenModal();
        } else {
            const fallback = this.template.querySelector('c-d-a_lwc027_-valider-reaffectation');
            if (fallback) fallback.handleOpenModal();
        }
    }

    runRejectReassign() {
        const modal = this.refs.rejectReassignModal;
        if (modal) {
            modal.handleOpenModal();
        } else {
            const fallback = this.template.querySelector('c-d-a_lwc028_-rejeter-reaffectation');
            if (fallback) fallback.handleOpenModal();
        }
    }

    runCancelReassign() {
        const modal = this.refs.cancelReassignModal;
        if (modal) {
            modal.handleOpenModal();
        } else {
            const fallback = this.template.querySelector('c-d-a_lwc029_-annuler-reaffectation');
            if (fallback) fallback.handleOpenModal();
        }
    }

    handleOwnerResolved(event) {
        this._showValidateReassign = event.detail.isOwner;
    }

    handleRejectOwnerResolved(event) {
        this._showRejectReassign = event.detail.isOwner;
    }

    async runContinueDeclaration() {
        const url = `/lightning/n/Poursuivre_Declaration?c__recordId=${encodeURIComponent(this.recordId)}`;

        if (this.isConsoleNavigation) {
            await openTab({
                url,
                focus: true,
                label: 'Poursuivre la déclaration'
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url }
            });
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extract(e) {
        return e?.body?.message || e?.message || JSON.stringify(e || '');
    }
}