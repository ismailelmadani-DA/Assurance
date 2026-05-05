public with sharing class DA_PassagerController {

    private static final String CLASS_NAME = DA_PassagerController.class.getName();
    private static final String ROLE_AUTRES_PARTIE = 'Autres partie';
    private static final String ROLE_PASSAGER_ADVERSE = 'Passager adverse';

    @AuraEnabled(cacheable=true)
    public static List<Passager__c> getPassengers(Id caseId) {
        System.debug(CLASS_NAME + ' - Start method getPassengers');
            List<Passager__c> result = DA_PassagerAssureService.getPassengers(caseId);
            System.debug(CLASS_NAME + ' - End method getPassengers');
            return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Passager__c> getPassagersAdverses(Id caseId) {
        System.debug(CLASS_NAME + ' - Start method getPassagersAdverses');
            List<Passager__c> result = DM001_Passager.getPassagersByCaseAndRole(caseId, ROLE_PASSAGER_ADVERSE);
            System.debug(CLASS_NAME + ' - End method getPassagersAdverses');
            return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Passager__c> getPassagersAutresPartie(Id caseId) {
        System.debug(CLASS_NAME + ' - Start method getPassagersAutresPartie');
            List<Passager__c> result = DM001_Passager.getPassagersByCaseAndRole(caseId, ROLE_AUTRES_PARTIE);
            System.debug(CLASS_NAME + ' - End method getPassagersAutresPartie');
            return result;
    }

    @AuraEnabled
    public static void deletePassager(Id passagerId) {
        System.debug(CLASS_NAME + ' - Start method deletePassager');
        try {
            if (passagerId == null) {
                throw new AuraHandledException('L\'identifiant du participant est requis.');
            }
            EM001_Passager.deletePassagerById(passagerId);
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
            if (String.isBlank(cin)) {
                throw new AuraHandledException('Le CIN est obligatoire.');
            }

            String conditions = 'CIN__c = \'' + String.escapeSingleQuotes(cin) + '\'';
            List<Account> existing = (List<Account>) DA_Utility.query('Id', 'Account', conditions, null, 1);

            if (!existing.isEmpty()) {
                System.debug(CLASS_NAME + ' - End method resolveAccountByCIN');
                return existing[0].Id;
            }

            SObject newAcc = DA_Utility.addByRecordType('Account', 'Passager', new Map<String, Object>{
                'Name' => nom != null ? nom.trim() : cin,
                'CIN__c' => cin
            });
            System.debug(CLASS_NAME + ' - End method resolveAccountByCIN');
            return newAcc.Id;
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lors de la résolution du compte par CIN.');
        }
    }
}