public with sharing class EM001_Passager {

    private static final String CLASS_NAME = EM001_Passager.class.getName();

    public static void validatePassager(Map<String, Object> data) {
        System.debug(CLASS_NAME + ' - Start method validatePassager');
        List<String> errors = new List<String>();

        if (String.isBlank((String) data.get('Name__c'))) {
            errors.add('Le nom du passager est obligatoire.');
        }
        if (String.isBlank((String) data.get('CIN__c'))) {
            errors.add('Le CIN est obligatoire.');
        }
        if (String.isBlank((String) data.get('Civilite__c'))) {
            errors.add('La civilite est obligatoire.');
        }

        if (!errors.isEmpty()) {
            throw new AuraHandledException(String.join(errors, ' | '));
        }
        System.debug(CLASS_NAME + ' - End method validatePassager');
    }

    public static void validatePassagers(List<Map<String, Object>> dataList) {
        System.debug(CLASS_NAME + ' - Start method validatePassagers');
        for (Integer i = 0; i < dataList.size(); i++) {
            try {
                validatePassager(dataList[i]);
            } catch (AuraHandledException e) {
                throw new AuraHandledException('Passager ' + (i + 1) + ' : ' + e.getMessage());
            }
        }
        System.debug(CLASS_NAME + ' - End method validatePassagers');
    }

    public static void checkDuplicateCIN(String cin, Id caseId) {
        System.debug(CLASS_NAME + ' - Start method checkDuplicateCIN');
        List<Passager__c> existing = DM001_Passager.getPassagersByCIN(cin, caseId);
        if (!existing.isEmpty()) {
            throw new AuraHandledException('Un passager avec le CIN "' + cin + '" existe deja sur ce dossier.');
        }
        System.debug(CLASS_NAME + ' - End method checkDuplicateCIN');
    }

    public static void checkDuplicateCINs(List<Map<String, Object>> dataList, Id caseId) {
        System.debug(CLASS_NAME + ' - Start method checkDuplicateCINs');
        Set<String> cinsInBatch = new Set<String>();
        for (Map<String, Object> data : dataList) {
            String cin = (String) data.get('CIN__c');
            if (String.isNotBlank(cin)) {
                if (cinsInBatch.contains(cin)) {
                    throw new AuraHandledException('CIN en double dans la liste : "' + cin + '".');
                }
                cinsInBatch.add(cin);
                checkDuplicateCIN(cin, caseId);
            }
        }
        System.debug(CLASS_NAME + ' - End method checkDuplicateCINs');
    }

    public static Passager__c mapDataToPassager(Map<String, Object> data, Id caseId, Id compteId) {
        System.debug(CLASS_NAME + ' - Start method mapDataToPassager');
        Passager__c p = new Passager__c();

        p.Case__c = caseId;
        p.Compte__c = compteId;

        p.Name__c = (String) data.get('Name__c');
        p.CIN__c = (String) data.get('CIN__c');
        p.Civilite__c = (String) data.get('Civilite__c');

        if (data.get('BirthDay__c') != null && String.isNotBlank((String) data.get('BirthDay__c'))) {
            p.BirthDay__c = Date.valueOf((String) data.get('BirthDay__c'));
        }

        p.Pays__c = (String) data.get('Pays__c');
        p.Ville__c = (String) data.get('Ville__c');
        p.Adresse__c = (String) data.get('Adresse__c');
        p.StateOfPerson__c = (String) data.get('StateOfPerson__c');
        p.MaritalStatus__c = (String) data.get('MaritalStatus__c');
        p.MoyenNotification__c = (String) data.get('MoyenNotification__c');

        if (data.get('Telephone__c') != null && String.isNotBlank((String) data.get('Telephone__c'))) {
            p.Telephone__c = (String) data.get('Telephone__c');
        }
        if (data.get('Email__c') != null && String.isNotBlank((String) data.get('Email__c'))) {
            p.Email__c = (String) data.get('Email__c');
        }

        if (data.get('CompagnieAdverse__c') != null && String.isNotBlank((String) data.get('CompagnieAdverse__c'))) {
            p.Account__c = (Id) data.get('CompagnieAdverse__c');
        }

        if (String.isNotBlank((String) data.get('Roles__c'))) {
            p.Roles__c = (String) data.get('Roles__c');
        }

        System.debug(CLASS_NAME + ' - End method mapDataToPassager');
        return p;
    }

    public static void insertPassagers(List<Passager__c> passagers) {
        insert passagers;
    }

    public static void deletePassagerById(Id passagerId) {
        Passager__c p = new Passager__c(Id = passagerId);
        delete p;
    }

    public static Passager__c mapOtherPartyToPassager(Map<String, Object> data, Id caseId, Id compteId) {
        System.debug(CLASS_NAME + ' - Start method mapOtherPartyToPassager');
        Passager__c p = mapDataToPassager(data, caseId, compteId);

        String fullName = (String) data.get('Nom__c') + ' ' + (String) data.get('Prenom__c');
        p.Name = (String) data.get('Nom__c');
        p.Name__c = fullName;
        p.Roles__c = 'Autres partie';

        System.debug(CLASS_NAME + ' - End method mapOtherPartyToPassager');
        return p;
    }
}