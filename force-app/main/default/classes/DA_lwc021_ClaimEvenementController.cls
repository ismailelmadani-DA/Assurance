public with sharing class DA_lwc021_ClaimEvenementController {

    /* ── LECTURE ─────────────────────────────────────────────────────── */

    @AuraEnabled(cacheable=false)
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

    @AuraEnabled(cacheable=false)
    public static Boolean isPopupEvenementVu(Id claimId) {
        if (claimId == null) return true;
        try {
            return DM006_Evenement.isPopupEvenementVu(claimId);
        } catch (Exception e) {
            System.debug('Erreur isPopupEvenementVu : ' + e.getMessage());
            return true;
        }
    }

    /* ── ÉCRITURE ────────────────────────────────────────────────────── */

    @AuraEnabled
    public static void associerEvenement(Id claimId, Id evenementId) {
        if (claimId     == null) throw new AuraHandledException('L\'identifiant du sinistre est requis.');
        if (evenementId == null) throw new AuraHandledException('L\'identifiant de l\'événement est requis.');
        try {
            EM006_Evenement.associerEvenement(claimId, evenementId);
        } catch (AuraHandledException ae) { throw ae; }
          catch (Exception e)            { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled
    public static void marquerPopupVu(Id claimId) {
        if (claimId == null) throw new AuraHandledException('L\'identifiant du sinistre est requis.');
        try {
            EM006_Evenement.marquerPopupVu(claimId);
        } catch (AuraHandledException ae) { throw ae; }
          catch (Exception e)            { throw new AuraHandledException(e.getMessage()); }
    }
}