import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import getInstructions from '@salesforce/apex/DA_lwc021_InstructionFormController.getInstructions';
import getVehiculesBySinistre from '@salesforce/apex/DA_lwc021_InstructionFormController.getVehiculesBySinistre';
import getVictimesBySinistre from '@salesforce/apex/DA_lwc021_InstructionFormController.getVictimesBySinistre';
import getCoveragesBySinistre from '@salesforce/apex/DA_lwc021_InstructionFormController.getCoveragesBySinistre';
import saveInstruction from '@salesforce/apex/DA_lwc021_InstructionFormController.saveInstruction';
import deleteInstruction from '@salesforce/apex/DA_lwc021_InstructionFormController.deleteInstruction';

const RECORD_TYPE_MAP = {
    'PEC - Prise en charge': 'PEC_Prise_en_charge',
    'Remboursement': 'Remboursement'
};

// ── helpers CSS ──────────────────────────────────────────────────────────────
function getStatutClass(statut) {
    if (!statut) return 'pm-state pm-state--default';
    const s = statut.toLowerCase();
    if (s.includes('valid') || s.includes('approuv') || s.includes('ok'))
        return 'pm-state pm-state--indemne';
    if (s.includes('attente') || s.includes('cours') || s.includes('progress'))
        return 'pm-state pm-state--blesse';
    if (s.includes('refus') || s.includes('annul') || s.includes('rejet'))
        return 'pm-state pm-state--deces';
    return 'pm-state pm-state--default';
}

function getRoleClass(role) {
    if (!role) return 'pm-role pm-role--assure';
    return role.toLowerCase().includes('advers')
        ? 'pm-role pm-role--adverse'
        : 'pm-role pm-role--assure';
}

function getStateClass(state) {
    if (!state) return 'pm-state pm-state--default';
    const s = state.toLowerCase();
    if (s.includes('bless')) return 'pm-state pm-state--blesse';
    if (s.includes('dec') || s.includes('mort')) return 'pm-state pm-state--deces';
    if (s.includes('indemne') || s.includes('sain')) return 'pm-state pm-state--indemne';
    return 'pm-state pm-state--default';
}

function formatDate(isoDate) {
    if (!isoDate) return '-';
    try {
        return new Date(isoDate).toLocaleDateString('fr-FR', {
            day: '2-digit', month: '2-digit', year: 'numeric'
        });
    } catch (e) { return isoDate; }
}

export default class DA_lwc021_InstructionForm extends NavigationMixin(LightningElement) {

    @api recordId;

    @track formData = {
        InstructionType__c: '',
        TypeDegat__c: '',
        Statut__c: 'Instruction créé',
        Vehicule__c: '',
        Victimes__c: '',
        ClaimCoverage__c: ''
    };

    @track instructions       = [];
    @track vehicules          = [];
    @track victimes           = [];
    @track coverages          = [];
    @track isLoading          = false;
    @track isLoadingVehicules = false;
    @track isLoadingVictimes  = false;
    @track isLoadingCoverages = false;
    @track showFormModal      = false;
    @track showDeleteModal    = false;
    @track isEditMode         = false;
    @track isSaving           = false;

    editingId  = null;
    deletingId = null;
    wiredInstructionsResult;

    typeInstructionOptions = [
        { label: 'PEC (Prise en charge)', value: 'PEC - Prise en charge' },
        { label: 'Remboursement',         value: 'Remboursement' }
    ];

    typeDogatOptions = [
        { label: 'Materiel', value: 'Materiel' },
        { label: 'Corporel', value: 'Corporel' }
    ];

    // ── Getters ──────────────────────────────────────────────────────────────
    get formTitle() {
        return this.isEditMode ? "Modification d'une instruction" : "Creation d'une instruction";
    }

    get saveLabel() {
        return this.isEditMode ? 'Enregistrer' : "Creer l'instruction";
    }

    get today() {
        return new Date().toISOString().substring(0, 10);
    }

    get showVehicule() { return this.formData.TypeDegat__c === 'Materiel'; }
    get showVictime()  { return this.formData.TypeDegat__c === 'Corporel'; }

