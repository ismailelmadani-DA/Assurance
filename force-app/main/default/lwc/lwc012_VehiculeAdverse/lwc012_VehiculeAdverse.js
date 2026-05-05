import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import VEHICLE_ASSIGNMENT_OBJECT from '@salesforce/schema/VehicleCaseAssignment__c';
import TYPE_VEHICULE_FIELD from '@salesforce/schema/VehicleCaseAssignment__c.TypeVehicule__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import PASSAGER_OBJECT from '@salesforce/schema/Passager__c';
import CIVILITE_FIELD from '@salesforce/schema/Passager__c.Civilite__c';
import PAYS_FIELD from '@salesforce/schema/Passager__c.Pays__c';
import VILLE_FIELD from '@salesforce/schema/Passager__c.Ville__c';
import SITUATION_FIELD from '@salesforce/schema/Passager__c.MaritalStatus__c';
import ETAT_PERSONNE_FIELD from '@salesforce/schema/Passager__c.StateOfPerson__c';

export default class Lwc012_VehiculeAdverse extends LightningElement {
    @api claimSummary;

    @api
    get savedAdverseVehicles() {
        return this._savedAdverseVehicles;
    }
    set savedAdverseVehicles(value) {
        if (value && value.length > 0) {
            this._savedAdverseVehicles = value;
            this.adverseVehicles = value.map(v => ({
                ...v,
                isPassengerFormOpen: false
            }));
            this.isFormVisible = false;
        }
    }
    _savedAdverseVehicles = [];

    @track adverseVehicles = [];
    @track isFormVisible = true;

    currentVehicleKeyForEdit = null;

    @track formData = {
        VehicleIsDamaged__c: '', Adversaire_Assure__c: 'false', TypeVehicule__c: '',
        RegistrationNumber__c: '', DateMiseEnCirculation__c: null, Marque__c: '',
        CompagnieAdverse__c: '', Numéro_de_contrat__c: '', NbDePassagerBlesses__c: 0
    };

    currentVehicleKey = null;
    currentPassengerKey = null;

    @track passengerData = {
        Name__c: '', Civilite__c: '', CIN__c: '', Pays__c: '', Adresse__c: '',
        BirthDay__c: null, MaritalStatus__c: '', Ville__c: '', StateOfPerson__c: ''
    };

    @track civiliteOptions = [];
    @track paysOptions = [];
    @track villeOptions = [];
    @track situationOptions = [];
    @track etatPersonneOptions = [];
    @track typeOptions = [];

    optionsAssure = [{ label: 'Oui', value: 'true' }, { label: 'Non', value: 'false' }];
    optionsEtat = [
        { label: 'Endommagé', value: 'Endommagé' },
        { label: 'Pas de dommage', value: 'Pas de dommage' }
    ];

