import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';

// Import des objets et champs pour Picklists dynamiques (Étape 4)
import CASE_OBJECT from '@salesforce/schema/Case';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import COUNTRY_FIELD from '@salesforce/schema/Case.CountryOfOccurrence__c';
import CITY_FIELD from '@salesforce/schema/Case.CityOfOccurrence__c';
import CLAIMANT_FIELD from '@salesforce/schema/Case.Claimant__c';
import PV_FIELD from '@salesforce/schema/Case.IncidentReport__c';
import NOTIF_FIELD from '@salesforce/schema/Account.MoyenNotification__c';

// Apex
import searchPolicies from '@salesforce/apex/ClaimSearchController.searchPolicies';
import createClaimCase from '@salesforce/apex/ClaimSearchController.createClaimCase';
import getPicklistOptions from '@salesforce/apex/ClaimSearchController.getTypeDocumentsByReportoire';
import saveDocumentLocally from '@salesforce/apex/ClaimSearchController.saveDocumentLocally';

export default class ClaimCreationWizard extends LightningElement {
    // --- État Global ---
    @track currentStep = 1;
    @track isLoading = false;
    @track searchResults = [];
    
    // --- Étape 1 & 2 ---
    @track isPoliceConnu; 
    @track searchType;
    @track selectedPolicyId; 
    @track dateSurvenance; 
    @track selectedPolicyRecord; 

    // --- Étape 4 (Case) ---
    @track createdCaseId; 
    @track caseData = {
        country: '', city: '', address: '', dateDepot: '',
        declarant: '', pvConstat: '', commentaire: '',
        nomContact: '', telContact: '', mailContact: '', moyenNotification: ''
    };
    @track isSameAsInsured = false;

    // --- Étape 5 (Documents) ---
    @track files = []; // Fichiers uploadés mais pas encore indexés
    @track uploadedDocumentIds = []; // Documents enregistrés en base
    @track allPicklistData = {}; // Map Répertoire -> Types
    @track optionsDirectory = [];
    @track optionsDocType = [];
    @track selectedDirectory = '';
    @track selectedDocType = '';

    // --- Options Picklists ---
    @track optionsPays = []; @track optionsVille = [];
    @track optionsDeclarant = []; @track optionsPV = [];
    @track optionsNotif = [];
    optionsOuiNon = [{ label: 'Oui', value: 'Oui' }, { label: 'Non', value: 'Non' }];
    optionsCriteres = [
        { label: "Numéro d'immatriculation", value: 'immatriculation' },
        { label: "Numéro d'attestation", value: 'attestation' },
        { label: "Numéro chassis", value: 'chassis' }
    ];
    optionsContact = [{ label: 'Oui', value: 'true' }, { label: 'Non', value: 'false' }];

