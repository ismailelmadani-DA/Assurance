public with sharing class DM001_Passager {

    private static final String PASSENGER_OBJECT = 'Passager__c';

    private static final String PASSENGER_LIST_FIELDS =
        'Id, Civilite__c, Name, CIN__c, Pays__c, Ville__c, ' +
        'StateOfPerson__c, isDriver__c, Compte__c';

    public static List<Passager__c> getPassengersByCase(Id caseId, String role) {
        String conditions =
            'Case__c = \'' + String.escapeSingleQuotes(String.valueOf(caseId)) + '\'' +
            ' AND Roles__c = \'' + String.escapeSingleQuotes(role) + '\'';

        List<SObject> records = DA_Utility.query(
            PASSENGER_LIST_FIELDS,
            PASSENGER_OBJECT,
            conditions,
            'CreatedDate DESC',
            null
        );

        List<Passager__c> passengers = new List<Passager__c>();
        for (SObject record : records) {
            passengers.add((Passager__c) record);
        }
        return passengers;
    }
}