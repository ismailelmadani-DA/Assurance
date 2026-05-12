public with sharing class EM009_CaseCoverage {

    public static void insertCoverages(List<CaseCoverage__c> coverages) {
        if (coverages != null && !coverages.isEmpty()) {
            insert coverages;
        }
    }

    public static void deleteCoverages(List<CaseCoverage__c> coverages) {
        if (coverages != null && !coverages.isEmpty()) {
            delete coverages;
        }
    }
}
