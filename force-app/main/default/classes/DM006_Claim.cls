public with sharing class DM006_Claim {

    private static final String OBJ = 'Claim__c';

    private static final String FIELDS =
        'Id, Name, Flags__c, Case__c, CreatedDate';

    public static Claim__c getById(String fields, Id claimId) {
        String queryFields = String.isNotBlank(fields) ? fields : FIELDS;
        return (Claim__c) DA_Utility.getById(queryFields, OBJ, claimId);
    }

    public static void updateClaim(Claim__c claim) {
        update claim;
    }
}