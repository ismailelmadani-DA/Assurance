public with sharing class DA_LWC008_ListPassagerAdverseController  {

    private static String friendlyError(Exception e) {
        String msg = e.getMessage();
        if (msg == null)                         return 'Une erreur inattendue s\'est produite.';
        if (msg.contains('INSUFFICIENT_ACCESS')) return 'Vous n\'avez pas les droits nécessaires pour effectuer cette action.';
        return 'Une erreur est survenue lors du traitement. Veuillez réessayer.';
    }

   @AuraEnabled(cacheable=true)
    public static List<SObject> getPassagersAdverses(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('L\'identifiant de la déclaration est requis.');
        }
        try {
            return DM001_Passager.getPassagersAdversesByCase(caseId); // ← DM commun
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException(friendlyError(e));
        }
    }
}