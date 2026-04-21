public with sharing class DM_DataManager {

    private static final String CLASS_NAME = DM_DataManager.class.getName();

    public static List<SObject> query(String fields, String sObjectName, String conditions, String orderBy, Integer limitCount) {
        return DA_Utility.query(fields, sObjectName, conditions, orderBy, limitCount);
    }

    public static SObject getById(String fields, String sObjectName, Id recordId) {
        String conditions = 'Id = \'' + String.escapeSingleQuotes(String.valueOf(recordId)) + '\'';
        List<SObject> results = query(fields, sObjectName, conditions, null, 1);
        return results.isEmpty() ? null : results[0];
    }

    public static void deleteById(String sObjectName, Id recordId) {
        EM_EntityManager.deleteById(sObjectName, recordId);
    }

    public static List<SObject> search(String fields, String sObjectName, String searchField, String searchTerm, String extraConditions, Integer limitCount) {
        return DA_Utility.search(fields, sObjectName, searchField, searchTerm, extraConditions, limitCount);
    }
}