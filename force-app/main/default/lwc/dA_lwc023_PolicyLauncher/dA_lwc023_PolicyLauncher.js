import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class DA_lwc023_PolicyLauncher extends NavigationMixin(LightningElement) {
    handleLaunch() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Creation_Police' // ← nom API de ta App Page à créer
            }
        });
    }
}