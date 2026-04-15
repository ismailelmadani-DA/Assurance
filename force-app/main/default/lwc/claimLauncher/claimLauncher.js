import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class ClaimLauncher extends NavigationMixin(LightningElement) {
    handleLaunch() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                // Utilise le Tab Name exact de ta capture
                apiName: 'Creation_Declaration' 
            }
        });
    }
}