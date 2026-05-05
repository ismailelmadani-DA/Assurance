public with sharing class PoliceSinistresController {

    /**
     * @description  : Retourne les sinistres d'une police sous forme de Map pour le LWC
     * @param        : policyId => Id de la police
     * @return       : List<Map<String, Object>>
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getSinistresByPolice(Id policyId) {
        if (policyId == null) {
            return new List<Map<String, Object>>();
        }

        try {
            List<Claim__c> claims = DM006_Claim.getClaimsByPolicyId(policyId);
            return mapClaims(claims);

        } catch (Exception e) {
            throw new AuraHandledException(
                'Erreur lors de la récupération des sinistres : ' + e.getMessage()
            );
        }
    }

    // ─── Private Helpers ────────────────────────────────────────────────────────

    private static List<Map<String, Object>> mapClaims(List<Claim__c> claims) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Claim__c c : claims) {
            result.add(toMap(c));
        }
        return result;
    }

    private static Map<String, Object> toMap(Claim__c c) {
        return new Map<String, Object>{
            'id'              => c.Id,
            'claimNumber'     => c.Name,
            'vehiculeId'      => c.Vehicule__c,
            'immatriculation' => resolveImmatriculation(c),
            'dateSurvenance'  => c.DateOfOccurrence__c,
            'lieuSurvenance'  => resolveLieu(c),
            'statut'          => c.Status__c,
            'createdById'     => c.CreatedById,
            'createdByName'   => (c.CreatedBy != null) ? c.CreatedBy.Name : null
        };
    }

    private static String resolveImmatriculation(Claim__c c) {
        return (c.Vehicule__r != null && String.isNotBlank(c.Vehicule__r.RegistrationNumber__c))
            ? c.Vehicule__r.RegistrationNumber__c
            : c.RegistrationNumber__c;
    }

    private static String resolveLieu(Claim__c c) {
        if (c.Case__r == null) return '';

        String pays  = c.Case__r.CountryOfOccurrence__c;
        String ville = c.Case__r.CityOfOccurrence__c;

        if (String.isNotBlank(pays) && String.isNotBlank(ville)) return pays + ', ' + ville;
        if (String.isNotBlank(pays))  return pays;
        if (String.isNotBlank(ville)) return ville;
        return '';
    }
}