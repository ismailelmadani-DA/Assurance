public with sharing class DA_ClaimCoverageController {

    private static final String RC_CODE = '001';

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getClaimCoveragesCatalog(Id claimId) {
        try {
            List<GarantieAssurance__mdt> mdtList = DM010_GarantieAssurance.getActive();

            Map<String, ClaimCoverage__c> existingByCode = new Map<String, ClaimCoverage__c>();
            if (claimId != null) {
                for (ClaimCoverage__c c : [
                    SELECT Id, Name, CodeGarantie__c, Insurance_Policy_Coverage__c
                    FROM ClaimCoverage__c
                    WHERE Claim__c = :claimId
                ]) {
                    if (c.CodeGarantie__c != null) existingByCode.put(c.CodeGarantie__c, c);
                }
            }

            Map<String, Object> rcEntry = null;
            List<Map<String, Object>> selected = new List<Map<String, Object>>();
            List<Map<String, Object>> unselected = new List<Map<String, Object>>();
            for (GarantieAssurance__mdt g : mdtList) {
                ClaimCoverage__c match = existingByCode.get(g.CodeGarantie__c);
                Boolean isUsed = match != null || g.CodeGarantie__c == RC_CODE;
                Map<String, Object> entry = new Map<String, Object>{
                    'Id'                 => match != null ? (Object) match.Id : (Object) g.CodeGarantie__c,
                    'CodeGarantie__c'    => g.CodeGarantie__c,
                    'NomDeLaGarantie__c' => g.MasterLabel,
                    'TypeGarantie__c'    => g.TypeGarantie__c,
                    'GarantieUsed__c'    => isUsed
                };
                if (g.CodeGarantie__c == RC_CODE) {
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

    @AuraEnabled
    public static void saveClaimCoverages(Id claimId, List<String> selectedCodes) {
        try {
            if (claimId == null) return;

            Map<String, GarantieAssurance__mdt> mdtByCode = DM010_GarantieAssurance.getActiveByCode();

            Map<String, ClaimCoverage__c> existingByCode = new Map<String, ClaimCoverage__c>();
            for (ClaimCoverage__c c : [
                SELECT Id, CodeGarantie__c
                FROM ClaimCoverage__c
                WHERE Claim__c = :claimId
            ]) {
                if (c.CodeGarantie__c != null) existingByCode.put(c.CodeGarantie__c, c);
            }

            Set<String> selectedSet = new Set<String>(selectedCodes == null ? new List<String>() : selectedCodes);
            selectedSet.add(RC_CODE);

            List<ClaimCoverage__c> toInsert = new List<ClaimCoverage__c>();
            List<ClaimCoverage__c> toDelete = new List<ClaimCoverage__c>();

            for (String code : mdtByCode.keySet()) {
                Boolean shouldBeChecked = selectedSet.contains(code);
                ClaimCoverage__c rec = existingByCode.get(code);
                if (rec == null && shouldBeChecked) {
                    GarantieAssurance__mdt g = mdtByCode.get(code);
                    toInsert.add(new ClaimCoverage__c(
                        Claim__c        = claimId,
                        Name            = g.MasterLabel,
                        CodeGarantie__c = code
                    ));
                } else if (rec != null && !shouldBeChecked) {
                    toDelete.add(rec);
                }
            }

            EM010_ClaimCoverage.deleteCoverages(toDelete);
            EM010_ClaimCoverage.insertCoverages(toInsert);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Erreur lors de la sauvegarde des garanties : ' + e.getMessage()
            );
        }
    }
}