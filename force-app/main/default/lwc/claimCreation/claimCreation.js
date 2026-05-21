import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { IsConsoleNavigation, getFocusedTabInfo, closeTab } from 'lightning/platformWorkspaceApi';

// Import des objets et champs pour Picklists dynamiques
import CASE_OBJECT from '@salesforce/schema/Case';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import COUNTRY_FIELD from '@salesforce/schema/Case.CountryOfOccurrence__c';
import CITY_FIELD from '@salesforce/schema/Case.CityOfOccurrence__c';
import CLAIMANT_FIELD from '@salesforce/schema/Case.Claimant__c';
import PV_FIELD from '@salesforce/schema/Case.IncidentReport__c';
import NOTIF_FIELD from '@salesforce/schema/Account.MoyenNotification__c';

// Apex
import searchPolicies from '@salesforce/apex/ClaimSearchController.searchPolicies';
import createCase from '@salesforce/apex/ClaimSearchController.createCase';
import getPicklistOptions from '@salesforce/apex/ClaimSearchController.getTypeDocumentsByReportoire';
import saveDocumentLocally from '@salesforce/apex/ClaimSearchController.saveDocumentLocally';
import updateCaseRecord from '@salesforce/apex/ClaimSearchController.updateCaseRecord';
import savePassengers from '@salesforce/apex/ClaimSearchController.savePassengers';
import saveAdverseVehicle from '@salesforce/apex/ClaimSearchController.saveAdverseVehicle';
import saveOtherParties from '@salesforce/apex/ClaimSearchController.saveOtherParties';
import finalizeClaimProcess from '@salesforce/apex/ClaimSearchController.finalizeClaimProcess';
import updateWizardStep from '@salesforce/apex/ClaimSearchController.updateWizardStep';
import getClaimProgressSnapshot from '@salesforce/apex/ClaimSearchController.getClaimProgressSnapshot';

export default class ClaimCreationWizard extends NavigationMixin(LightningElement) {

    @wire(IsConsoleNavigation) isConsoleNavigation;

    // recordId reçu via Quick Action "Poursuivre la déclaration"
    @api recordId;

    // =========================================================
    // ÉTATS ET FLAGS
    // =========================================================
    @track currentStep = 1;
    @track isLoading = false;
    @track searchResults = [];
    @track isPoliceConnu;
    @track searchType;
    @track isFileUploaded = false;
    messageObligatoire = false;
    @api errorMessage = 'Prière d\'indexer le(s) document(s).';

   
    @track step1Data = {
        police: '',
        immat: '',
        dateSurvenance: '',
        heureSurvenance: '',
        critere: ''
    };

    @track caseAlreadyCreated = false;

    // --- Decision modal (étape 4) ---
    @track showDecisionModal = false;
    @track decisionChoice = '';
    @track motifRejet = '';
    @track motifRejetError = '';
    @track isConfirmingDecision = false;

    decisionOptions = [
        { label: 'Poursuivre la déclaration', value: 'continue' },
        { label: 'Rejeter la déclaration', value: 'reject' }
    ];

    get isRejectChoice() { return this.decisionChoice === 'reject'; }
    get isContinueChoice() { return this.decisionChoice === 'continue'; }
    get isDecisionConfirmDisabled() { return !this.decisionChoice || this.isConfirmingDecision; }
    get confirmLabel() { return this.isConfirmingDecision ? 'Traitement...' : 'Confirmer'; }

    // Date du jour dynamique
    @track todayDate = new Date().toISOString().split('T')[0];

    // --- Données Police & Véhicule ---
    @track selectedPolicyId;
    @track dateSurvenance;
    @track selectedPolicyRecord;
    @track IdPolice;
    @track PoliceValue;
    @track adverseVehicleData = [];
    @track otherPartiesData = [];

    // --- Variables pour l'objet Case (Étape 4) ---
    @track createdCaseId;
    @track createdCaseNumber;
    @track caseData = {
        country: '', city: '', address: '', dateDepot: '', declarant: '',
        pvConstat: '', commentaire: '', nomContact: '', telContact: '',
        mailContact: '', moyenNotification: ''
    };
    @track isSameAsInsured = false;

