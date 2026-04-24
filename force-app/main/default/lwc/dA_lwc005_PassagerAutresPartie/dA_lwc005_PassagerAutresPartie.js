import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getPassagersAutresPartie from '@salesforce/apex/DA_PassagerController.getPassagersAutresPartie';

const STATE_CLASS_MAP = {
    Blessé: 'pm-state pm-state--blesse',
    Décédé: 'pm-state pm-state--deces',
    Indemne: 'pm-state pm-state--indemne'
};
const DEFAULT_STATE_CLASS = 'pm-state pm-state--default';

export default class DA_lwc005_PassagerAutresPartie extends NavigationMixin(LightningElement) {
    @api recordId;

    passagers;
    error;

    _wiredResult;

    // --- Wire ---
    @wire(getPassagersAutresPartie, { caseId: '$recordId' })
    wiredPassagers(result) {
        this._wiredResult = result;
        const { data, error: err } = result;
        if (data) {
            this.passagers = data.map((r) => ({
                ...r,
                stateClass: STATE_CLASS_MAP[r.StateOfPerson__c] || DEFAULT_STATE_CLASS,
                recordUrl: `/lightning/r/Passager__c/${r.Id}/view`,
                accountUrl: r.Compte__c ? `/lightning/r/Account/${r.Compte__c}/view` : null,
                accountName: r.Compte__r?.Name || r.Name__c || '',
                hasAccount: !!r.Compte__c
            }));
            this.error = undefined;
        } else if (err) {
            this.error = err.body?.message || 'Erreur lors du chargement des participants.';
            this.passagers = undefined;
        }
    }

    // --- Getters ---
    get hasPassagers() {
        return Array.isArray(this.passagers) && this.passagers.length > 0;
    }

    get totalLabel() {
        const count = this.passagers?.length || 0;
        return `${count} participant${count > 1 ? 's' : ''}`;
    }

    // --- Navigation vers Account ---
    navigateToAccount(event) {
        const accountId = event.currentTarget.dataset.id;
        if (accountId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: accountId,
                    objectApiName: 'Account',
                    actionName: 'view'
                }
            });
        }
    }

    // --- Refresh ---
    handleRefresh() {
        return refreshApex(this._wiredResult);
    }
}