public with sharing class DM009_CaseCoverage {

    private static final String OBJ = 'CaseCoverage__c';
    private static final String FIELDS = 'Id, Name, CodeGarantie__c, Case__c';

    public static List<CaseCoverage__c> getByCaseId(String fields, Id caseId) {
        String queryFields = String.isNotBlank(fields) ? fields : FIELDS;
        String safeId = String.escapeSingleQuotes(String.valueOf(caseId));
        return (List<CaseCoverage__c>) DA_Utility.query(queryFields, OBJ, 'Case__c = \'' + safeId + '\'', 'CreatedDate DESC', null);
    }
}
