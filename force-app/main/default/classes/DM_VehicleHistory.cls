/**
 * @description  : Data Manager pour l'historique des véhicules d'un passager
 * @author       : D&A Technologies
 * @date         : 2026-04-23
 */
public with sharing class DM_VehicleHistory {

    private static final String CP_FIELDS =
        'Id, isDriver__c, Roles__c, Vehicule__c, Claim__c, ' +
        'Claim__r.Name, ' +
        'Claim__r.Vehicule__c, ' +
        'Claim__r.Vehicule__r.Name, ' +
        'Claim__r.Vehicule__r.RegistrationNumber__c, ' +
        'Claim__r.Vehicule__r.Brand__c, ' +
        'Claim__r.Vehicule__r.ModelePicklist__c, ' +
        'Claim__r.Vehicule__r.Modele__c, ' +
        'Claim__r.Vehicule__r.ProprietaireDuVehicule__r.Name, ' +
        'Vehicule__r.Name, ' +
        'Vehicule__r.RegistrationNumber__c, ' +
        'Vehicule__r.Brand__c, ' +
        'Vehicule__r.ModelePicklist__c, ' +
        'Vehicule__r.Modele__c, ' +
        'Vehicule__r.ProprietaireDuVehicule__r.Name';

    private static final String CP_OBJECT = 'ClaimParticipant__c';

    public static List<ClaimParticipant__c> getParticipantsByAccount(Id accountId) {
        if (accountId == null) return new List<ClaimParticipant__c>();

        String conditions =
            'ParticipantAccount__c = \'' +
            String.escapeSingleQuotes(String.valueOf(accountId)) + '\'';

        return (List<ClaimParticipant__c>) DA_Utility.query(
            CP_FIELDS,
            CP_OBJECT,
            conditions,
            'Vehicule__r.RegistrationNumber__c ASC',
            null
        );
    }

    public static List<ClaimParticipant__c> getParticipantsByIds(Set<Id> cpIds) {
        if (cpIds == null || cpIds.isEmpty()) return new List<ClaimParticipant__c>();

        List<String> escapedIds = new List<String>();
        for (Id cpId : cpIds) {
            escapedIds.add('\'' + String.escapeSingleQuotes(String.valueOf(cpId)) + '\'');
        }
        String conditions = 'Id IN (' + String.join(escapedIds, ',') + ')';

        return (List<ClaimParticipant__c>) DA_Utility.query(
            CP_FIELDS,
            CP_OBJECT,
            conditions,
            'Vehicule__r.RegistrationNumber__c ASC',
            null
        );
    }

    public static List<ClaimParticipant__c> getParticipantsByPassager(Id accountId) {
        if (accountId == null) return new List<ClaimParticipant__c>();

        String conditions =
            'Passager__r.Account__c = \'' +
            String.escapeSingleQuotes(String.valueOf(accountId)) + '\'';

        return (List<ClaimParticipant__c>) DA_Utility.query(
            CP_FIELDS,
            CP_OBJECT,
            conditions,
            'Vehicule__r.RegistrationNumber__c ASC',
            null
        );
    }
}