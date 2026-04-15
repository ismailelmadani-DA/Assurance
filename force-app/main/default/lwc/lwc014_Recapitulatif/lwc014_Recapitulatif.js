import { LightningElement, api } from 'lwc';

export default class Lwc014_Recapitulatif extends LightningElement {
    // Récupération des données depuis le Parent
    @api policy = {};
    @api caseData = {};
    @api caseNumber = '';
    @api dateSurvenance = '';
    @api driver = {};
    @api passengers = [];
    @api adverseVehicles = [];
    @api otherParties = [];

    // Getters pour faciliter l'affichage HTML
    get hasAdverseVehicles() {
        return this.adverseVehicles && this.adverseVehicles.length > 0;
    }

    get hasOtherParties() {
        return this.otherParties && this.otherParties.length > 0;
    }

    get passengersCount() {
        return this.passengers ? this.passengers.length : 0;
    }
}