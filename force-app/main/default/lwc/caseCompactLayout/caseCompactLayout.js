import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin }             from 'lightning/navigation';
import { IsConsoleNavigation, openTab } from 'lightning/platformWorkspaceApi';
import { refreshApex }                 from '@salesforce/apex';
import { ShowToastEvent }              from 'lightning/platformShowToastEvent';
import USER_ID                         from '@salesforce/user/Id';
import getRecordData from '@salesforce/apex/DA_lwc025_CaseCompactLayoutController.getRecordData';
import closeCase     from '@salesforce/apex/DA_lwc025_CaseCompactLayoutController.closeCase';
import cancelCase    from '@salesforce/apex/DA_lwc025_CaseCompactLayoutController.cancelCase';
import takeOverCase  from '@salesforce/apex/DA_lwc025_CaseCompactLayoutController.takeOverCase';

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
                recordUrl: (f.isLookup && f.lookupId) ? '/' + f.lookupId : null
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

    // ✅ NOUVEAU — deux cas de visibilité pour les boutons de la Déclaration
    get isDeclarationButtonVisible() {
    if (!this._data) return false;

    // Cas 1 — requête En cours → ReaffecterA voit uniquement poursuivre
    const reaffecterAId = this._data.reaffecterAId;
    if (reaffecterAId) {
        return reaffecterAId === USER_ID;
    }

    // Cas 2 — requête Initiale → personne ne voit les boutons
    // mais le badge est affiché via hasRequeteInitiale
    if (this._data.requeteInitialeId) {
        return false;
    }

    // Cas 3 — pas de requête ou requête Rejetée → gestionnaire actuel
    return this._data.declarationOwnerId === USER_ID;
}

    get actionItems() {
        const actions = this._data?.actions || [];
        return actions.filter(a => {
            // ✅ Boutons Declaration — visibilité gérée par isDeclarationButtonVisible
            if (a.name === 'continueDeclaration' && this._data?.recordTypeName === 'Declaration') {
    // visible pour gestionnaire actuel ET ReaffecterA — mais PAS si requête Initiale
    if (this._data.requeteInitialeId) return false;
    // masqué une fois le sinistre créé (LastWizardStep__c remis à null par finalizeClaimProcess)
    if (this._data.lastWizardStep == null) return false;
    return this.isDeclarationButtonVisible;
}
if (a.name === 'reassign' && this._data?.recordTypeName === 'Declaration') {
    // visible uniquement si pas de requête Initiale ET pas de requête En cours
    if (this._data.requeteInitialeId) return false;
    if (this._data.reaffecterAId)     return false;
    return this._data.declarationOwnerId === USER_ID;
}
            // Boutons Requete — filtrés par isOwner de lwc027/lwc028
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
        const pageRef = {
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Poursuivre_Declaration'
            },
            state: {
                c__recordId: this.recordId
            }
        };

        if (this.isConsoleNavigation) {
            await openTab({
                pageReference: pageRef,
                focus: true,
                label: 'Poursuivre la déclaration'
            });
        } else {
            this[NavigationMixin.Navigate](pageRef);
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extract(e) {
        return e?.body?.message || e?.message || JSON.stringify(e || '');
    }
}