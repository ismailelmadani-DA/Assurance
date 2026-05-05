/**
 * DA_lwc021_ClaimEvenementController
 * Façade AuraEnabled — délègue à DM006 (lecture) et EM006 (écriture).
 */
public with sharing class DA_lwc021_ClaimEvenementController {

    @AuraEnabled(cacheable=true)
    public static List<Evenement__c> getMatchingEvenements(Id claimId) {
        if (claimId == null) throw new AuraHandledException('L\'identifiant du sinistre est requis.');
        try {
            return DM006_Evenement.getMatchingEvenementsForClaim(claimId);
        } catch (AuraHandledException ae) { throw ae; }
          catch (Exception e)            { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled(cacheable=false)
    public static Evenement__c getEvenementAssocie(Id claimId) {
        if (claimId == null) throw new AuraHandledException('L\'identifiant du sinistre est requis.');
        try {
            return DM006_Evenement.getEvenementAssocie(claimId);
        } catch (AuraHandledException ae) { throw ae; }
          catch (Exception e)            { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled
    public static Map<String, Object> associerEvenement(Id claimId, Id evenementId) {
        if (claimId     == null) return errorResponse('L\'identifiant du sinistre est requis.');
        if (evenementId == null) return errorResponse('L\'identifiant de l\'événement est requis.');
        try {
            return EM006_Evenement.associerEvenement(claimId, evenementId);
        } catch (AuraHandledException ae) { throw ae; }
          catch (Exception e)            { return errorResponse(e.getMessage()); }
    }

    private static Map<String, Object> errorResponse(String message) {
        return new Map<String, Object>{ 'success' => false, 'message' => message };
    }
}