import { LightningElement, api, track } from 'lwc';
import getClaimFlagData from '@salesforce/apex/DA_FlagSinistreController.getClaimFlagData';

const FLAG_STYLES = {
    Sensible: 'fsd-flag--sensible',
    Majeur: 'fsd-flag--majeur',
    Grave: 'fsd-flag--grave',
    Frauduleux: 'fsd-flag--frauduleux',
    Douteux: 'fsd-flag--douteux'
};

export default class DA_lwc022_FlagSinistreDisplay extends LightningElement {
    @api recordId;

    @track currentFlags = [];
    @track pendingRequests = [];

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        try {
            const data = await getClaimFlagData({ claimId: this.recordId });
            this.currentFlags = data.currentFlags || [];
            this.pendingRequests = data.pendingRequests || [];
        } catch (error) {
            console.error('FlagSinistreDisplay error', error);
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
            class: 'fsd-flag ' + (FLAG_STYLES[flag] || '')
        }));

        for (const pFlag of pendingFlags) {
            if (!this.currentFlags.includes(pFlag)) {
                badges.push({
                    value: pFlag + '-pending',
                    label: pFlag + ' - En attente',
                    class: 'fsd-flag fsd-flag--pending'
                });
            }
        }

        return badges;
    }
}