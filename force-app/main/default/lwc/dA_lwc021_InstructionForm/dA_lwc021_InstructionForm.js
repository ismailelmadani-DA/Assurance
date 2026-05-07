import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import createInstruction from '@salesforce/apex/DA_lwc021_InstructionFormController.createInstruction';
import getVehiclesByClaim from '@salesforce/apex/DA_lwc021_InstructionFormController.getVehiclesByClaim';
import getParticipantsByClaim from '@salesforce/apex/DA_lwc021_InstructionFormController.getParticipantsByClaim';

// Claim fields to fetch
import CLAIM_NAME from '@salesforce/schema/Claim__c.Name';
import TYPE_DEGAT from '@salesforce/schema/Instruction__c.TypeDegat__c';

const CLAIM_FIELDS = [CLAIM_NAME, TYPE_DEGAT];

export default class DA_lwc021_InstructionForm extends NavigationMixin(LightningElement) {

    // ─── Public properties ────────────────────────────────────────────────────
    @api recordId; // The Claim__c Id (passed from record page)

    // ─── Tracked state ────────────────────────────────────────────────────────
    @track currentStep = 1;
    @track selectedInstructionType = null; // 'PEC' | 'Remboursement'
    @track selectedVehicleId = null;
    @track selectedVehicleName = null;
    @track selectedParticipantId = null;
    @track selectedParticipantName = null;

    @track vehicles = [];
    @track participants = [];
    @track isLoadingVehicles = false;
    @track isLoadingParticipants = false;

    @track isSaving = false;
    @track isSaved = false;
    @track saveError = null;
    @track createdInstructionId = null;
    @track createdInstructionName = null;

    // ─── Wire: Claim record ───────────────────────────────────────────────────
    @wire(getRecord, { recordId: '$recordId', fields: CLAIM_FIELDS })
    claimRecord;

    // ─── Computed: Claim info ─────────────────────────────────────────────────
    get claimName() {
        return getFieldValue(this.claimRecord.data, CLAIM_NAME) || '—';
    }

    get typeDegat() {
        return getFieldValue(this.claimRecord.data, TYPE_DEGAT) || '—';
    }

    get isMateriel() {
        return this.typeDegat === 'Matériel';
    }

    get isCorporel() {
        return this.typeDegat === 'Corporel';
    }

    get hasDegat() {
        return this.isMateriel || this.isCorporel;
    }

    // ─── Computed: Step visibility ────────────────────────────────────────────
    get isStep1() { return this.currentStep === 1 && !this.isSaved; }
    get isStep2() { return this.currentStep === 2 && !this.isSaved; }
    get isStep3() { return this.currentStep === 3 && !this.isSaved; }

    // ─── Computed: Step CSS classes ───────────────────────────────────────────
    get step1Class() {
        return `step-item ${this.currentStep === 1 ? 'step-active' : this.currentStep > 1 ? 'step-done' : ''}`;
    }
    get step2Class() {
        return `step-item ${this.currentStep === 2 ? 'step-active' : this.currentStep > 2 ? 'step-done' : ''}`;
    }
    get step3Class() {
        return `step-item ${this.currentStep === 3 ? 'step-active' : ''}`;
    }

    // ─── Computed: Type card classes ──────────────────────────────────────────
    get isPEC() { return this.selectedInstructionType === 'PEC'; }
    get isRemboursement() { return this.selectedInstructionType === 'Remboursement'; }

    get pecCardClass() {
        return `type-card ${this.isPEC ? 'type-card--selected' : ''}`;
    }
    get remboursementCardClass() {
        return `type-card ${this.isRemboursement ? 'type-card--selected' : ''}`;
    }

    // ─── Computed: Badge classes ──────────────────────────────────────────────
    get typeDegaTBadgeClass() {
        return `badge ${this.isMateriel ? 'badge--materiel' : this.isCorporel ? 'badge--corporel' : 'badge--default'}`;
    }

    get recapTypeBadgeClass() {
        return `badge ${this.isPEC ? 'badge--pec' : 'badge--remboursement'}`;
    }

    // ─── Computed: Next button disabled ──────────────────────────────────────
    get isStep1NextDisabled() {
        return !this.selectedInstructionType;
    }

    get isStep2NextDisabled() {
        if (this.isMateriel) return !this.selectedVehicleId;
        if (this.isCorporel) return !this.selectedParticipantId;
        return false;
    }

    get hasVehicles() { return this.vehicles && this.vehicles.length > 0; }
    get hasParticipants() { return this.participants && this.participants.length > 0; }

