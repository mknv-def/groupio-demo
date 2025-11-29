// communityUserContext.js
import { LightningElement, wire, track } from 'lwc';
import getCurrentUserContext from '@salesforce/apex/CommunityUserContext.getCurrentUserContext';
import Id from '@salesforce/user/Id';

export default class CommunityUserContext extends LightningElement {
    @track userId = Id;
    @track userContext;
    @track error;

    @wire(getCurrentUserContext)
    wiredContext({ error, data }) {
        if (data) {
            this.userContext = data;
            this.error = undefined;

            console.log('Current User:', data.currentUser);
            console.log('Contact:', data.contact);
            console.log('Account:', data.account);
        } else if (error) {
            this.error = error;
            this.userContext = undefined;
        }
    }

    get accountId() {
        return this.userContext?.account?.Id;
    }

    get accountName() {
        return this.userContext?.account?.Name;
    }

    get contactId() {
        return this.userContext?.contact?.Id;
    }

    get contactName() {
        return this.userContext?.contact?.Name;
    }
}