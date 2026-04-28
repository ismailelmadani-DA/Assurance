public with sharing class DM004_RIB {

    private static final String RIB_OBJECT = 'RIB__c';

    private static final String FIELDS =
        'Id, Name, RIB__c, CodeBanque__c, Actif__c, ' +
        'Statut__c, ParticipantAccount__c, ParticipantAccount__r.Name';

    public static List<RIB__c> getByAccountId(String fields, Id accountId) {
        String queryFields = String.isNotBlank(fields) ? fields : FIELDS;
        String conditions = 'ParticipantAccount__c = \'' + String.escapeSingleQuotes(String.valueOf(accountId)) + '\'';
        return (List<RIB__c>) DA_Utility.query(queryFields, RIB_OBJECT, conditions, 'CreatedDate DESC', null);
    }

    public static RIB__c getById(String fields, Id recordId) {
        String queryFields = String.isNotBlank(fields) ? fields : FIELDS;
        return (RIB__c) DA_Utility.getById(queryFields, RIB_OBJECT, recordId);
    }

    public static List<RIB__c> getOtherActiveByAccountId(Id currentRibId, Id accountId) {
        String conditions = 'ParticipantAccount__c = \'' + String.escapeSingleQuotes(String.valueOf(accountId)) + '\'' +
                            ' AND Actif__c = true AND Id != \'' + String.escapeSingleQuotes(String.valueOf(currentRibId)) + '\'';
        return (List<RIB__c>) DA_Utility.query(FIELDS, RIB_OBJECT, conditions, null, null);
    }

    public static List<Map<String, String>> getBanqueOptions() {
        List<Map<String, String>> opts = new List<Map<String, String>>();
        for (Schema.PicklistEntry entry : RIB__c.CodeBanque__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                opts.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }
        return opts;
    }
}