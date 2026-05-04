public with sharing class RequestApprovalService {

    public static void applyDecision(RequestApproval__c ra) {
        if (ra.Sinistre__c == null || ra.Flag__c == null || ra.Status__c != 'Approuvée') {
            return;
        }

        Claim__c claim = DM006_Claim.getById('Id, Flags__c', ra.Sinistre__c);
        if (claim == null) return;

        Set<String> flags = new Set<String>();
        if (String.isNotBlank(claim.Flags__c)) {
            for (String f : claim.Flags__c.split(';')) {
                flags.add(f.trim());
            }
        }

        if (flags.contains(ra.Flag__c)) {
            flags.remove(ra.Flag__c);
        } else {
            if (ra.Flag__c == 'Frauduleux') flags.remove('Douteux');
            if (ra.Flag__c == 'Douteux') flags.remove('Frauduleux');
            flags.add(ra.Flag__c);
        }

        claim.Flags__c = flags.isEmpty() ? null : String.join(new List<String>(flags), ';');
        update claim;
    }
}