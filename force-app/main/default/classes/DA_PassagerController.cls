public with sharing class DA_PassagerController {

    @AuraEnabled
    public static List<Passager__c> getPassengers(Id caseId) {
        return [
            SELECT Id,
                   Civilite__c,
                   Name,
                   CIN__c,
                   Pays__c,
                   Ville__c,
                   StateOfPerson__c,
                   isDriver__c,
                   Compte__c
            FROM Passager__c
            WHERE Case__c = :caseId
              AND Roles__c = 'Passager assuré'
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static void deletePassenger(Id passengerId) {
        delete [SELECT Id FROM Passager__c WHERE Id = :passengerId LIMIT 1];
    }

    @AuraEnabled(cacheable=true)
    public static List<Account> getAvailableAccounts() {
        return [
            SELECT Id, Name
            FROM Account
            ORDER BY Name
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getAccountPrefillData(Id accountId) {
        if (accountId == null) {
            return new Map<String, String>();
        }

        Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe().fields.getMap();

        List<String> fieldsToQuery = new List<String>{ 'Id', 'Name' };

        List<String> optionalFields = new List<String>{
            'Civilite__c',
            'Sexe__c',
            'MaritalStatus__c',
            'Adresse__c',
            'Pays__c',
            'Ville__c',
            'Email__c',
            'Phone'
        };

        for (String fieldName : optionalFields) {
            if (accountFields.containsKey(fieldName)) {
                fieldsToQuery.add(fieldName);
            }
        }

        String soql = 'SELECT ' + String.join(fieldsToQuery, ',') +
                      ' FROM Account WHERE Id = :accountId LIMIT 1';

        Account acc = Database.query(soql);

        Map<String, String> result = new Map<String, String>();
        result.put('Name', (String) acc.get('Name'));

        for (String fieldName : optionalFields) {
            if (accountFields.containsKey(fieldName) && acc.get(fieldName) != null) {
                result.put(fieldName, String.valueOf(acc.get(fieldName)));
            }
        }

        return result;
    }

    @AuraEnabled
    public static Id savePassenger(Passager__c passengerData) {
        validateInput(passengerData);

        passengerData.CIN__c = normalizeCin(passengerData.CIN__c);

        if (passengerData.Compte__c == null) {
            throw new AuraHandledException('Le compte du participant est obligatoire.');
        }

        List<Passager__c> existingPassengers = [
            SELECT Id, CIN__c, Case__c, Roles__c, Compte__c
            FROM Passager__c
            WHERE CIN__c = :passengerData.CIN__c
              AND Roles__c = 'Passager assuré'
              AND Case__c = :passengerData.Case__c
            LIMIT 10
        ];

        // Aucun CIN trouvé -> INSERT
        if (existingPassengers.isEmpty()) {
            insert passengerData;
            return passengerData.Id;
        }

        // CIN trouvé
        for (Passager__c existingPassenger : existingPassengers) {
            // même compte + même CIN -> UPDATE
            if (existingPassenger.Compte__c == passengerData.Compte__c) {
                passengerData.Id = existingPassenger.Id;
                update passengerData;
                return passengerData.Id;
            } else {
                // autre compte + même CIN -> REFUS
                throw new AuraHandledException(
                    'Ce CIN existe déjà pour un autre utilisateur.'
                );
            }
        }

        throw new AuraHandledException(
            'Impossible de traiter l’enregistrement du passager.'
        );
    }

    private static void validateInput(Passager__c p) {
        if (p == null) {
            throw new AuraHandledException('Aucune donnée reçue.');
        }

        if (String.isBlank(p.Name)) {
            throw new AuraHandledException('Nom et prénom obligatoires.');
        }

        if (String.isBlank(p.CIN__c)) {
            throw new AuraHandledException('CIN obligatoire.');
        }

        if (p.Case__c == null) {
            throw new AuraHandledException('Dossier obligatoire.');
        }
    }

    private static String normalizeCin(String cin) {
        return String.isBlank(cin) ? null : cin.trim().toUpperCase();
    }
}