trigger RequestApprovalTrigger on RequestApproval__c (after insert, after update) {

    if (Trigger.isAfter && Trigger.isInsert) {
        for (RequestApproval__c ra : Trigger.new) {
            if (ra.TypeApprobation__c == 'Flag du sinistre'
                && ra.Status__c == 'En attente d\'approbation') {
                FlagSinistreNotifier.sendForRequest(ra);
            }
        }
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        for (RequestApproval__c ra : Trigger.new) {
            RequestApproval__c old = Trigger.oldMap.get(ra.Id);
            Boolean justDecided = old.Status__c == 'En attente d\'approbation'
                && (ra.Status__c == 'Approuvée' || ra.Status__c == 'Rejetée');
            if (justDecided && ra.TypeApprobation__c == 'Flag du sinistre') {
                RequestApprovalService.applyDecision(ra);
            }
        }
    }
}