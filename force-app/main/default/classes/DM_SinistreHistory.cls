public with sharing class DM_SinistreHistory {

    private static final String CLAIM_PARTICIPANT = 'ClaimParticipant__c';

    private static final String FIELDS =
        'Id, Claim__c, Claim__r.Name, ' +
        'Vehicule__c, Vehicule__r.RegistrationNumber__c, ' +
        'Roles__c, StateOfPerson__c';

    public static List<Map<String, Object>> getHistoriques(Id accountId) {
        String conditions = 'ParticipantAccount__c = \'' + String.escapeSingleQuotes(String.valueOf(accountId)) + '\'';
        List<SObject> records = DM_DataManager.query(FIELDS, CLAIM_PARTICIPANT, conditions, 'CreatedDate DESC', null);

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (SObject rec : records) {
            ClaimParticipant__c cp = (ClaimParticipant__c) rec;
            Map<String, Object> row = new Map<String, Object>();
            row.put('id', cp.Id);
            row.put('claimId', cp.Claim__c);
            row.put('claimNumber', cp.Claim__r != null ? cp.Claim__r.Name : '');
            row.put('vehiculeId', cp.Vehicule__c);
            row.put('immatriculation', cp.Vehicule__r != null ? cp.Vehicule__r.RegistrationNumber__c : '');
            row.put('type', cp.Roles__c);
            row.put('etat', cp.StateOfPerson__c);
            result.add(row);
        }
        return result;
    }
}