    @wire(getObjectInfo, { objectApiName: PASSAGER_OBJECT }) passagerInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$passagerInfo.data.defaultRecordTypeId',
        fieldApiName: CIVILITE_FIELD
    })
    wiredCiv({ data }) { if (data) this.civiliteOptions = data.values; }

    @wire(getPicklistValues, {
        recordTypeId: '$passagerInfo.data.defaultRecordTypeId',
        fieldApiName: PAYS_FIELD
    })
    wiredPays({ data }) { if (data) this.paysOptions = data.values; }

    @wire(getPicklistValues, {
        recordTypeId: '$passagerInfo.data.defaultRecordTypeId',
        fieldApiName: VILLE_FIELD
    })
    wiredVille({ data }) { if (data) this.villeOptions = data.values; }

    @wire(getPicklistValues, {
        recordTypeId: '$passagerInfo.data.defaultRecordTypeId',
        fieldApiName: SITUATION_FIELD
    })
    wiredSitu({ data }) { if (data) this.situationOptions = data.values; }

    @wire(getPicklistValues, {
        recordTypeId: '$passagerInfo.data.defaultRecordTypeId',
        fieldApiName: ETAT_PERSONNE_FIELD
    })
    wiredEtatPassager({ data }) { if (data) this.etatPersonneOptions = data.values; }

    @wire(getObjectInfo, { objectApiName: VEHICLE_ASSIGNMENT_OBJECT }) objectMetadata;

    @wire(getPicklistValues, {
        recordTypeId: '$objectMetadata.data.defaultRecordTypeId',
        fieldApiName: TYPE_VEHICULE_FIELD
    })
    wiredType({ data }) { if (data) this.typeOptions = data.values; }

    handleInputChange(event) {
        this.formData[event.target.dataset.field] = event.target.value;
    }

    handleLookupChange(event) {
        this.formData.CompagnieAdverse__c = event.detail.recordId;
    }

    handleEditVehicle(event) {
        const keyToEdit = event.currentTarget.dataset.key;
        this.currentVehicleKeyForEdit = keyToEdit;
        const vehicle = this.adverseVehicles.find(v => v.key.toString() === keyToEdit.toString());
        if (vehicle) {
            this.formData = { ...vehicle };
            this.isFormVisible = true;
            setTimeout(() => {
                const picker = this.template.querySelector('lightning-record-picker');
                if (picker && vehicle.CompagnieAdverse__c) {
                    picker.value = vehicle.CompagnieAdverse__c;
                }
            }, 100);
        }
    }

    handleAjouter() {
        const allValid = [...this.template.querySelectorAll(
            'lightning-input[data-field], lightning-combobox[data-field], lightning-record-picker'
        )].reduce((v, i) => {
            if (i.reportValidity) i.reportValidity();
            return v && (i.checkValidity ? i.checkValidity() : true);
        }, true);

        if (allValid) {
            if (this.currentVehicleKeyForEdit) {
                this.adverseVehicles = this.adverseVehicles.map(v => {
                    if (v.key.toString() === this.currentVehicleKeyForEdit.toString()) {
                        return {
                            ...this.formData,
                            key: v.key,
                            passengers: v.passengers,
                            isPassengerFormOpen: v.isPassengerFormOpen
                        };
                    }
                    return v;
                });
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Succès', message: 'Véhicule mis à jour.', variant: 'success'
                }));
            } else {
                const newVehicle = {
                    ...this.formData,
                    key: Date.now(),
                    passengers: [],
                    isPassengerFormOpen: false
                };
                this.adverseVehicles = [...this.adverseVehicles, newVehicle];
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Succès', message: 'Véhicule adverse ajouté.', variant: 'success'
                }));
            }
            this.resetForm();
            this.isFormVisible = false;
            this.notifyParent();
        }
    }

    handleDelete(event) {
        const keyToDelete = event.currentTarget.dataset.key;
        this.adverseVehicles = this.adverseVehicles.filter(
            v => v.key.toString() !== keyToDelete.toString()
        );
        if (this.adverseVehicles.length === 0) this.isFormVisible = true;
        this.notifyParent();
    }

    openPassengerForm(event) {
        const vehKey = event.currentTarget.dataset.key;
        this.currentVehicleKey = vehKey;
        this.currentPassengerKey = null;
        this.passengerData = {
            Name__c: '', Civilite__c: '', CIN__c: '', Pays__c: '', Adresse__c: '',
            BirthDay__c: null, MaritalStatus__c: '', Ville__c: '', StateOfPerson__c: ''
        };
        this.adverseVehicles = this.adverseVehicles.map(v => ({
            ...v,
            isPassengerFormOpen: v.key.toString() === vehKey.toString()
        }));
    }

    closePassengerForm() {
        this.currentVehicleKey = null;
        this.currentPassengerKey = null;
        this.adverseVehicles = this.adverseVehicles.map(v => ({
            ...v,
            isPassengerFormOpen: false
        }));
    }

    handleEditPassenger(event) {
        const vehKey = event.currentTarget.dataset.vehkey;
        const passKey = event.currentTarget.dataset.passkey;
        this.currentVehicleKey = vehKey;
        this.currentPassengerKey = passKey;
        const vehicle = this.adverseVehicles.find(v => v.key.toString() === vehKey.toString());
        if (vehicle) {
            const passenger = vehicle.passengers.find(p => p.key.toString() === passKey.toString());
            if (passenger) {
                this.passengerData = { ...passenger };
                this.adverseVehicles = this.adverseVehicles.map(v => ({
                    ...v,
                    isPassengerFormOpen: v.key.toString() === vehKey.toString()
                }));
            }
        }
    }

    handlePassInputChange(event) {
        this.passengerData[event.target.dataset.passfield] = event.target.value;
    }

    handleSavePassenger() {
        const allValid = [...this.template.querySelectorAll(
            'lightning-input[data-passfield], lightning-combobox[data-passfield], lightning-textarea[data-passfield]'
        )].reduce((v, i) => {
            if (i.reportValidity) i.reportValidity();
            return v && i.checkValidity();
        }, true);

        if (allValid) {
            this.adverseVehicles = this.adverseVehicles.map(veh => {
                if (veh.key.toString() === this.currentVehicleKey.toString()) {
                    if (this.currentPassengerKey) {
                        veh.passengers = veh.passengers.map(p => {
                            if (p.key.toString() === this.currentPassengerKey.toString()) {
                                return { ...this.passengerData, key: p.key };
                            }
                            return p;
                        });
                    } else {
                        veh.passengers = [...veh.passengers, { ...this.passengerData, key: Date.now() }];
                    }
                }
                return { ...veh };
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Succès',
                message: this.currentPassengerKey ? 'Passager mis à jour.' : 'Passager lié au véhicule.',
                variant: 'success'
            }));

            this.closePassengerForm();
            this.notifyParent();
        }
    }

    handleDeletePassenger(event) {
        const vehKey = event.currentTarget.dataset.vehkey;
        const passKey = event.currentTarget.dataset.passkey;
        this.adverseVehicles = this.adverseVehicles.map(veh => {
            if (veh.key.toString() === vehKey.toString()) {
                return {
                    ...veh,
                    passengers: veh.passengers.filter(p => p.key.toString() !== passKey.toString())
                };
            }
            return veh;
        });
        this.notifyParent();
    }

    showForm() { this.isFormVisible = true; }

    handleAnnuler() {
        this.resetForm();
        if (this.adverseVehicles.length > 0) this.isFormVisible = false;
    }

    resetForm() {
        this.currentVehicleKeyForEdit = null;
        this.formData = {
            VehicleIsDamaged__c: '', Adversaire_Assure__c: 'false', TypeVehicule__c: '',
            RegistrationNumber__c: '', DateMiseEnCirculation__c: null, Marque__c: '',
            CompagnieAdverse__c: '', Numéro_de_contrat__c: '', NbDePassagerBlesses__c: 0
        };
        const picker = this.template.querySelector('lightning-record-picker');
        if (picker) picker.clearSelection();
    }

    @api get adverseVehicleData() { return this.adverseVehicles; }
    @api validate() { return true; }

    notifyParent() {
        this.dispatchEvent(new CustomEvent('adversevehicleupdate', { detail: this.adverseVehicles }));
    }
}