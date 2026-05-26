/**
 * @description       : Controller de gestion de l'association événement/sinistre
 * @author            : D&A Technologies
 * @group             : Controller
 * @last modified on  : 25-05-2026
 */
public with sharing class DA_lwc021_ClaimEvenementController {

    /* ── LECTURE ─────────────────────────────────────────────────────── */

    @AuraEnabled(cacheable=false)
    public static List<Evenement__c> getMatchingEvenements(Id claimId) {
        if (claimId == null) throw new AuraHandledException('L\'identifiant du sinistre est requis.');
        try {
            return DM006_Evenement.getMatchingEvenementsForClaim(claimId);
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled(cacheable=false)
    public static Evenement__c getEvenementAssocie(Id claimId) {
        if (claimId == null) throw new AuraHandledException('L\'identifiant du sinistre est requis.');
        try {
            return DM006_Evenement.getEvenementAssocie(claimId);
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
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
        if (!Schema.sObjectType.Claim__c.isUpdateable()) {
            throw new AuraHandledException('Vous n\'avez pas les droits pour modifier ce sinistre.');
        }
        try {
            EM006_Evenement.associerEvenement(claimId, evenementId);
        } catch (AuraHandledException ae) { throw ae; }
          catch (DmlException e)          { throw new AuraHandledException(handleDmlException(e)); }
          catch (Exception e)             { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled
    public static void marquerPopupVu(Id claimId) {
        if (claimId == null) throw new AuraHandledException('L\'identifiant du sinistre est requis.');
        if (!Schema.sObjectType.Claim__c.isUpdateable()) {
            throw new AuraHandledException('Droits insuffisants pour modifier le sinistre.');
        }
        try {
            EM006_Evenement.marquerPopupVu(claimId);
        } catch (AuraHandledException ae) { throw ae; }
          catch (DmlException e)          { throw new AuraHandledException(handleDmlException(e)); }
          catch (Exception e)             { throw new AuraHandledException(e.getMessage()); }
    }

    /* ── PRIVÉ ───────────────────────────────────────────────────────── */

    private static String handleDmlException(Exception e) {
        String msg = e.getMessage();
        if (msg == null)                                 return 'Une erreur inattendue s\'est produite.';
        if (msg.contains('INSUFFICIENT_ACCESS'))         return 'Vous n\'avez pas les droits nécessaires pour effectuer cette action.';
        if (msg.contains('INVALID_CROSS_REFERENCE_KEY')
         || msg.contains('id value of incorrect type'))  return 'Référence invalide : vérifiez que le sinistre et l\'événement sont correctement configurés.';
        if (msg.contains('ENTITY_IS_DELETED'))           return 'L\'enregistrement a déjà été supprimé.';
        if (msg.contains('REQUIRED_FIELD_MISSING'))      return 'Un ou plusieurs champs obligatoires ne sont pas renseignés.';
        return 'Une erreur est survenue lors du traitement. Veuillez réessayer. ' + msg;
    }
}