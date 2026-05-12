public with sharing class EM010_ClaimCoverage {

    public static void insertCoverages(List<ClaimCoverage__c> coverages) {
        if (coverages != null && !coverages.isEmpty()) {
            insert coverages;
        }
    }

    public static void deleteCoverages(List<ClaimCoverage__c> coverages) {
        if (coverages != null && !coverages.isEmpty()) {
            delete coverages;
        }
    }
}
