public with sharing class EM003_Prestataire {

    public static void upsertPrestataire(Account acc, RIB__c rib) {
        upsert acc;
        if (rib != null) {
            rib.ParticipantAccount__c = acc.Id;
            upsert rib;
        }
    }
}