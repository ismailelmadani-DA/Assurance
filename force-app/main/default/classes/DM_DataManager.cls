public with sharing class DM_DataManager {

    private static final String CLASS_NAME = DM_DataManager.class.getName();

    public static List<SObject> query(String fields, String sObjectName, String conditions, String orderBy, Integer limitCount) {
        String soql = 'SELECT ' + fields + ' FROM ' + sObjectName;

        if (String.isNotBlank(conditions)) {
            soql += ' WHERE ' + conditions;
        }
        if (String.isNotBlank(orderBy)) {
            soql += ' ORDER BY ' + orderBy;
        }
        if (limitCount != null && limitCount > 0) {
            soql += ' LIMIT ' + limitCount;
        }

        return Database.query(soql);
    }

    public static SObject getById(String fields, String sObjectName, Id recordId) {
        String conditions = 'Id = \'' + String.escapeSingleQuotes(String.valueOf(recordId)) + '\'';
        List<SObject> results = query(fields, sObjectName, conditions, null, 1);
        return results.isEmpty() ? null : results[0];
    }

    public static void deleteById(String sObjectName, Id recordId) {
        SObject record = Schema.getGlobalDescribe().get(sObjectName).newSObject(recordId);
        delete record;
    }
}