    // --- WIRES: Récupération des données Picklist ---
    @wire(getObjectInfo, { objectApiName: CASE_OBJECT }) caseObjectInfo;
    @wire(getPicklistValues, { recordTypeId: '$caseObjectInfo.data.defaultRecordTypeId', fieldApiName: COUNTRY_FIELD })
    wiredPays({ data }) { if (data) this.optionsPays = data.values; }
    @wire(getPicklistValues, { recordTypeId: '$caseObjectInfo.data.defaultRecordTypeId', fieldApiName: CITY_FIELD })
    wiredVille({ data }) { if (data) this.optionsVille = data.values; }
    @wire(getPicklistValues, { recordTypeId: '$caseObjectInfo.data.defaultRecordTypeId', fieldApiName: CLAIMANT_FIELD })
    wiredDeclarant({ data }) { if (data) this.optionsDeclarant = data.values; }
    @wire(getPicklistValues, { recordTypeId: '$caseObjectInfo.data.defaultRecordTypeId', fieldApiName: PV_FIELD })
    wiredPV({ data }) { if (data) this.optionsPV = data.values; }

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT }) accountObjectInfo;
    @wire(getPicklistValues, { recordTypeId: '$accountObjectInfo.data.defaultRecordTypeId', fieldApiName: NOTIF_FIELD })
    wiredNotif({ data }) { if (data) this.optionsNotif = data.values; }

    @wire(getPicklistOptions)
    wiredDocOptions({ data }) {
        if (data) {
            this.allPicklistData = data;
            this.optionsDirectory = Object.keys(data).map(key => ({ label: key, value: key }));
        }
    }

    // --- Getters de Visibilité & UI ---
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get isStep5() { return this.currentStep === 5; }
    get isStep6() { return this.currentStep === 6; }

    // Pour gérer les boutons "Suivant" proprement dans le HTML
    get isStepStandard() { return this.currentStep < 4; }

    get showFooter() { return this.currentStep < 6 && (this.isOuiSelected || (this.isNonSelected && this.searchType) || this.currentStep > 1); }
    get showPrecedent() { return this.currentStep > 1 && this.currentStep < 6; }
    get isOuiSelected() { return this.isPoliceConnu === 'Oui'; }
    get isNonSelected() { return this.isPoliceConnu === 'Non'; }
    get isSameAsInsuredString() { return this.isSameAsInsured.toString(); }
    get isUploadDisabled() { return !this.selectedDirectory || !this.selectedDocType; }
    
    get inputLabel() {
        const labels = { immatriculation: "Numéro d'immatriculation", attestation: "Numéro d'attestation", chassis: "Numéro chassis" };
        return labels[this.searchType] || "Valeur";
    }

    // --- Getters Stepper Classes ---
    get step1Class() { return this.currentStep === 1 ? 'step active' : 'step completed'; }
    get step1IconClass() { return this.currentStep > 1 ? 'circle-check' : 'circle-ring'; }
    get step2Class() { return this.currentStep === 2 ? 'step active' : (this.currentStep > 2 ? 'step completed' : 'step'); }
    get step2IconClass() { return this.currentStep === 2 ? 'circle-ring' : (this.currentStep > 2 ? 'circle-check' : 'square-gray'); }
    get step3Class() { return this.currentStep === 3 ? 'step active' : (this.currentStep > 3 ? 'step completed' : 'step'); }
    get step3IconClass() { return this.currentStep === 3 ? 'circle-ring' : (this.currentStep > 3 ? 'circle-check' : 'square-gray'); }
    get step4Class() { return this.currentStep === 4 ? 'step active' : (this.currentStep > 4 ? 'step completed' : 'step'); }
    get step4IconClass() { return this.currentStep === 4 ? 'circle-ring' : (this.currentStep > 4 ? 'circle-check' : 'square-gray'); }
    get step5Class() { return this.currentStep === 5 ? 'step active' : 'step'; }
    get step5IconClass() { return this.currentStep === 5 ? 'circle-ring' : 'square-gray'; }

    // --- Handlers ---
    handleDateChange(event) { this.dateSurvenance = event.target.value; }
    handlePoliceConnuChange(event) { this.isPoliceConnu = event.detail.value; this.searchType = undefined; this.searchResults = []; }
    handleSearchTypeChange(event) { this.searchType = event.detail.value; }
    
    handleRowClick(event) {
        const policyId = event.currentTarget.dataset.id;
        this.selectedPolicyId = policyId;
        const radioBtn = this.template.querySelector(`input[data-radio-id="${policyId}"]`);
        if (radioBtn) radioBtn.checked = true;
        this.template.querySelectorAll('.clickable-row').forEach(row => row.classList.remove('row-selected'));
        event.currentTarget.classList.add('row-selected');
    }

    handleCaseInputChange(event) {
        const field = event.target.dataset.field;
        this.caseData[field] = event.target.value;
    }

    handleContactToggle(event) {
        this.isSameAsInsured = event.detail.value === 'true';
        this.caseData.nomContact = this.isSameAsInsured && this.selectedPolicyRecord ? this.selectedPolicyRecord.InsuredName : '';
    }

    handleFolderChange(event) {
        this.selectedDirectory = event.detail.value;
        const types = this.allPicklistData[this.selectedDirectory] || [];
        this.optionsDocType = types.map(t => ({ label: t, value: t }));
        this.selectedDocType = '';
    }

    handleDocTypeChange(event) { this.selectedDocType = event.detail.value; }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        const newFiles = uploadedFiles.map((file, idx) => ({
            fileName: file.name,
            contentVersionId: file.contentVersionId,
            repertoire: this.selectedDirectory,
            typeDocument: this.selectedDocType,
            index: this.files.length + idx + 1
        }));
        this.files = [...this.files, ...newFiles];
        this.showToast('Succès', 'Fichiers chargés. Veuillez les indexer.', 'info');
    }

    async handleUploadSingle(event) {
        const fileName = event.target.dataset.id;
        const file = this.files.find(f => f.fileName === fileName);
        this.isLoading = true;
        try {
            const docObj = {
                RegistrationNumber__c: this.selectedPolicyRecord.RegistrationNumber,
                Police__c: this.selectedPolicyId,
                Directory__c: file.repertoire,
                Type_de_document__c: file.typeDocument 
            };

            // Appel de la méthode Apex de sauvegarde locale
            const result = await saveDocumentLocally({
                fileData: {
                    document: docObj,
                    caseId: this.createdCaseId,
                    typeDocument: file.typeDocument
                }
            });

            if (result === 'Ok') {
                this.uploadedDocumentIds = [...this.uploadedDocumentIds, file];
                this.files = this.files.filter(f => f.fileName !== fileName);
                this.showToast('Succès', `${fileName} indexé avec succès.`, 'success');
            }
        } catch (error) {
            this.showToast('Erreur', 'Erreur d\'indexation: ' + (error.body ? error.body.message : error.message), 'error');
        } finally { this.isLoading = false; }
    }

    handleRemoveFile(event) {
        const id = event.target.dataset.id;
        this.files = this.files.filter(f => f.fileName !== id);
    }

    handleDeleteDocument(event) {
        const id = event.target.dataset.id;
        this.uploadedDocumentIds = this.uploadedDocumentIds.filter(f => f.fileName !== id);
    }

    // --- Navigation ---
    async handleNext() {
    if (this.currentStep === 5) {
        // On passe à la nouvelle étape 6 (Circonstances)
        this.currentStep = 6;
        return;
    }

    if (this.currentStep === 6) {
        // Use the correct child LWC tag name based on the bundle folder da_lwc005_ClaimCircumstancesForm
        const form = this.template.querySelector('c-da-lwc005-claim-circumstances-form');
        if (form && form.validate()) {
            const data = form.formData;
            // Ici : Appel Apex pour sauvegarder l'objet Claim__c lié au Case
            this.saveClaim(data); 
        }
        return;
    }

        if (this.currentStep === 4) {
            const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
                .reduce((v, input) => { input.reportValidity(); return v && input.checkValidity(); }, true);
            if (!allValid) return;

            this.isLoading = true;
            try {
                const payload = { ...this.caseData, policyId: this.selectedPolicyId, vehicleId: this.selectedPolicyRecord.vehicleId, dateSurvenance: this.dateSurvenance };
                this.createdCaseId = await createClaimCase({ payload: JSON.stringify(payload) });
                this.showToast('Succès', 'Déclaration créée.', 'success');
                this.currentStep = 5;
            } catch (e) {
                this.showToast('Erreur', 'Échec création Case: ' + (e.body ? e.body.message : e.message), 'error');
            } finally { this.isLoading = false; }
            return;
        }

        if (this.currentStep === 3) { this.currentStep = 4; return; }

        if (this.currentStep === 2) {
            if (!this.selectedPolicyId) {
                this.showToast('Attention', 'Sélectionnez une police.', 'warning');
                return;
            }
            this.selectedPolicyRecord = this.searchResults.find(p => p.Id === this.selectedPolicyId);
            this.currentStep = 3; 
            return;
        }

        // Étape 1 : Recherche
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-radio-group')]
    .reduce((v, input) => { input.reportValidity(); return v && input.checkValidity(); }, true);

if (!allValid) return;

this.isLoading = true;
try {
    const params = {
        policyNumber: this.isOuiSelected ? this.template.querySelector('[data-id="police"]')?.value : null,
        registrationNumber: this.isOuiSelected ? this.template.querySelector('[data-id="immat"]')?.value : (this.searchType === 'immatriculation' ? this.template.querySelector('[data-id="critere"]')?.value : null),
        chassisNumber: this.searchType === 'chassis' ? this.template.querySelector('[data-id="critere"]')?.value : null,
        attestationNumber: this.searchType === 'attestation' ? this.template.querySelector('[data-id="critere"]')?.value : null
    };

    const data = await searchPolicies(params);

    if (data && data.length > 0) {
        const dSurvenance = new Date(this.dateSurvenance);
        dSurvenance.setHours(0, 0, 0, 0);

        // On filtre les résultats pour ne garder que ceux qui couvrent la date
        const validPolicies = data.filter(policy => {
            const dEffet = new Date(policy.DateEffet);
            const dExpiration = new Date(policy.DateExpiration);
            dEffet.setHours(0, 0, 0, 0);
            dExpiration.setHours(0, 0, 0, 0);
            
            return dSurvenance >= dEffet && dSurvenance <= dExpiration;
        });

        if (validPolicies.length > 0) {
            // On affiche uniquement les polices valides à l'étape 2
            this.searchResults = validPolicies;
            this.currentStep = 2;
        } else {
            // AUCUNE police ne couvre cette date
            const firstResult = data[0]; // On prend la première pour afficher un message d'exemple
            this.showToast(
                'Période non couverte', 
                `Le contrat trouvé n'est pas valide le ${this.dateSurvenance}. (Période : du ${firstResult.DateEffet} au ${firstResult.DateExpiration})`, 
                'error'
            );
            // On reste à l'étape 1
                }
            } else {
                this.showToast('Information', 'Aucune police trouvée avec ces critères.', 'info');
            }
        } catch (e) {
            this.showToast('Erreur', 'Erreur lors de la recherche technique.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handlePrecedent() { if (this.currentStep > 1) this.currentStep -= 1; }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}