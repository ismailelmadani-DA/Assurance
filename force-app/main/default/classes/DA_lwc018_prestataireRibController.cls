public with sharing class DA_lwc018_prestataireRibController {

    private static final String RIB_FIELDS =
        'Id, Name, RIB__c, CodeBanque__c, Actif__c, Statut__c, ParticipantAccount__c';

    @AuraEnabled(cacheable=true)
    public static List<RIB__c> getRibs(Id accountId) {
        if (accountId == null) return new List<RIB__c>();
        try {
            return DM004_RIB.getByAccountId(RIB_FIELDS, accountId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getBanqueOptions() {
        try {
            return DM004_RIB.getBanqueOptions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}