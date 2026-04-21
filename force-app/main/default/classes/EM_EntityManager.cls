public with sharing class EM_EntityManager {

    public static SObject insertRecord(SObject record) {
        insert record;
        return record;
    }

    public static List<SObject> insertRecords(List<SObject> records) {
        insert records;
        return records;
    }

    public static SObject updateRecord(SObject record) {
        update record;
        return record;
    }

    public static List<SObject> updateRecords(List<SObject> records) {
        update records;
        return records;
    }

    public static SObject upsertRecord(SObject record) {
        upsert record;
        return record;
    }

    public static List<SObject> upsertRecords(List<SObject> records) {
        upsert records;
        return records;
    }

    public static void deleteRecord(SObject record) {
        delete record;
    }

    public static void deleteRecords(List<SObject> records) {
        delete records;
    }

    public static void deleteById(String sObjectName, Id recordId) {
        SObject record = Schema.getGlobalDescribe().get(sObjectName).newSObject(recordId);
        delete record;
    }

    public static void deleteByIds(String sObjectName, List<Id> recordIds) {
        List<SObject> records = new List<SObject>();
        Schema.SObjectType sType = Schema.getGlobalDescribe().get(sObjectName);
        for (Id recId : recordIds) {
            records.add(sType.newSObject(recId));
        }
        delete records;
    }
}