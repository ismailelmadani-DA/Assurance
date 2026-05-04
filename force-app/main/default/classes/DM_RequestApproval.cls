public with sharing class DM_RequestApproval {

    private static final String OBJ = 'RequestApproval__c';

    private static final String FIELDS =
        'Id, Name, Sinistre__c, Sinistre__r.Name, Status__c, ' +
        'TypeApprobation__c, Flag__c, Commentaire__c, ' +
        'Submitter__c, Submitter__r.Name, ' +
        'NextApprover__c, NextApprover__r.Name, CreatedDate';

    public static List<RequestApproval__c> getPendingByClaimId(Id claimId) {
        String safeId = String.escapeSingleQuotes(String.valueOf(claimId));
        String conditions = 'Sinistre__c = \'' + safeId + '\' AND Status__c = \'En attente d\\\'approbation\'';
        return (List<RequestApproval__c>) DA_Utility.query(FIELDS, OBJ, conditions, 'CreatedDate DESC', null);
    }
}