    // ─── Step 1: Type selection ───────────────────────────────────────────────
    selectPEC() { this.selectedInstructionType = 'PEC'; }
    selectRemboursement() { this.selectedInstructionType = 'Remboursement'; }

    goToStep1() {
        this.currentStep = 1;
    }

    async goToStep2() {
        if (!this.selectedInstructionType) return;
        this.currentStep = 2;

        if (this.isMateriel && this.vehicles.length === 0) {
            await this._loadVehicles();
        } else if (this.isCorporel && this.participants.length === 0) {
            await this._loadParticipants();
        }
    }

    goToStep3() {
        if (this.isStep2NextDisabled) return;
        this.currentStep = 3;
    }

    // ─── Load vehicles ────────────────────────────────────────────────────────
    async _loadVehicles() {
        this.isLoadingVehicles = true;
        try {
            const raw = await getVehiclesByClaim({ claimId: this.recordId });
            this.vehicles = raw.map(v => ({
                Id: v.Id,
                Name: v.Name || '—',
                immat: v.RegistrationNumber__c || 'Immat. inconnue',
                marque: v.Marque__c || '',
                selected: false,
                cardClass: 'entity-card'
            }));
        } catch (e) {
            this._showToast('Erreur', 'Impossible de charger les véhicules : ' + this._extractError(e), 'error');
        } finally {
            this.isLoadingVehicles = false;
        }
    }

    // ─── Load participants ────────────────────────────────────────────────────
    async _loadParticipants() {
        this.isLoadingParticipants = true;
        try {
            const raw = await getParticipantsByClaim({ claimId: this.recordId });
            this.participants = raw.map(p => ({
                Id: p.Id,
                Name: p.Name || '—',
                role: p.Roles__c || 'Rôle inconnu',
                etat: p.StateOfPerson__c || '',
                selected: false,
                cardClass: 'entity-card'
            }));
        } catch (e) {
            this._showToast('Erreur', 'Impossible de charger les participants : ' + this._extractError(e), 'error');
        } finally {
            this.isLoadingParticipants = false;
        }
    }

    // ─── Select vehicle ───────────────────────────────────────────────────────
    selectVehicle(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedVehicleId = id;
        this.vehicles = this.vehicles.map(v => ({
            ...v,
            selected: v.Id === id,
            cardClass: v.Id === id ? 'entity-card entity-card--selected' : 'entity-card'
        }));
        this.selectedVehicleName = this.vehicles.find(v => v.Id === id)?.Name;
    }

    // ─── Select participant ───────────────────────────────────────────────────
    selectParticipant(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedParticipantId = id;
        this.participants = this.participants.map(p => ({
            ...p,
            selected: p.Id === id,
            cardClass: p.Id === id ? 'entity-card entity-card--selected' : 'entity-card'
        }));
        this.selectedParticipantName = this.participants.find(p => p.Id === id)?.Name;
    }

    // ─── Save instruction ─────────────────────────────────────────────────────
    async handleSave() {
        this.isSaving = true;
        this.saveError = null;

        try {
            const payload = {
                claimId: this.recordId,
                instructionType: this.selectedInstructionType,
                typeDegat: this.typeDegat,
                vehicleId: this.isMateriel ? this.selectedVehicleId : null,
                participantId: this.isCorporel ? this.selectedParticipantId : null
            };

            const result = await createInstruction({ params: JSON.stringify(payload) });

            this.createdInstructionId = result.Id;
            this.createdInstructionName = result.Name;
            this.isSaved = true;

            this._showToast(
                'Succès',
                `L'instruction ${result.Name} a été créée avec le statut "Instruction créée".`,
                'success'
            );
        } catch (e) {
            this.saveError = this._extractError(e);
            this._showToast('Erreur de création', this.saveError, 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // ─── Navigate to created instruction ─────────────────────────────────────
    navigateToInstruction() {
        if (!this.createdInstructionId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.createdInstructionId,
                actionName: 'view'
            }
        });
    }

    // ─── Reset form ───────────────────────────────────────────────────────────
    resetForm() {
        this.currentStep = 1;
        this.selectedInstructionType = null;
        this.selectedVehicleId = null;
        this.selectedVehicleName = null;
        this.selectedParticipantId = null;
        this.selectedParticipantName = null;
        this.vehicles = [];
        this.participants = [];
        this.isSaving = false;
        this.isSaved = false;
        this.saveError = null;
        this.createdInstructionId = null;
        this.createdInstructionName = null;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────
    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _extractError(e) {
        if (e && e.body && e.body.message) return e.body.message;
        if (e && e.message) return e.message;
        return JSON.stringify(e);
    }
}