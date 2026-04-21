public with sharing class DA_PassagerController {

    private static final String CLASS_NAME = DA_PassagerController.class.getName();

    /**
     * @description      :   Récupère la liste des passagers assurés liés à un dossier
     * @method Name      :   getPassengers
     * @Author           :   D&A Technologies
     * @date             :   2026-04-20
     * @param caseId     :   Identifiant du dossier
     * @return           :   List<Passager__c>
     * -------------------------------------------------------------------------------------------------
     **/
    @AuraEnabled(cacheable=true)
    public static List<Passager__c> getPassengers(Id caseId) {
        System.debug(CLASS_NAME + ' - Start method getPassengers');

        try {
            List<Passager__c> result = DA_PassagerAssureService.getPassengers(caseId);
            System.debug(CLASS_NAME + ' - End method getPassengers');
            return result;
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lors du chargement des passagers assurés.');
        }
    }
}