    get hasInstructions() { return this.instructions && this.instructions.length > 0; }
    get hasVehicules()    { return this.vehicules && this.vehicules.length > 0; }
    get hasVictimes()     { return this.victimes  && this.victimes.length  > 0; }
    get hasCoverages()    { return this.coverages && this.coverages.length > 0; }

    get coverageRows() {
        return this.coverages.map(c => ({
            ...c,
            isSelected : this.formData.ClaimCoverage__c === c.Id,
            rowClass   : this.formData.ClaimCoverage__c === c.Id ? 'pm-table__row--selected' : ''
        }));
    }

    get vehiculeRows() {
        return this.vehicules.map(v => ({
            ...v,
            ProprietaireName : (v.ProprietaireDuVehicule__r && v.ProprietaireDuVehicule__r.Name) || '-',
            isSelected       : this.formData.Vehicule__c === v.Id,
            rowClass         : this.formData.Vehicule__c === v.Id ? 'pm-table__row--selected' : ''
        }));
    }

    get victimeRows() {
        return this.victimes.map(p => ({
            ...p,
            ParticipantName : (p.ParticipantAccount__r && p.ParticipantAccount__r.Name) || p.Name || '-',
            isSelected      : this.formData.Victimes__c === p.Id,
            rowClass        : this.formData.Victimes__c === p.Id ? 'pm-table__row--selected' : '',
            roleClass       : getRoleClass(p.Roles__c),
            stateClass      : getStateClass(p.StateOfPerson__c)
        }));
    }

    // ── Wire ─────────────────────────────────────────────────────────────────
    @wire(getInstructions, { sinisterId: '$recordId' })
    wiredInstructions(result) {
        this.wiredInstructionsResult = result;
        if (result.data) {
            this.instructions = result.data.map(instr => {
                const vehiculeName = (instr.Vehicule__r && instr.Vehicule__r.Name) || '';
                const victimeName  = (instr.Victimes__r
                                        && instr.Victimes__r.ParticipantAccount__r
                                        && instr.Victimes__r.ParticipantAccount__r.Name)
                                     || (instr.Victimes__r && instr.Victimes__r.Name)
                                     || '';
                return {
                    ...instr,
                    nameUrl       : '/lightning/r/Instruction__c/' + instr.Id + '/view',
                    VehiculeName  : vehiculeName || '-',
                    VictimeName   : victimeName  || '-',
                    hasVehicule   : !!instr.Vehicule__c,
                    hasVictime    : !!instr.Victimes__c,
                    vehiculeUrl   : instr.Vehicule__c ? '/lightning/r/Vehicule__c/' + instr.Vehicule__c + '/view' : '',
                    victimeUrl    : instr.Victimes__c ? '/lightning/r/ClaimParticipant__c/' + instr.Victimes__c + '/view' : '',
                    isMateriel    : instr.TypeDegat__c === 'Materiel',
                    statutClass   : getStatutClass(instr.Statut__c),
                    formattedDate : formatDate(instr.CreatedDate)
                };
            });
        } else if (result.error) {
            this.fireToast('Erreur', 'Impossible de charger les instructions.', 'error');
        }
    }

    // ── Chargement ───────────────────────────────────────────────────────────
    loadVehicules() {
        this.isLoadingVehicules = true;
        getVehiculesBySinistre({ sinisterId: this.recordId })
            .then(data  => { this.vehicules = data; })
            .catch(()   => { this.fireToast('Erreur', 'Impossible de charger les vehicules.', 'error'); })
            .finally(() => { this.isLoadingVehicules = false; });
    }

    loadVictimes() {
        this.isLoadingVictimes = true;
        getVictimesBySinistre({ sinisterId: this.recordId })
            .then(data  => { this.victimes = data; })
            .catch(()   => { this.fireToast('Erreur', 'Impossible de charger les victimes.', 'error'); })
            .finally(() => { this.isLoadingVictimes = false; });
    }

