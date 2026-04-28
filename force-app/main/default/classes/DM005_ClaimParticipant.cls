public with sharing class DM005_ClaimParticipant {

    private static final String CLAIM_PARTICIPANT = 'ClaimParticipant__c';

    private static final String FIELDS =
        'Id, Name, Claim__c, Claim__r.Name, ' +
        'ParticipantAccount__c, ParticipantAccount__r.Name, ' +
        'Roles__c, StateOfPerson__c, ' +
        'Vehicule__c, Vehicule__r.RegistrationNumber__c, ' +
        'BirthDay__c, Sexe__c, Civilite__c, ' +
        'ParticipantCNI__c, TypeContact__c, ' +
        'isDriver__c, isOwner__c, Passager__c';

    public static List<ClaimParticipant__c> getByClaimId(String fields, Id claimId) {
        String queryFields = String.isNotBlank(fields) ? fields : FIELDS;
        String conditions = 'Claim__c = \'' + String.escapeSingleQuotes(String.valueOf(claimId)) + '\'';
        return (List<ClaimParticipant__c>) DA_Utility.query(queryFields, CLAIM_PARTICIPANT, conditions, 'CreatedDate DESC', null);
    }

    public static List<ClaimParticipant__c> getByAccountId(String fields, Id accountId) {
        String queryFields = String.isNotBlank(fields) ? fields : FIELDS;
        String conditions = 'ParticipantAccount__c = \'' + String.escapeSingleQuotes(String.valueOf(accountId)) + '\'';
        return (List<ClaimParticipant__c>) DA_Utility.query(queryFields, CLAIM_PARTICIPANT, conditions, 'CreatedDate DESC', null);
    }

    public static List<ClaimParticipant__c> getByClaimAndRole(String fields, Id claimId, String role) {
        String queryFields = String.isNotBlank(fields) ? fields : FIELDS;
        String safeId = String.escapeSingleQuotes(String.valueOf(claimId));
        String safeRole = String.escapeSingleQuotes(role);
        String conditions = 'Claim__c = \'' + safeId + '\' AND Roles__c = \'' + safeRole + '\'';
        return (List<ClaimParticipant__c>) DA_Utility.query(queryFields, CLAIM_PARTICIPANT, conditions, 'CreatedDate DESC', null);
    }

    public static ClaimParticipant__c getById(String fields, Id recordId) {
        String queryFields = String.isNotBlank(fields) ? fields : FIELDS;
        return (ClaimParticipant__c) DA_Utility.getById(queryFields, CLAIM_PARTICIPANT, recordId);
    }
}