public with sharing class DA_CaseCoverageController {

    private static final String RC_CODE = '001';

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getCaseCoveragesCatalog(Id caseId) {
        try {
            if (caseId == null) return new List<Map<String, Object>>();

            Case caseRec = DM_Case.getById('Id, Police__c', caseId);
            Id policyId = caseRec == null ? null : caseRec.Police__c;

            List<InsurancePolicyCoverage__c> policyCoverages = new List<InsurancePolicyCoverage__c>();
            if (policyId != null) {
                policyCoverages = DM008_InsurancePolicyCoverage.getByPolicyId(
                    'Id, CodeGarantie__c, NomDeLaGarantie__c, TypeGarantie__c, GarantieUsed__c',
                    policyId
                );
            }

            Set<String> selectedCodes = new Set<String>();
            for (CaseCoverage__c cc : DM009_CaseCoverage.getByCaseId('Id, CodeGarantie__c', caseId)) {
                if (cc.CodeGarantie__c != null) selectedCodes.add(cc.CodeGarantie__c);
            }

            Map<String, Object> rcEntry = null;
            List<Map<String, Object>> selected = new List<Map<String, Object>>();
            List<Map<String, Object>> unselected = new List<Map<String, Object>>();
            for (InsurancePolicyCoverage__c pc : policyCoverages) {
                if (pc.GarantieUsed__c != true) continue;
                Boolean isUsed = selectedCodes.contains(pc.CodeGarantie__c) || pc.CodeGarantie__c == RC_CODE;
                Map<String, Object> entry = new Map<String, Object>{
                    'Id'                 => pc.Id,
                    'CodeGarantie__c'    => pc.CodeGarantie__c,
                    'NomDeLaGarantie__c' => pc.NomDeLaGarantie__c,
                    'TypeGarantie__c'    => pc.TypeGarantie__c,
                    'GarantieUsed__c'    => isUsed
                };
                if (pc.CodeGarantie__c == RC_CODE) {
                    rcEntry = entry;
                } else if (isUsed) {
                    selected.add(entry);
                } else {
                    unselected.add(entry);
                }
            }

            List<Map<String, Object>> result = new List<Map<String, Object>>();
            if (rcEntry != null) result.add(rcEntry);
            result.addAll(selected);
            result.addAll(unselected);
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Erreur lors du chargement des garanties : ' + e.getMessage()
            );
        }
    }

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