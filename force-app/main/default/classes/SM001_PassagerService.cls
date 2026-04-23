public with sharing class SM001_PassagerService {

    private static final String CLASS_NAME = SM001_PassagerService.class.getName();
    private static final String ROLE_AUTRES_PARTIE = 'Autres partie';
    private static final String ROLE_PASSAGER_ASSURE = 'Passager assure';

    public static List<Passager__c> getPassagersAutresPartie(Id caseId) {
        System.debug(CLASS_NAME + ' - Start method getPassagersAutresPartie');
        if (caseId == null) {
            throw new AuraHandledException('L\'identifiant du dossier est requis.');
        }
        List<Passager__c> result = DM001_Passager.getPassagersByCaseAndRole(caseId, ROLE_AUTRES_PARTIE);
        System.debug(CLASS_NAME + ' - End method getPassagersAutresPartie');
        return result;
    }

    public static void deletePassager(Id passagerId) {
        System.debug(CLASS_NAME + ' - Start method deletePassager');
        if (passagerId == null) {
            throw new AuraHandledException('L\'identifiant du participant est requis.');
        }
        EM001_Passager.deletePassagerById(passagerId);
        System.debug(CLASS_NAME + ' - End method deletePassager');
    }

    public static Id resolveAccountByCIN(String cin, String nom) {
        System.debug(CLASS_NAME + ' - Start method resolveAccountByCIN');
        if (String.isBlank(cin)) {
            throw new AuraHandledException('Le CIN est obligatoire.');
        }

        String conditions = 'CIN__c = \'' + String.escapeSingleQuotes(cin) + '\'';
        List<Account> existing = (List<Account>) DA_Utility.query('Id', 'Account', conditions, null, 1);

        if (!existing.isEmpty()) {
            System.debug(CLASS_NAME + ' - End method resolveAccountByCIN (existing)');
            return existing[0].Id;
        }

        Account newAcc = new Account();
        newAcc.Name = nom != null ? nom.trim() : cin;
        newAcc.CIN__c = cin;
        insert newAcc;
        System.debug(CLASS_NAME + ' - End method resolveAccountByCIN (created)');
        return newAcc.Id;
    }

    public static void savePassagers(Id caseId, String passengersJson) {
        System.debug(CLASS_NAME + ' - Start method savePassagers');

        // 1. Recuperer le compte parent
        Id parentAccountId = resolveParentAccount(caseId);

        // 2. Deserialiser et valider
        List<Object> passList = (List<Object>) JSON.deserializeUntyped(passengersJson);
        List<Map<String, Object>> dataList = new List<Map<String, Object>>();
        for (Object obj : passList) {
            dataList.add((Map<String, Object>) obj);
        }

        EM001_Passager.validatePassagers(dataList);
        EM001_Passager.checkDuplicateCINs(dataList, caseId);

        // 3. Mapper les donnees en objets Passager__c
        List<Passager__c> toInsert = new List<Passager__c>();
        for (Map<String, Object> data : dataList) {
            data.put('Roles__c', ROLE_PASSAGER_ASSURE);
            Passager__c p = EM001_Passager.mapDataToPassager(data, caseId, parentAccountId);
            toInsert.add(p);
        }

        // 4. Inserer via DM
        if (!toInsert.isEmpty()) {
            EM001_Passager.insertPassagers(toInsert);
        }

        System.debug(CLASS_NAME + ' - End method savePassagers');
    }

    public static void saveOtherParties(Id caseId, String partiesJson) {
        System.debug(CLASS_NAME + ' - Start method saveOtherParties');

        if (String.isBlank(partiesJson) || partiesJson == '[]') {
            return;
        }

        // 1. Gestion du compte
        Id accountIdToUse = resolveParentAccountWithFallback(caseId);

        // 2. Deserialiser
        List<Object> partyList = (List<Object>) JSON.deserializeUntyped(partiesJson);

        // 3. Mise a jour OpposingParty sur le Case
        if (!partyList.isEmpty()) {
            Map<String, Object> firstParty = (Map<String, Object>) partyList[0];
            update new Case(
                Id = caseId,
                OpposingParty__c = (String) firstParty.get('OpposingParty__c')
            );
        }

        // 4. Mapper et inserer les tiers
        List<Passager__c> toInsert = new List<Passager__c>();
        for (Object obj : partyList) {
            Map<String, Object> data = (Map<String, Object>) obj;
            Passager__c p = EM001_Passager.mapOtherPartyToPassager(data, caseId, accountIdToUse);
            toInsert.add(p);
        }

        if (!toInsert.isEmpty()) {
            EM001_Passager.insertPassagers(toInsert);
        }

        System.debug(CLASS_NAME + ' - End method saveOtherParties');
    }

    // ===== PRIVATE HELPERS =====

    private static Id resolveParentAccount(Id caseId) {
        String conditions = 'Id = \'' + String.escapeSingleQuotes(String.valueOf(caseId)) + '\'';
        List<Case> cases = (List<Case>) DA_Utility.query('Id, AccountId, Police__r.AccountName__c', 'Case', conditions, null, 1);

        if (cases.isEmpty()) {
            throw new AuraHandledException('Le dossier (Case) est introuvable.');
        }

        Id parentAccountId = cases[0].AccountId != null ? cases[0].AccountId : cases[0].Police__r.AccountName__c;

        if (parentAccountId == null) {
            throw new AuraHandledException('Erreur : Aucun compte client n\'est lie a ce dossier.');
        }
        return parentAccountId;
    }

    private static Id resolveParentAccountWithFallback(Id caseId) {
        String conditions = 'Id = \'' + String.escapeSingleQuotes(String.valueOf(caseId)) + '\'';
        List<Case> cases = (List<Case>) DA_Utility.query('Id, AccountId', 'Case', conditions, null, 1);

        if (cases.isEmpty()) {
            throw new AuraHandledException('Le dossier (Case) est introuvable.');
        }

        Id accountIdToUse = cases[0].AccountId;

        if (accountIdToUse == null) {
            Account defaultAcc = new Account(Name = 'Dossier Sans Compte - Tiers Generique');
            insert defaultAcc;
            accountIdToUse = defaultAcc.Id;

            cases[0].AccountId = accountIdToUse;
            update cases[0];
        }

        return accountIdToUse;
    }
}