    // --- Variables pour l'étape 5 (Documents) ---
    @track files = [];
    @track uploadedDocumentIds = [];
    @track allPicklistData = {};
    @track optionsDirectory = [];
    @track optionsDocType = [];
    @track selectedDirectory = '';
    @track selectedDocType = '';
    @track firstPicklistValue = '';
    @track secondPicklistValue = '';
    @track document = {};
    MAX_FILE_SIZE = 3145728; // 3 MB

    // --- Variables pour les étapes 6, 7 et 8 ---
    @track claimId;
    @track circumstancesData = {};
    @track driverData = {};
    @track passengersData = [];

    // --- Options Picklists ---
    @track optionsPays = [];
    @track optionsVille = [];
    @track optionsDeclarant = [];
    @track optionsPV = [];
    @track optionsNotif = [];

    optionsOuiNon = [{ label: 'Oui', value: 'Oui' }, { label: 'Non', value: 'Non' }];
    optionsCriteres = [
        { label: "Numéro d'immatriculation", value: 'immatriculation' },
        { label: "Numéro d'attestation", value: 'attestation' },
        { label: "Numéro chassis", value: 'chassis' }
    ];
    optionsContact = [{ label: 'Oui', value: 'true' }, { label: 'Non', value: 'false' }];

    // =========================================================
    // WIRES : Données Case & Account
    // =========================================================
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

    // WIRE : Métadonnées Documents
    @wire(getPicklistOptions)
    wiredPicklistOptions({ error, data }) {
        if (data) {
            this.allPicklistData = data;
            this.optionsDirectory = Object.keys(data).map(key => ({ label: key, value: key }));
        } else if (error) {
            console.error('Erreur picklist documents:', error);
        }
    }

    // =========================================================
    // GETTERS DE NAVIGATION
    // =========================================================
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get isStep5() { return this.currentStep === 5; }
    get isStep6() { return this.currentStep === 6; }
    get isStep7() { return this.currentStep === 7; }
    get isStep8() { return this.currentStep === 8; }
    get isStep9() { return this.currentStep === 9; }
    get isStep10() { return this.currentStep === 10; }
    get isStep11() { return this.currentStep === 11; }
    get isStep12() { return this.currentStep === 12; }

    get showFooter() { return this.currentStep <= 12; }
    get showPrecedent() { return this.currentStep > 1; }

    get isOuiSelected() { return this.isPoliceConnu === 'Oui'; }
    get isNonSelected() { return this.isPoliceConnu === 'Non'; }
    get isSameAsInsuredString() { return this.isSameAsInsured.toString(); }
    get isUploadDisabled() { return !this.selectedDirectory || !this.selectedDocType; }

    get inputLabel() {
        const labels = {
            immatriculation: "Numéro d'immatriculation",
            attestation: "Numéro d'attestation",
            chassis: "Numéro chassis"
        };
        return labels[this.searchType] || "Valeur";
    }

