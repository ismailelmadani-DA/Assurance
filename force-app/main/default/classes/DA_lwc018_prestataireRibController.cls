public with sharing class DA_lwc018_prestataireRibController {

    private static final String RIB_FIELDS =
        'Id, Name, RIB__c, CodeBanque__c, Actif__c, Statut__c, ParticipantAccount__c';

    @AuraEnabled(cacheable=true)
    public static List<RIB__c> getRibs(Id accountId) {    
        return DM004_RIB.getByAccountId(RIB_FIELDS, accountId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getBanqueOptions() {
            return DM004_RIB.getBanqueOptions();
    }
}