    loadCoverages() {
        this.isLoadingCoverages = true;
        getCoveragesBySinistre({ sinisterId: this.recordId })
            .then(data  => { this.coverages = data || []; })
            .catch(()   => { this.fireToast('Erreur', 'Impossible de charger les garanties.', 'error'); })
            .finally(() => { this.isLoadingCoverages = false; });
    }

    // ── Handlers formulaire ──────────────────────────────────────────────────
    handleNew() {
        this.resetForm();
        this.loadCoverages();
        this.showFormModal = true;
    }

    handleCancel() {
        this.showFormModal = false;
        this.resetForm();
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.formData = { ...this.formData, [field]: event.detail.value };
    }

    handleDegatChange(event) {
        const value = event.detail.value;
        this.formData = { ...this.formData, TypeDegat__c: value, Vehicule__c: '', Victimes__c: '' };
        this.vehicules = [];
        this.victimes  = [];
        if (value === 'Materiel') this.loadVehicules();
        else if (value === 'Corporel') this.loadVictimes();
    }

    handleVehiculeSelect(event) {
        const id = event.currentTarget.dataset.id;
        this.formData = { ...this.formData, Vehicule__c: id };
    }

    handleVictimeSelect(event) {
        const id = event.currentTarget.dataset.id;
        this.formData = { ...this.formData, Victimes__c: id };
    }

    handleCoverageSelect(event) {
        const id = event.currentTarget.dataset.id;
        this.formData = { ...this.formData, ClaimCoverage__c: id };
    }

