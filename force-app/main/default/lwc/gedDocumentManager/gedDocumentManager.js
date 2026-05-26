import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import DOCUMENT_OBJECT from '@salesforce/schema/Document__c';
import DIRECTORY_FIELD from '@salesforce/schema/Document__c.Directory__c';
import TYPEDOC_FIELD from '@salesforce/schema/Document__c.Type_de_document__c';

import saveDocumentWithGED from '@salesforce/apex/DocumentGEDController.saveDocumentWithGED';
import getDocumentsByCase from '@salesforce/apex/DocumentGEDController.getDocumentsByCase';
import deleteDocument from '@salesforce/apex/DocumentGEDController.deleteDocument';

export default class GedDocumentManager extends LightningElement {
    // --- Variables d'entrée (API) ---
    @api caseId;
    @api caseNumber;
    @api policyId;
    @api policyNumber;
    @api registrationNumber;
    @api dateSurvenance;

    // --- États ---
    @track isLoading = false;
    
    // --- Fichier ---
    @track selectedFile = null;
    @track selectedFileName = '';
    
    // --- Formulaire ---
    @track repertoire = '';
    @track typeDocument = '';
    @track nature = '';
    
    // --- Listes ---
    @track allPicklistData = {};
    @track optionsDirectory = [];
    @track optionsDocType = [];

    // --- Tableau ---
    @track documents = [];
    wiredDocsResult;

    // --- Getters ---
    get isUploadDisabled() { return !this.selectedFile || !this.repertoire || !this.typeDocument; }
    get isTypeDisabled() { return !this.repertoire; }
    get hasDocuments() { return this.documents && this.documents.length > 0; }

   

    // 2. Charger les documents liés à la déclaration
    @wire(getDocumentsByCase, { caseId: '$caseId' })
    wiredDocuments(result) {
        this.wiredDocsResult = result;
        if (result.data) {
            this.documents = result.data;
        }
    }
    
    // 1. On récupère les infos de l'objet Document (pour le RecordTypeId)
    @wire(getObjectInfo, { objectApiName: DOCUMENT_OBJECT })
    documentInfo;

    // 2. On récupère automatiquement les vraies valeurs de la liste "Répertoire"
    @wire(getPicklistValues, { 
        recordTypeId: '$documentInfo.data.defaultRecordTypeId', 
        fieldApiName: DIRECTORY_FIELD 
    })
    wiredDirectoryValues({ data, error }) {
        if (data) {
            this.optionsDirectory = data.values; // Récupère direct les API Names corrects !
        }
    }

    // 3. On récupère automatiquement les vraies valeurs de la liste "Type de document"
    @wire(getPicklistValues, { 
        recordTypeId: '$documentInfo.data.defaultRecordTypeId', 
        fieldApiName: TYPEDOC_FIELD 
    })
    wiredTypeDocValues({ data, error }) {
        if (data) {
            this.allTypeDocValues = data; // On stocke tout pour filtrer ensuite (si liste dépendante)
            this.optionsDocType = data.values;
        }
    }

    // 3. Gestion Formulaire
    handleInputChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
        
        if (field === 'repertoire') {
            // Optionnel : Si vos types de documents dépendent du répertoire, 
            // la logique standard LWC gère ça via les "controllingValues" de l'objet data renvoyé.
            // Si ce n'est pas une liste dépendante dans Salesforce, il n'y a rien d'autre à faire !
            this.typeDocument = ''; 
        }
    }

    handleFileChange(event) {
        if (event.target.files.length > 0) {
            this.selectedFile = event.target.files[0];
            this.selectedFileName = this.selectedFile.name;
        }
    }

    clearFile() {
        this.selectedFile = null;
        this.selectedFileName = '';
        // Réinitialise l'input html
        const fileInput = this.template.querySelector('#file-upload');
        if(fileInput) fileInput.value = null;
    }

    // 4. UPLOAD VERS GOOGLE DRIVE ET SALESFORCE
    handleUpload() {
        this.isLoading = true;
        
        // Création du JSON contenant les informations
        const formData = {
            NumeroDeclaration__c: this.caseId,
            Police__c: this.policyId,
            RegistrationNumber__c: this.registrationNumber,
            OccurrenceDate__c: this.dateSurvenance,
            Directory__c: this.repertoire,
            Type_de_document__c: this.typeDocument,
            Nature__c: this.nature
        };

        const reader = new FileReader();
        reader.onload = () => {
            const base64Data = reader.result.split(',')[1];

            saveDocumentWithGED({
                recordId: this.caseId,
                base64Data: base64Data,
                fileName: this.selectedFileName,
                mimeType: this.selectedFile.type,
                formDataJSON: JSON.stringify(formData)
            })
            .then(() => {
                this.showToast('Succès', 'Document importé avec succès !', 'success');
                this.clearFile();
                this.nature = ''; 
                this.typeDocument = '';
                return refreshApex(this.wiredDocsResult); // Rafraîchit le tableau
            })
            .catch(error => {
                let msg = error.body ? error.body.message : error.message;
                this.showToast('Erreur', msg, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
        };
        reader.readAsDataURL(this.selectedFile);
    }

    // 5. Actions Tableau
    handleView(event) {
        const googleId = event.target.dataset.id;
        if (googleId) {
            window.open(`https://drive.google.com/file/d/${googleId}/view`, '_blank');
        } else {
            this.showToast('Erreur', 'Lien Drive introuvable.', 'error');
        }
    }

    handleDelete(event) {
        if(confirm('Voulez-vous vraiment supprimer ce document ?')) {
            this.isLoading = true;
            deleteDocument({ documentId: event.target.dataset.id })
                .then(() => {
                    this.showToast('Succès', 'Document supprimé.', 'success');
                    return refreshApex(this.wiredDocsResult);
                })
                .catch(err => this.showToast('Erreur', err.body ? err.body.message : err.message, 'error'))
                .finally(() => this.isLoading = false);
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}