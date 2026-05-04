import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getClaimFlagData from '@salesforce/apex/DA_FlagSinistreController.getClaimFlagData';
import saveFlags from '@salesforce/apex/DA_FlagSinistreController.saveFlags';

const FLAG_LIST = ['Sensible', 'Majeur', 'Grave', 'Frauduleux', 'Douteux'];


export default class DA_lwc019_FlagSinistre extends LightningElement {
    @api recordId;

    @track isModalOpen = false;
    @track currentFlags = [];
    @track selectedFlags = [];
    @track commentaire = '';
    @track isSaving = false;
    @track isPrivileged = false;
    @track pendingRequests = [];
    @track claimName = '';

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        try {
            const data = await getClaimFlagData({ claimId: this.recordId });
            this.currentFlags = data.currentFlags || [];
            this.pendingRequests = data.pendingRequests || [];
            this.isPrivileged = data.isPrivileged;
            this.claimName = data.claimName;
        } catch (error) {
            this.showToast('Erreur', this.extractError(error), 'error');
        }
    }

    get hasPendingRequests() {
        return this.pendingRequests && this.pendingRequests.length > 0;
    }

    get flagOptions() {
        const RESTRICTED = ['Frauduleux', 'Douteux'];
        const pendingFlags = this.pendingRequests.map(r => r.flag);
        const hasFrauduleux = this.selectedFlags.includes('Frauduleux');
        const hasDouteux = this.selectedFlags.includes('Douteux');

        return FLAG_LIST.map(flag => {
            let disabled = false;
            let pendingLabel = '';
            const isRestricted = RESTRICTED.includes(flag);

            let disabledReason = '';
            if (isRestricted && !this.isPrivileged) {
                const otherFlag = flag === 'Frauduleux' ? 'Douteux' : 'Frauduleux';
                if (pendingFlags.includes(flag)) {
                    disabled = true;
                    disabledReason = 'Une demande est déjà en attente de validation pour le flag "' + flag + '".';
                } else if (pendingFlags.includes(otherFlag)) {
                    disabled = true;
                    disabledReason = 'Vous ne pouvez pas sélectionner ce flag tant que le flag "' + otherFlag + '" est en attente de validation.';
                } else if (flag === 'Frauduleux' && hasDouteux) {
                    disabled = true;
                    disabledReason = 'Les flags "Frauduleux" et "Douteux" ne peuvent pas être sélectionnés en même temps.';
                } else if (flag === 'Douteux' && hasFrauduleux) {
                    disabled = true;
                    disabledReason = 'Les flags "Frauduleux" et "Douteux" ne peuvent pas être sélectionnés en même temps.';
                }
            }

            if (pendingFlags.includes(flag)) {
                pendingLabel = 'En attente';
            }

            return {
                value: flag,
                label: flag,
                checked: this.selectedFlags.includes(flag),
                disabled,
                disabledReason,
                pendingLabel
            };
        });
    }

    handleOpenModal() {
        this.selectedFlags = [...this.currentFlags];
        this.commentaire = '';
        this.isModalOpen = true;
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    handleDisabledClick(event) {
        const flag = event.currentTarget.dataset.flag;
        const opt = this.flagOptions.find(o => o.value === flag);
        if (opt && opt.disabled && opt.disabledReason) {
            this.showToast('Action non disponible', opt.disabledReason, 'warning');
        }
    }

    handleFlagChange(event) {
        const flag = event.target.dataset.flag;
        const isChecked = event.target.checked;
        const RESTRICTED = ['Frauduleux', 'Douteux'];
        const isRestricted = RESTRICTED.includes(flag);
        const pendingFlags = this.pendingRequests.map(r => r.flag);

        if (isRestricted && !this.isPrivileged && isChecked) {
            const otherFlag = flag === 'Frauduleux' ? 'Douteux' : 'Frauduleux';
            if (pendingFlags.includes(flag) || pendingFlags.includes(otherFlag) || this.selectedFlags.includes(otherFlag)) {
                event.target.checked = false;
                return;
            }
        }

        let flags = [...this.selectedFlags];
        if (isChecked) {
            if (!flags.includes(flag)) {
                flags.push(flag);
            }
        } else {
            flags = flags.filter(f => f !== flag);
        }

        this.selectedFlags = flags;
    }

    handleCommentChange(event) {
        this.commentaire = event.target.value;
    }

    async handleConfirm() {
        if (!this.commentaire || this.commentaire.trim() === '') {
            this.showToast('Erreur', 'Le commentaire est obligatoire.', 'error');
            return;
        }

        if (this.selectedFlags.includes('Frauduleux') && this.selectedFlags.includes('Douteux')) {
            this.showToast('Erreur', 'Les flags "Frauduleux" et "Douteux" ne peuvent pas être sélectionnés en même temps.', 'error');
            return;
        }

        this.isSaving = true;
        try {
            const result = await saveFlags({
                claimId: this.recordId,
                selectedFlags: this.selectedFlags,
                commentaire: this.commentaire.trim()
            });

            if (result.success) {
                this.showToast('Succès', result.message, 'success');
                this.isModalOpen = false;
                await this.loadData();
            } else {
                this.showToast('Erreur', result.message, 'error');
            }
        } catch (error) {
            this.showToast('Erreur', this.extractError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    extractError(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return 'Une erreur inattendue est survenue.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: 'sticky' }));
    }
}