    // ── Nom cliquable dans le tableau ────────────────────────────────────────
    handleNameClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type      : 'standard__recordPage',
            attributes: { recordId: id, objectApiName: 'Instruction__c', actionName: 'view' }
        });
    }

    handleVehiculeNameClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({
            type      : 'standard__recordPage',
            attributes: { recordId: id, objectApiName: 'Vehicule__c', actionName: 'view' }
        });
    }

    handleVictimeNameClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({
            type      : 'standard__recordPage',
            attributes: { recordId: id, objectApiName: 'ClaimParticipant__c', actionName: 'view' }
        });
    }

    // ── Boutons tableau ──────────────────────────────────────────────────────
    handleEditClick(event) {
        event.stopPropagation();
        const id  = event.currentTarget.dataset.id;
        const row = this.instructions.find(i => i.Id === id);
        if (!row) return;
        this.isEditMode = true;
        this.editingId  = row.Id;
        this.formData   = {
            InstructionType__c : row.InstructionType__c || '',
            TypeDegat__c       : row.TypeDegat__c       || '',
            Statut__c          : row.Statut__c          || '',
            Vehicule__c        : row.Vehicule__c        || '',
            Victimes__c        : row.Victimes__c        || '',
            ClaimCoverage__c   : ''
        };
        this.vehicules = [];
        this.victimes  = [];
        if (row.TypeDegat__c === 'Materiel') this.loadVehicules();
        if (row.TypeDegat__c === 'Corporel') this.loadVictimes();
        this.loadCoverages();
        this.showFormModal = true;
    }

    handleDeleteClick(event) {
        event.stopPropagation();
        this.deletingId    = event.currentTarget.dataset.id;
        this.showDeleteModal = true;
    }

    // ── Sauvegarde ────────────────────────────────────────────────────────────
    handleSave() {
        if (this.isSaving) return;
        if (!this.validateForm()) return;
        this.isSaving  = true;
        this.isLoading = true;

        const payload = {
            id              : this.editingId,
            sinisterId      : this.recordId,
            recordTypeName  : RECORD_TYPE_MAP[this.formData.InstructionType__c],
            instructionType : this.formData.InstructionType__c,
            typeDegat       : this.formData.TypeDegat__c,
            statut          : this.formData.Statut__c,
            vehiculeId      : this.formData.TypeDegat__c === 'Materiel' ? this.formData.Vehicule__c : null,
            victimeId       : this.formData.TypeDegat__c === 'Corporel' ? this.formData.Victimes__c : null,
            coverageId      : this.formData.ClaimCoverage__c || null
        };

        const wasEdit = this.isEditMode;

        saveInstruction({ payload: JSON.stringify(payload) })
            .then(savedRecord => {
                /*
                 * savedRecord doit etre retourne par Apex :
                 *   return [SELECT Id, Name FROM Instruction__c WHERE Id = :upsertedId LIMIT 1];
                 *
                 * Toast cible :
                 *   Titre   : "Instruction ajoutee avec succes"
                 *   Message : "I-00016"  <-- cliquable vers la fiche
                 */
                const savedId   = savedRecord && savedRecord.Id   ? savedRecord.Id   : '';
                const savedName = savedRecord && savedRecord.Name ? savedRecord.Name : '';

                this.showFormModal = false;
                this.resetForm();

                return refreshApex(this.wiredInstructionsResult).then(() => {
                    // Fallback : cherche dans la liste rafraichie si Apex n'a pas retourne le record
                    const resolvedId   = savedId   || (this.instructions[0] && this.instructions[0].Id)   || '';
                    const resolvedName = savedName
                        || (resolvedId && this.instructions.find(i => i.Id === resolvedId) && this.instructions.find(i => i.Id === resolvedId).Name)
                        || '';

                    if (resolvedId && resolvedName) {
                        // Toast avec nom cliquable
                        // Rendu : "Instruction ajoutee avec succes \n I-00016 (lien)"
                        this.dispatchEvent(new ShowToastEvent({
                            title       : wasEdit
                                            ? 'Instruction mise a jour avec succes'
                                            : 'Instruction ajoutee avec succes',
                            message     : '{0}',
                            messageData : [{
                                url  : '/lightning/r/Instruction__c/' + resolvedId + '/view',
                                label: resolvedName
                            }],
                            variant     : 'success',
                            mode        : 'dismissible'
                        }));
                    } else {
                        // Fallback texte simple
                        this.fireToast(
                            'Succes',
                            wasEdit ? 'Instruction mise a jour.' : 'Instruction creee avec succes.',
                            'success'
                        );
                    }
                });
            })
            .catch(error => {
                const msg = (error && error.body && error.body.message) ? error.body.message : 'Une erreur est survenue.';
                this.fireToast('Erreur', msg, 'error');
            })
            .finally(() => {
                this.isLoading = false;
                this.isSaving  = false;
            });
    }

    // ── Suppression ───────────────────────────────────────────────────────────
    handleCancelDelete() {
        this.showDeleteModal = false;
        this.deletingId = null;
    }

    handleConfirmDelete() {
        this.isLoading       = true;
        this.showDeleteModal = false;
        deleteInstruction({ instructionId: this.deletingId })
            .then(() => {
                this.deletingId = null;
                this.fireToast('Succes', 'Instruction supprimee.', 'success');
                return refreshApex(this.wiredInstructionsResult);
            })
            .catch(error => {
                const msg = (error && error.body && error.body.message) ? error.body.message : 'Erreur lors de la suppression.';
                this.fireToast('Erreur', msg, 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    // ── Utilitaires ───────────────────────────────────────────────────────────
    resetForm() {
        this.isEditMode = false;
        this.editingId  = null;
        this.formData   = {
            InstructionType__c : '',
            TypeDegat__c       : '',
            Statut__c          : 'Instruction créé',
            Vehicule__c        : '',
            Victimes__c        : '',
            ClaimCoverage__c   : ''
        };
        this.vehicules = [];
        this.victimes  = [];
        this.coverages = [];
    }

    validateForm() {
        let valid = true;
        if (!this.formData.InstructionType__c)                                        valid = false;
        if (!this.formData.TypeDegat__c)                                              valid = false;
        if (this.formData.TypeDegat__c === 'Materiel' && !this.formData.Vehicule__c) valid = false;
        if (this.formData.TypeDegat__c === 'Corporel' && !this.formData.Victimes__c) valid = false;
        if (!this.formData.ClaimCoverage__c)                                          valid = false;
        if (!valid) {
            this.fireToast('Validation', 'Veuillez remplir tous les champs obligatoires (*).', 'warning');
        }
        return valid;
    }

    fireToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}