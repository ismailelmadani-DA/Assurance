public with sharing class PassagerController {

    private static final String CLASS_NAME = PassagerController.class.getName();
    private static final String ROLE_AUTRES_PARTIE = 'Autres partie';

    @AuraEnabled(cacheable=true)
    public static List<Passager__c> getPassagersAutresPartie(Id caseId) {
        System.debug(CLASS_NAME + ' - Start method getPassagersAutresPartie');
        if (caseId == null) {
            throw new AuraHandledException('L\'identifiant du dossier est requis.');
        }
        try {
            List<Passager__c> passagers = DM001_Passager.getPassagersByCaseAndRole(caseId, ROLE_AUTRES_PARTIE);
            System.debug(CLASS_NAME + ' - End method getPassagersAutresPartie');
            return passagers;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deletePassager(Id passagerId) {
        System.debug(CLASS_NAME + ' - Start method deletePassager');
        if (passagerId == null) {
            throw new AuraHandledException('L\'identifiant du participant est requis.');
        }
        try {
            DM001_Passager.deletePassagerById(passagerId);
            System.debug(CLASS_NAME + ' - End method deletePassager');
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id resolveAccountByCIN(String cin, String nom) {
        if (String.isBlank(cin)) {
            throw new AuraHandledException('Le CIN est obligatoire.');
        }
        try {
            List<Account> existing = [
                SELECT Id FROM Account WHERE CIN__c = :cin LIMIT 1
            ];
            if (!existing.isEmpty()) {
                return existing[0].Id;
            }
            Account newAcc = new Account();
            newAcc.Name = nom != null ? nom.trim() : cin;
            newAcc.CIN__c = cin;
            insert newAcc;
            return newAcc.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}