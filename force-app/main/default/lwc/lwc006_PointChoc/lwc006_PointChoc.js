// lwc006_PointChoc.js
import { LightningElement, track, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import POINTS_CHOC_FIELD from '@salesforce/schema/Claim__c.PointsDeChoc__c';
import PRECISIONS_FIELD from '@salesforce/schema/Claim__c.PrecisionsDommages__c';

export default class Lwc006_PointChoc extends LightningElement {
    @api recordId;

    // ✅ AJOUT : Propriétés @api pour recevoir les données du parent (mode wizard)
    @api
    get savedPoints() {
        return this._savedPoints;
    }
    set savedPoints(value) {
        this._savedPoints = value;
        // Restaurer les points dès que la valeur arrive
        if (value) {
            this._scheduleRestore();
        }
    }

    @api
    get savedPrecisions() {
        return this._savedPrecisions;
    }
    set savedPrecisions(value) {
        this._savedPrecisions = value;
    }

    _savedPoints = '';
    _savedPrecisions = '';
    _restoreScheduled = false;

    @track parts = [];
    @track motifVal = '';
    @track messageObligatoire = false;

    @api errorMessage = 'Veuillez sélectionner au moins un point de choc.';

    get isReadOnly() {
        return !!this.recordId;
    }

    // ✅ AJOUT : Restaurer après rendu
    renderedCallback() {
        if (this._restoreScheduled && !this._restored) {
            this._restored = true;
            this._restoreScheduled = false;
            this._doRestore();
        }
    }

    _scheduleRestore() {
        this._restored = false;
        this._restoreScheduled = true;
    }

    _doRestore() {
        const pointsStr = this._savedPoints;
        const precisions = this._savedPrecisions;

        if (!pointsStr) return;

        // Réinitialiser d'abord
        this.parts = [];

        const partiesEndommagees = pointsStr.split(';').map(p => p.trim()).filter(p => p !== '');

        partiesEndommagees.forEach(partval => {
            const myPartElement = this.template.querySelector(`path[data-value='${partval}']`);
            if (myPartElement) {
                myPartElement.style.fill = '#FF0000';
                myPartElement.style.fillOpacity = '0.6';
                this.parts.push({ id: myPartElement.id, val: partval });
            }
        });

        this.parts = [...this.parts];

        if (precisions) {
            this.motifVal = precisions;
        }

        this.updateLayout();
    }

    @wire(getRecord, { recordId: '$recordId', fields: [POINTS_CHOC_FIELD, PRECISIONS_FIELD] })
    wiredClaim({ error, data }) {
        if (data) {
            const pointsSauvegardes = getFieldValue(data, POINTS_CHOC_FIELD);
            const precisionsSauvegardees = getFieldValue(data, PRECISIONS_FIELD);

            if (precisionsSauvegardees) {
                this.motifVal = precisionsSauvegardees;
            }
            if (pointsSauvegardes) {
                this.colorierPointsExistants(pointsSauvegardes);
            }
        } else if (error) {
            console.error('Erreur lors de la récupération des points de choc', error);
        }
    }

    colorierPointsExistants(pointsStr) {
        const partiesEndommagees = pointsStr.split(';').map(p => p.trim()).filter(p => p !== '');
        setTimeout(() => {
            partiesEndommagees.forEach(partval => {
                const myPartElement = this.template.querySelector(`path[data-value='${partval}']`);
                if (myPartElement) {
                    myPartElement.style.fill = '#FF0000';
                    myPartElement.style.fillOpacity = '0.6';
                    this.parts.push({ id: myPartElement.id, val: partval });
                }
            });
            this.parts = [...this.parts];
            this.updateLayout();
        }, 500);
    }

    onclickPart(event) {
        if (this.isReadOnly) return;

        try {
            const type = event.target.getAttribute('data-type');
            const partval = event.target.getAttribute('data-value');
            let partId;

            if (type === 'div') {
                const myPartElement = this.template.querySelector(`path[data-value='${partval}']`);
                partId = myPartElement ? myPartElement.id : null;
            } else {
                partId = event.target.id;
            }

            if (!partId) return;

            const partDom = this.template.querySelector(`#${partId}`);
            const index = this.parts.findIndex(p => p.id === partId);

            if (index > -1) {
                partDom.style.fill = '';
                partDom.style.fillOpacity = '0';
                this.parts.splice(index, 1);
            } else {
                partDom.style.fill = '#FF0000';
                partDom.style.fillOpacity = '0.6';
                this.parts.push({ id: partId, val: partval });
            }

            this.parts = [...this.parts];
            this.updateLayout();
            this.notifyChange();

        } catch (e) {
            console.error('Erreur dans onclickPart:', e.message);
        }
    }

    handleMotifChange(event) {
        if (this.isReadOnly) return;
        this.motifVal = event.target.value;
        this.notifyChange();
    }

    updateLayout() {
        const hasParts = this.parts.length > 0;
        const car = this.template.querySelector('.my-car-container');
        const details = this.template.querySelector('.my-details-container');

        if (car && details) {
            if (hasParts) {
                car.classList.remove('car-initial');
                car.classList.add('car-with-details');
                details.classList.remove('details-empty');
                details.classList.add('details-not-empty');
            } else {
                car.classList.add('car-initial');
                car.classList.remove('car-with-details');
                details.classList.add('details-empty');
                details.classList.remove('details-not-empty');
            }
        }
    }

    notifyChange() {
        const selectedPartsString = this.parts.map(p => p.val).join(';');
        this.dispatchEvent(new CustomEvent('pointchocchange', {
            detail: {
                clickedParts: selectedPartsString,
                precisionDommage: this.motifVal
            }
        }));
    }

    @api
    checkValidity() {
        if (this.isReadOnly) return true;
        this.messageObligatoire = (this.parts.length === 0);
        return !this.messageObligatoire;
    }
}