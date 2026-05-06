public with sharing class DM008_InsurancePolicyCoverage {

    private static final String OBJECT_NAME = 'InsurancePolicyCoverage__c';

    public static List<InsurancePolicyCoverage__c> getByPolicyId(String fields, Id policyId) {
        if (policyId == null) return new List<InsurancePolicyCoverage__c>();

        String safeId = String.escapeSingleQuotes(String.valueOf(policyId));
        String conditions = 'InsurancePolicy__c = \'' + safeId + '\'';
        String orderBy = 'CreatedDate ASC';

        return (List<InsurancePolicyCoverage__c>) DA_Utility.query(fields, OBJECT_NAME, conditions, orderBy, null);
    }

}