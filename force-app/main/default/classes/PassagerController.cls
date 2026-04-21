public with sharing class PassagerController {

    private static final String CLASS_NAME = PassagerController.class.getName();

    @AuraEnabled(cacheable=true)
    public static List<Passager__c> getPassagersAutresPartie(Id caseId) {
        System.debug(CLASS_NAME + ' - Start method getPassagersAutresPartie');
        try {
            return SM001_PassagerService.getPassagersAutresPartie(caseId);
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deletePassager(Id passagerId) {
        System.debug(CLASS_NAME + ' - Start method deletePassager');
        try {
            SM001_PassagerService.deletePassager(passagerId);
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id resolveAccountByCIN(String cin, String nom) {
        try {
            return SM001_PassagerService.resolveAccountByCIN(cin, nom);
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}