public with sharing class DA_GarantieController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getGaranties() {
        try {
            return DM_Garantie.getGaranties();
        } catch (Exception e) {
            throw new AuraHandledException(
                'Erreur lors du chargement des garanties : ' + e.getMessage()
            );
        }
    }

    @AuraEnabled
    public static void saveGarantie(String record) {
        try {
            EM_Garantie.saveGarantie(record);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Erreur lors de l’enregistrement de la garantie : ' + e.getMessage()
            );
        }
    }
}