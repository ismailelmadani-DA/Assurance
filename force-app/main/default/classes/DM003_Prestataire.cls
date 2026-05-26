public with sharing class DM003_Prestataire {

    private static final String PRESTATAIRE_RT_DEV_NAME = 'Prestataire';

    public static Id getPrestataireRTId() {
        return DA_Utility.getRecordTypeId('Account', PRESTATAIRE_RT_DEV_NAME);
    }

    public static List<Account> getPrestataires(String typeFilter, String searchTerm) {
        Id rtId = getPrestataireRTId();

        String fields     = 'Id, Name, codeTier__c, TypeDePrestataire__c, Phone, Email__c, Ville__c, Adresse__c, Pays__c, RecordTypeId';
        String conditions = 'RecordTypeId = \'' + String.escapeSingleQuotes(String.valueOf(rtId)) + '\'';

        if (String.isNotBlank(typeFilter)) {
            conditions += ' AND TypeDePrestataire__c = \'' + String.escapeSingleQuotes(typeFilter) + '\'';
        }
        if (String.isNotBlank(searchTerm)) {
            String safeSearch = '%' + String.escapeSingleQuotes(searchTerm) + '%';
            conditions += ' AND ('
                + 'Name LIKE \'' + safeSearch + '\''
                + ' OR codeTier__c LIKE \'' + safeSearch + '\''
                + ' OR TypeDePrestataire__c LIKE \'' + safeSearch + '\''
                + ' OR Phone LIKE \'' + safeSearch + '\''
                + ' OR Ville__c LIKE \'' + safeSearch + '\''
                + ')';
        }

        return (List<Account>) DA_Utility.query(fields, 'Account', conditions, 'CreatedDate DESC', 200);
    }

    public static List<RIB__c> getRibsByAccountIds(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) return new List<RIB__c>();

        List<String> idList = new List<String>();
        for (Id accId : accountIds) idList.add('\'' + accId + '\'');
        String formattedIds = String.join(idList, ',');

        String fields     = 'Id, ParticipantAccount__c, CodeBanque__c, RIB__c, Statut__c, Actif__c';
        String conditions = 'ParticipantAccount__c IN (' + formattedIds + ')';

        return (List<RIB__c>) DA_Utility.query(fields, 'RIB__c', conditions, 'Actif__c DESC, CreatedDate DESC', 1000);
    }

    public static Integer countPrestatairesByType(String type) {
        Id rtId = getPrestataireRTId();
        return DA_Utility.count('Account',
            'TypeDePrestataire__c = \'' + String.escapeSingleQuotes(type) + '\''
            + ' AND RecordTypeId = \'' + String.escapeSingleQuotes(String.valueOf(rtId)) + '\''
        );
    }

    // ─── Picklists — délégation vers DA_Utility ──────────────────────────────

    public static List<Map<String, String>> getBanqueOptions() {
        return DA_Utility.getPicklistValues('RIB__c', 'CodeBanque__c');
    }

    public static List<Map<String, String>> getPaysOptions() {
        return DA_Utility.getPicklistValues('Account', 'Pays__c');
    }

    public static Map<String, List<Map<String, String>>> getDependentVilleOptions() {
        return DA_Utility.getDependentPicklistValues('Account', 'Pays__c', 'Ville__c');
    }
}