    // =========================================================
    // GETTERS STEPPER (Classes CSS)
    // =========================================================
    get step1Class() { return this.currentStep === 1 ? 'step active' : 'step completed'; }
    get step1IconClass() { return this.currentStep > 1 ? 'circle-check' : 'circle-ring'; }
    get step2Class() { return this.currentStep === 2 ? 'step active' : (this.currentStep > 2 ? 'step completed' : 'step'); }
    get step2IconClass() { return this.currentStep === 2 ? 'circle-ring' : (this.currentStep > 2 ? 'circle-check' : 'square-gray'); }
    get step3Class() { return this.currentStep === 3 ? 'step active' : (this.currentStep > 3 ? 'step completed' : 'step'); }
    get step3IconClass() { return this.currentStep === 3 ? 'circle-ring' : (this.currentStep > 3 ? 'circle-check' : 'square-gray'); }
    get step4Class() { return this.currentStep === 4 ? 'step active' : (this.currentStep > 4 ? 'step completed' : 'step'); }
    get step4IconClass() { return this.currentStep === 4 ? 'circle-ring' : (this.currentStep > 4 ? 'circle-check' : 'square-gray'); }
    get step5Class() { return this.currentStep === 5 ? 'step active' : (this.currentStep > 5 ? 'step completed' : 'step'); }
    get step5IconClass() { return this.currentStep === 5 ? 'circle-ring' : (this.currentStep > 5 ? 'circle-check' : 'square-gray'); }
    get step6Class() { return this.currentStep === 6 ? 'step active' : (this.currentStep > 6 ? 'step completed' : 'step'); }
    get step6IconClass() { return this.currentStep === 6 ? 'circle-ring' : (this.currentStep > 6 ? 'circle-check' : 'square-gray'); }
    get step7Class() { return this.currentStep === 7 ? 'step active' : (this.currentStep > 7 ? 'step completed' : 'step'); }
    get step7IconClass() { return this.currentStep === 7 ? 'circle-ring' : (this.currentStep > 7 ? 'circle-check' : 'square-gray'); }
    get step8Class() { return this.currentStep === 8 ? 'step active' : (this.currentStep > 8 ? 'step completed' : 'step'); }
    get step8IconClass() { return this.currentStep === 8 ? 'circle-ring' : (this.currentStep > 8 ? 'circle-check' : 'square-gray'); }
    get step9Class() { return this.currentStep === 9 ? 'step active' : (this.currentStep > 9 ? 'step completed' : 'step'); }
    get step9IconClass() { return this.currentStep === 9 ? 'circle-ring' : (this.currentStep > 9 ? 'circle-check' : 'square-gray'); }
    get step10Class() { return this.currentStep === 10 ? 'step active' : (this.currentStep > 10 ? 'step completed' : 'step'); }
    get step10IconClass() { return this.currentStep === 10 ? 'circle-ring' : (this.currentStep > 10 ? 'circle-check' : 'square-gray'); }
    get step11Class() { return this.currentStep === 11 ? 'step active' : (this.currentStep > 11 ? 'step completed' : 'step'); }
    get step11IconClass() { return this.currentStep === 11 ? 'circle-ring' : (this.currentStep > 11 ? 'circle-check' : 'square-gray'); }
    get step12Class() { return this.currentStep === 12 ? 'step active' : (this.currentStep > 12 ? 'step completed' : 'step'); }
    get step12IconClass() { return this.currentStep === 12 ? 'circle-ring' : (this.currentStep > 12 ? 'circle-check' : 'square-gray'); }

    // --- Données pour composants enfants ---
    get summaryForChild() {
        return {
            dateSurvenance: this.dateSurvenance,
            policyNumber: this.selectedPolicyRecord?.PolicyNumber,
            registrationNumber: this.selectedPolicyRecord?.RegistrationNumber,
            caseNumber: this.createdCaseNumber || 'En cours',
            nbBlesses: this.driverData?.NumberOfInjuredPassengers__c || 0,
            brand: this.selectedPolicyRecord?.Brand || '-',
            vehicleName: this.selectedPolicyRecord?.vehicleName || '-',
            driverName: this.driverData ? `${this.driverData.FirstName || ''} ${this.driverData.LastName || ''}`.trim() : 'Non renseigné'
        };
    }

  
    @wire(CurrentPageReference)
    setPageReference(pageRef) {
        if (!this.recordId && pageRef && pageRef.state) {
            const fromState = pageRef.state.c__recordId || pageRef.state.recordId;
            if (fromState) {
                this.recordId = fromState;
                this.hydrateFromCase(fromState);
            }
        }
    }

    connectedCallback() {
        if (this.recordId) {
            this.hydrateFromCase(this.recordId);
        }
    }

