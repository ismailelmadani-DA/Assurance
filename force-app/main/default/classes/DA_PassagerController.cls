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

    @AuraEnabled(cacheable=true)
    public static List<Passager__c> getPassagersAutresPartie(Id caseId) {
        System.debug(CLASS_NAME + ' - Start method getPassagersAutresPartie');
        try {
            List<Passager__c> result = SM001_PassagerService.getPassagersAutresPartie(caseId);
            System.debug(CLASS_NAME + ' - End method getPassagersAutresPartie');
            return result;
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lors du chargement des passagers autres partie.');
        }
    }

    @AuraEnabled
    public static void deletePassager(Id passagerId) {
        System.debug(CLASS_NAME + ' - Start method deletePassager');
        try {
            SM001_PassagerService.deletePassager(passagerId);
            System.debug(CLASS_NAME + ' - End method deletePassager');
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lors de la suppression du passager.');
        }
    }

    @AuraEnabled
    public static Id resolveAccountByCIN(String cin, String nom) {
        System.debug(CLASS_NAME + ' - Start method resolveAccountByCIN');
        try {
            Id result = SM001_PassagerService.resolveAccountByCIN(cin, nom);
            System.debug(CLASS_NAME + ' - End method resolveAccountByCIN');
            return result;
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lors de la résolution du compte par CIN.');
        }
    }
}