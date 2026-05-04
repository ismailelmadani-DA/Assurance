public with sharing class EM_RequestApproval {

    public static RequestApproval__c createRequest(Id claimId, String flag, String commentaire, Id submitterId, Id approverId) {
        RequestApproval__c req = new RequestApproval__c();
        req.Sinistre__c = claimId;
        req.Flag__c = flag;
        req.Commentaire__c = commentaire;
        req.TypeApprobation__c = 'Flag du sinistre';
        req.Status__c = 'En attente d\'approbation';
        req.Submitter__c = submitterId;
        req.NextApprover__c = approverId;
        insert req;
        return req;
    }
}