    async hydrateFromCase(caseId) {
        this.isLoading = true;
        try {
            const snap = await getClaimProgressSnapshot({ caseId });
            if (!snap) return;

            this.createdCaseId = snap.caseId;
            this.createdCaseNumber = snap.caseNumber;
            this.caseAlreadyCreated = true;
            this.selectedPolicyId = snap.selectedPolicyId;
            this.dateSurvenance = snap.dateSurvenance;
            this.isSameAsInsured = snap.isSameAsInsured === true;

            if (snap.selectedPolicyRecord) {
                this.selectedPolicyRecord = snap.selectedPolicyRecord;
            }
            if (snap.caseData) {
                this.caseData = { ...this.caseData, ...snap.caseData };
            }
            if (snap.circumstancesData) {
                this.circumstancesData = snap.circumstancesData;
            }
            if (snap.passengersData) {
                this.passengersData = snap.passengersData;
            }
            if (snap.adverseVehicleData) {
                this.adverseVehicleData = snap.adverseVehicleData;
            }
            if (snap.otherPartiesData) {
                this.otherPartiesData = snap.otherPartiesData;
            }

            const target = snap.lastStep && snap.lastStep >= 5 ? snap.lastStep : 5;
            this.currentStep = target;
        } catch (error) {
            this.showToast('Erreur', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async persistStep(step) {
        if (!this.createdCaseId || step == null) return;
        try {
            await updateWizardStep({ caseId: this.createdCaseId, step });
        } catch (error) {
            // silencieux : la sauvegarde de progression ne doit pas bloquer la navigation
        }
    }

    handleStep1Change(event) {
        const fieldId = event.target.dataset.id;
        this.step1Data = { ...this.step1Data, [fieldId]: event.target.value };
        // Synchroniser dateSurvenance utilisée dans toute l'application
        if (fieldId === 'dateSurvenance') {
            this.dateSurvenance = event.target.value;
        }
    }

    // =========================================================
    // HANDLERS RECHERCHE & SÉLECTION
    // =========================================================
    handleDateChange(event) {
        this.dateSurvenance = event.target.value;
    }

    handlePoliceConnuChange(event) {
        this.isPoliceConnu = event.detail.value;
        this.searchType = undefined;
        this.searchResults = [];
        this.selectedPolicyId = undefined;
    }

    handleSearchTypeChange(event) {
        this.searchType = event.detail.value;
        this.selectedPolicyId = undefined;
    }

    
    handleRowClick(event) {
        const policyId = event.currentTarget.dataset.id;
        this.selectedPolicyId = policyId;

        this.searchResults = this.searchResults.map(p => ({
            ...p,
            isSelected: p.Id === policyId,
            rowClass: p.Id === policyId ? 'clickable-row row-selected' : 'clickable-row'
        }));
    }

    // =========================================================
    // HANDLER FORMULAIRE CASE (Étape 4)
    // =========================================================
    handleCaseInputChange(event) {
        const field = event.target.dataset.field;
        this.caseData = { ...this.caseData, [field]: event.target.value };
    }

    handleContactToggle(event) {
        this.isSameAsInsured = event.detail.value === 'true';
        if (this.isSameAsInsured && this.selectedPolicyRecord) {
            this.caseData = {
                ...this.caseData,
                nomContact: this.selectedPolicyRecord.InsuredName,
                telContact: this.selectedPolicyRecord.InsuredPhone || '',
                mailContact: this.selectedPolicyRecord.InsuredEmail || ''
            };
        } else {
            this.caseData = {
                ...this.caseData,
                nomContact: '',
                telContact: '',
                mailContact: ''
            };
        }
    }

    // =========================================================
    // HANDLERS DOCUMENTS (Étape 5)
    // =========================================================
    handleFolderChange(event) {
        this.selectedDirectory = event.target.value;
        const types = this.allPicklistData[this.selectedDirectory] || [];
        this.optionsDocType = types.map(t => ({ label: t, value: t }));
        this.selectedDocType = '';
    }

    handleDocTypeChange(event) {
        this.selectedDocType = event.target.value;
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        const currentFileCount = this.files.length;
        uploadedFiles.forEach((file, idx) => {
            const newFile = {
                fileName: file.name,
                size: file.size,
                contentVersionId: file.contentVersionId,
                typeDocument: this.selectedDocType,
                repertoire: this.selectedDirectory,
                index: currentFileCount + idx + 1
            };
            this.files = [...this.files, newFile];
        });
        this.isFileUploaded = true;
        this.showToast('Success', `${uploadedFiles.length} fichier(s) chargé(s)`, 'success');
    }

    async handleUploadSingle(event) {
        const fileName = event.target.dataset.id;
        const file = this.files.find(f => f.fileName === fileName);
        if (file.size > this.MAX_FILE_SIZE) {
            this.showToast('Erreur', `Le fichier dépasse 3 Mo`, 'error');
            return;
        }
        this.isLoading = true;
        try {
            const docObj = {
                RegistrationNumber__c: this.selectedPolicyRecord.RegistrationNumber,
                Police__c: this.selectedPolicyId,
                Directory__c: file.repertoire,
                Type_de_document__c: file.typeDocument
            };
            const result = await saveDocumentLocally({
                fileData: { document: docObj, caseId: this.createdCaseId, typeDocument: file.typeDocument }
            });
            if (result === 'Ok') {
                this.uploadedDocumentIds = [...this.uploadedDocumentIds, file];
                this.files = this.files.filter(f => f.fileName !== fileName);
                this.showToast('Succès', `${fileName} indexé`, 'success');
            }
        } catch (error) {
            this.showToast('Erreur', 'Indexation échouée', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRemoveFile(event) {
        const id = event.target.dataset.id;
        this.files = this.files.filter(f => f.fileName !== id);
        this.isFileUploaded = this.files.length > 0;
    }

    // =========================================================
    // HANDLERS ENFANTS (Étapes 6, 7, 8, 9, 10)
    // =========================================================
    handleCircumstancesUpdate(event) { this.circumstancesData = event.detail; }
    handleDriverUpdate(event) { this.driverData = event.detail; }
    handlePassengersUpdate(event) { this.passengersData = event.detail; }
    handleAdverseVehicleUpdate(event) { this.adverseVehicleData = event.detail; }
    handleOtherPartiesUpdate(event) { this.otherPartiesData = event.detail; }

    // =========================================================
    // NAVIGATION PRINCIPALE
    // =========================================================
    async handleNext() {
        this.isLoading = true;
        try {

            // -----------------------------------------------
            // ÉTAPE 1 : Recherche Police & Validation Date
            // -----------------------------------------------
            if (this.currentStep === 1) {
                const allValid = [...this.template.querySelectorAll('lightning-input, lightning-radio-group')]
                    .reduce((v, i) => { i.reportValidity(); return v && i.checkValidity(); }, true);
                if (!allValid) { this.isLoading = false; return; }

                const params = {
                    policyNumber: this.step1Data.police || null,
                    registrationNumber: this.isOuiSelected
                        ? (this.step1Data.immat || null)
                        : (this.searchType === 'immatriculation' ? this.step1Data.critere : null),
                    chassisNumber: this.searchType === 'chassis' ? this.step1Data.critere : null,
                    attestationNumber: this.searchType === 'attestation' ? this.step1Data.critere : null
                };

                const data = await searchPolicies(params);
                if (data && data.length > 0) {
                    const dSurv = new Date(this.dateSurvenance).setHours(0, 0, 0, 0);
                    const validPols = data.filter(p => {
                        const dEf = new Date(p.DateEffet).setHours(0, 0, 0, 0);
                        const dEx = new Date(p.DateExpiration).setHours(0, 0, 0, 0);
                        return dSurv >= dEf && dSurv <= dEx;
                    });
                    if (validPols.length > 0) {
                        this.searchResults = validPols.map(p => ({
                            ...p,
                            isSelected: false,
                            rowClass: 'clickable-row'
                        }));
                        this.currentStep = 2;
                    } else {
                        this.showToast('Erreur', 'Période non couverte par ce contrat.', 'error');
                    }
                } else {
                    this.showToast('Info', 'Aucune police trouvée avec ces critères.', 'info');
                }
            }

            // -----------------------------------------------
            // ÉTAPE 2 : Sélection de la Police
            // -----------------------------------------------
            else if (this.currentStep === 2) {
                if (!this.selectedPolicyId) {
                    this.showToast('Attention', 'Veuillez sélectionner une police avant de continuer.', 'warning');
                    this.isLoading = false;
                    return;
                }
                this.selectedPolicyRecord = this.searchResults.find(p => p.Id === this.selectedPolicyId);
                this.currentStep = 3;
            }

            // -----------------------------------------------
            // ÉTAPE 3 : Consultation Infos (Navigation simple)
            // -----------------------------------------------
            else if (this.currentStep === 3) {
                this.currentStep = 4;
            }

            // -----------------------------------------------
            // ÉTAPE 4 : Création de la Déclaration (Case)
            // -----------------------------------------------
            else if (this.currentStep === 4) {
                const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
                    .reduce((v, i) => { i.reportValidity(); return v && i.checkValidity(); }, true);
                if (!allValid) { this.isLoading = false; return; }

                // ✅ Si le Case a déjà été créé (retour arrière), on ne recrée pas
                if (this.caseAlreadyCreated) {
                    this.currentStep = 5;
                    this.isLoading = false;
                    return;
                }

                this.decisionChoice = '';
                this.motifRejet = '';
                this.motifRejetError = '';
                this.showDecisionModal = true;
                this.isLoading = false;
                return;
            }

            // -----------------------------------------------
            // ÉTAPE 5 : Documents (Navigation simple)
            // -----------------------------------------------
            else if (this.currentStep === 5) {
                this.currentStep = 6;
                this.persistStep(6);
            }

            // -----------------------------------------------
            // ÉTAPE 6 : Mise à jour des Circonstances
            // -----------------------------------------------
            else if (this.currentStep === 6) {
                const formChild = this.template.querySelector('c-d-a_lwc005_-claim-circumstances-form');
                if (formChild && formChild.validate()) {
                    await updateCaseRecord({
                        caseId: this.createdCaseId,
                        caseData: formChild.formData
                    });
                    this.showToast('Succès', 'Circonstances enregistrées', 'success');
                    this.currentStep = 7;
                    this.persistStep(7);
                }
            }

            // -----------------------------------------------
            // ÉTAPE 7 : Infos Conducteur
            // -----------------------------------------------
            else if (this.currentStep === 7) {
                const driverChild = this.template.querySelector('c-lwc007_-driver-info');
                if (driverChild && driverChild.validate()) {
                    this.currentStep = 8;
                    this.persistStep(8);
                }
            }

            // -----------------------------------------------
            // ÉTAPE 8 : Passagers Assurés
            // -----------------------------------------------
            else if (this.currentStep === 8) {
                const passengerChild = this.template.querySelector('c-lwc011_-passagers-assure');
                if (passengerChild && passengerChild.validate()) {
                    if (this.passengersData && this.passengersData.length > 0) {
                        await savePassengers({
                            caseId: this.createdCaseId,
                            passengersJson: JSON.stringify(this.passengersData)
                        });
                    }
                    this.currentStep = 9;
                    this.persistStep(9);
                }
            }

            // -----------------------------------------------
            // ÉTAPE 9 : Véhicule Adverse
            // -----------------------------------------------
            else if (this.currentStep === 9) {
                const adverseChild = this.template.querySelector('c-lwc012_-vehicule-adverse');
                if (adverseChild && adverseChild.validate()) {
                    const dataFromChild = adverseChild.adverseVehicleData;

                    if (!dataFromChild || dataFromChild.length === 0) {
                        this.currentStep = 10;
                        this.persistStep(10);
                        this.isLoading = false;
                        return;
                    }

                    try {
                        await saveAdverseVehicle({
                            caseId: this.createdCaseId,
                            adverseDataJson: JSON.stringify(dataFromChild)
                        });
                        this.showToast('Succès', 'Informations du tiers enregistrées', 'success');
                        this.currentStep = 10;
                        this.persistStep(10);
                    } catch (error) {
                        this.showToast('Erreur', error.body?.message || error.message, 'error');
                    } finally {
                        this.isLoading = false;
                    }
                } else {
                    this.isLoading = false;
                }
            }

            // -----------------------------------------------
            // ÉTAPE 10 : Dommages Autres Parties
            // -----------------------------------------------
            else if (this.currentStep === 10) {
                const partyChild = this.template.querySelector('c-lwc013_-dommages-autres-parties');

                if (partyChild && partyChild.validate()) {
                    if (!this.otherPartiesData || this.otherPartiesData.length === 0) {
                        this.currentStep = 11;
                        this.persistStep(11);
                        return;
                    }

                    this.isLoading = true;
                    try {
                        await saveOtherParties({
                            caseId: this.createdCaseId,
                            partiesJson: JSON.stringify(this.otherPartiesData)
                        });
                        this.showToast('Succès', 'Informations Tiers enregistrées', 'success');
                        this.currentStep = 11;
                        this.persistStep(11);
                    } catch (error) {
                        this.showToast('Erreur', error.body?.message || error.message, 'error');
                    } finally {
                        this.isLoading = false;
                    }
                }
            }

            // -----------------------------------------------
            // ÉTAPE 11 : Garanties de la police
            // -----------------------------------------------
            else if (this.currentStep === 11) {
                const garantiesChild = this.template.querySelector('c-lwc015_-garanties-police');
                if (garantiesChild) {
                    await garantiesChild.saveCoverages();
                }
                this.currentStep = 12;
                this.persistStep(12);
            }

            // -----------------------------------------------
            // ÉTAPE 12 : Finalisation et création du Sinistre
            // -----------------------------------------------
            else if (this.currentStep === 12) {
                this.isLoading = true;
                try {
                    const finalClaimId = await finalizeClaimProcess({
                        caseId: this.createdCaseId
                    });

                    this.showToast('Succès', 'Le dossier sinistre a été finalisé et mis en traitement !', 'success');

                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: finalClaimId,
                            objectApiName: 'Claim__c',
                            actionName: 'view'
                        }
                    });
                } catch (error) {
                    this.showToast('Erreur', error.body?.message || error.message, 'error');
                } finally {
                    this.isLoading = false;
                }
            }

        } catch (error) {
            this.showToast('Erreur', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleDecisionChange(event) {
        this.decisionChoice = event.target.value;
        this.motifRejetError = '';
    }

    handleMotifRejetChange(event) {
        this.motifRejet = event.target.value;
        if (this.motifRejet && this.motifRejet.trim()) {
            this.motifRejetError = '';
        }
    }

    handleCancelDecision() {
        this.showDecisionModal = false;
        this.decisionChoice = '';
        this.motifRejet = '';
        this.motifRejetError = '';
        this.isConfirmingDecision = false;
    }

    async handleConfirmDecision() {
        if (this.isConfirmingDecision) return;
        if (!this.decisionChoice) return;

        if (this.decisionChoice === 'reject' && !this.motifRejet.trim()) {
            this.motifRejetError = 'Le motif de rejet est obligatoire.';
            return;
        }

        this.isConfirmingDecision = true;
        this.isLoading = true;
        try {
            const payload = {
                ...this.caseData,
                policyId: this.selectedPolicyId,
                vehicleId: this.selectedPolicyRecord.vehicleId,
                dateSurvenance: this.dateSurvenance,
                insuredIsContact: this.insuredIsContact
            };
            if (this.decisionChoice === 'reject') {
                payload.rejectMotif = this.motifRejet.trim();
            }

            const result = await createCase({ payload: JSON.stringify(payload) });
            this.createdCaseId = result.id;
            this.createdCaseNumber = result.caseNumber;
            this.caseAlreadyCreated = true;
            this.showDecisionModal = false;

            if (this.decisionChoice === 'reject') {
                this.showToast('Succès', 'Déclaration rejetée.', 'success');
                this.redirectToCase(this.createdCaseId);
            } else {
                this.showToast('Succès', 'Déclaration initialisée', 'success');
                this.currentStep = 5;
            }
        } catch (error) {
            this.showToast('Erreur', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
            this.isConfirmingDecision = false;
        }
    }

    handlePrecedent() {
        if (this.currentStep > 1) {
            this.currentStep -= 1;
        }
    }

    redirectToCase(caseId) {
        if (!caseId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: caseId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
        if (this.isConsoleNavigation) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(async () => {
                try {
                    const focused = await getFocusedTabInfo();
                    if (focused && focused.tabId) {
                        await closeTab(focused.tabId);
                    }
                } catch (e) {
                    // ignore — not in a Console workspace
                }
            }, 400);
        }
    }

    // =========================================================
    // TOAST
    // =========================================================
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'sticky'
        }));
    }
}