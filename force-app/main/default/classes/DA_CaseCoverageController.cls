public with sharing class DA_CaseCoverageController {

    @AuraEnabled(cacheable=false)
    public static List<CaseCoverage__c> getCaseCoverages(Id caseId) {
        if (caseId == null) return new List<CaseCoverage__c>();
        return DM009_CaseCoverage.getByCaseId(
            'Id, Name, CodeGarantie__c, Insurance_Policy_Coverage__c, Insurance_Policy_Coverage__r.TypeGarantie__c',
            caseId
        );
    }

    @AuraEnabled(cacheable=false)
    public static List<Id> getSelectedCoverageIds(Id caseId) {
        if (caseId == null) return new List<Id>();
        List<CaseCoverage__c> existing = DM009_CaseCoverage.getByCaseId(
            'Id, Insurance_Policy_Coverage__c', caseId
        );
        List<Id> result = new List<Id>();
        for (CaseCoverage__c cc : existing) {
            if (cc.Insurance_Policy_Coverage__c != null) {
                result.add(cc.Insurance_Policy_Coverage__c);
            }
        }
        return result;
    }

    @AuraEnabled
    public static void saveCaseCoverages(Id caseId, Id policyId, List<Id> selectedCoverageIds) {
        try {
            Set<Id> selectedSet = new Set<Id>(selectedCoverageIds == null ? new List<Id>() : selectedCoverageIds);

            List<CaseCoverage__c> existing = DM009_CaseCoverage.getByCaseId(
                'Id, Insurance_Policy_Coverage__c', caseId
            );

            Set<Id> alreadyLinked = new Set<Id>();
            List<CaseCoverage__c> toDelete = new List<CaseCoverage__c>();
            for (CaseCoverage__c cc : existing) {
                if (cc.Insurance_Policy_Coverage__c != null && selectedSet.contains(cc.Insurance_Policy_Coverage__c)) {
                    alreadyLinked.add(cc.Insurance_Policy_Coverage__c);
                } else {
                    toDelete.add(cc);
                }
            }

            Set<Id> toCreate = new Set<Id>(selectedSet);
            toCreate.removeAll(alreadyLinked);

            List<CaseCoverage__c> toInsert = new List<CaseCoverage__c>();
            if (!toCreate.isEmpty()) {
                List<InsurancePolicyCoverage__c> coverages = DM008_InsurancePolicyCoverage.getByPolicyId(
                    'Id, CodeGarantie__c, NomDeLaGarantie__c', policyId
                );
                for (InsurancePolicyCoverage__c cov : coverages) {
                    if (toCreate.contains(cov.Id)) {
                        toInsert.add(new CaseCoverage__c(
                            Case__c = caseId,
                            Name = cov.NomDeLaGarantie__c,
                            CodeGarantie__c = cov.CodeGarantie__c,
                            Insurance_Policy_Coverage__c = cov.Id
                        ));
                    }
                }
            }

            EM009_CaseCoverage.deleteCoverages(toDelete);
            EM009_CaseCoverage.insertCoverages(toInsert);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Erreur lors de la sauvegarde des garanties : ' + e.getMessage()
            );
        }
    }
}