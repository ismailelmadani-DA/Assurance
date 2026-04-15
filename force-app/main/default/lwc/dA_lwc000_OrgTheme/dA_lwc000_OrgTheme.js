import { LightningElement } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import WAFA_RESOURCE from '@salesforce/resourceUrl/OrgTheme';

export default class DA_lwc000_OrgTheme extends LightningElement {
    connectedCallback() {
        loadStyle(this, WAFA_RESOURCE)
            .then(() => {
                console.log('Org Theme Loaded Successfully');
            })
            .catch(error => {
                console.error('Error loading Org Theme', error);
            });
    }
}