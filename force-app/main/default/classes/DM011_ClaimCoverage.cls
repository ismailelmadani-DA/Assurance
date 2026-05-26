public with sharing class DM011_ClaimCoverage {

    private static final String OBJ = 'ClaimCoverage__c';
    private static final String FIELDS =
        'Id, Name, CodeGarantie__c, Claim__c, Insurance_Policy_Coverage__c';

    public static List<ClaimCoverage__c> getByClaimId(String fields, Id claimId) {
        if (claimId == null) return new List<ClaimCoverage__c>();
        String queryFields = String.isNotBlank(fields) ? fields : FIELDS;
        String safeId = String.escapeSingleQuotes(String.valueOf(claimId));
        return (List<ClaimCoverage__c>) DA_Utility.query(
            queryFields, OBJ, 'Claim__c = \'' + safeId + '\'', 'CreatedDate DESC', null
        );
    }
}