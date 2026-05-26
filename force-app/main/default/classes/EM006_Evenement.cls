public with sharing class EM006_Evenement {

    public static void upsertEvenement(Evenement__c evt) {
        upsert evt;
    }

    public static void deleteEvenement(Id recordId) {
        DA_Utility.deleteById('Evenement__c', recordId);
    }

    public static void associerEvenement(Id claimId, Id evenementId) {
        update new Claim__c(
            Id                  = claimId,
            EvenementAssocie__c = evenementId,
            PopupEvenementVu__c = true
        );
    }

    public static void marquerPopupVu(Id claimId) {
        update new Claim__c(
            Id                  = claimId,
            PopupEvenementVu__c = true
        );
    }
}