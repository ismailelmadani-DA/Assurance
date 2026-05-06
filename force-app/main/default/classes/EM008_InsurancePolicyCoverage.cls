public with sharing class EM008_InsurancePolicyCoverage {

    public static void updateCoverages(List<InsurancePolicyCoverage__c> coverages) {
        if (!coverages.isEmpty()) {
            update coverages;
        }
    }
}