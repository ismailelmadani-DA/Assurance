public with sharing class DA_RIBController {

    private static final String FIELDS =
        'Id, Name, RIB__c, CodeBanque__c, Actif__c, Statut__c';

    @AuraEnabled(cacheable=true)
    public static List<RIB__c> getRIBsByAccountId(Id accountId) {
        return DM004_RIB.getByAccountId(FIELDS, accountId);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getBanqueLabels() {
        Map<String, String> labels = new Map<String, String>();
        for (Schema.PicklistEntry p : RIB__c.CodeBanque__c.getDescribe().getPicklistValues()) {
            labels.put(p.getValue(), p.getLabel());
        }
        return labels;
    }
}