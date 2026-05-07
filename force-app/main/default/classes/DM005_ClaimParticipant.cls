public with sharing class DM005_ClaimParticipant {

    private static final String CLAIM_PARTICIPANT = 'ClaimParticipant__c';

    private static final String FIELDS =
        'Id, Name, Claim__c, Claim__r.Name, ' +
        'ParticipantAccount__c, ParticipantAccount__r.Name, ' +
        'Roles__c, StateOfPerson__c, ' +
        'Vehicule__c, Vehicule__r.RegistrationNumber__c, ' +
        'BirthDay__c, Sexe__c, Civilite__c, ' +
        'ParticipantCNI__c, TypeContact__c, ' +
        'isDriver__c, isOwner__c, Passager__c';

    public static List<ClaimParticipant__c> getByClaimId(String fields, Id claimId) {
        String queryFields = String.isNotBlank(fields) ? fields : FIELDS;
        String conditions = 'Claim__c = \'' + String.escapeSingleQuotes(String.valueOf(claimId)) + '\'';
        return (List<ClaimParticipant__c>) DA_Utility.query(queryFields, CLAIM_PARTICIPANT, conditions, 'CreatedDate DESC', null);
    }

    public static List<ClaimParticipant__c> getByAccountId(String fields, Id accountId) {
        String queryFields = String.isNotBlank(fields) ? fields : FIELDS;
        String conditions = 'ParticipantAccount__c = \'' + String.escapeSingleQuotes(String.valueOf(accountId)) + '\'';
        return (List<ClaimParticipant__c>) DA_Utility.query(queryFields, CLAIM_PARTICIPANT, conditions, 'CreatedDate DESC', null);
    }

    public static List<ClaimParticipant__c> getByClaimAndRole(String fields, Id claimId, String role) {
        String queryFields = String.isNotBlank(fields) ? fields : FIELDS;
        String safeId = String.escapeSingleQuotes(String.valueOf(claimId));
        String safeRole = String.escapeSingleQuotes(role);
        String conditions = 'Claim__c = \'' + safeId + '\' AND Roles__c = \'' + safeRole + '\'';
        return (List<ClaimParticipant__c>) DA_Utility.query(queryFields, CLAIM_PARTICIPANT, conditions, 'CreatedDate DESC', null);
    }

    public static ClaimParticipant__c getById(String fields, Id recordId) {
        String queryFields = String.isNotBlank(fields) ? fields : FIELDS;
        return (ClaimParticipant__c) DA_Utility.getById(queryFields, CLAIM_PARTICIPANT, recordId);
    }

    public static Boolean existsByClaimRoleAndCIN(Id claimId, String role, String cin, Id excludeId) {
        String safeClaimId = String.escapeSingleQuotes(String.valueOf(claimId));
        String safeRole = String.escapeSingleQuotes(role);
        String safeCin = String.escapeSingleQuotes(cin.trim());
        String conditions = 'Claim__c = \'' + safeClaimId + '\' AND Roles__c = \'' + safeRole + '\''
            + ' AND ParticipantCNI__c = \'' + safeCin + '\'';
        if (excludeId != null) {
            conditions += ' AND Id != \'' + String.escapeSingleQuotes(String.valueOf(excludeId)) + '\'';
        }
        List<SObject> existing = DA_Utility.query('Id', CLAIM_PARTICIPANT, conditions, null, 1);
        return !existing.isEmpty();
    }

    public static void deleteById(Id recordId) {
        DA_Utility.deleteById(CLAIM_PARTICIPANT, recordId);
    }

    public static Claim__c getClaimById(String fields, Id claimId) {
        String safeId = String.escapeSingleQuotes(String.valueOf(claimId));
        List<SObject> results = DA_Utility.query(fields, 'Claim__c', 'Id = \'' + safeId + '\'', null, 1);
        return results.isEmpty() ? null : (Claim__c) results[0];
    }
    // ── Méthodes ajoutées pour ClaimParticipantController / EMClaimParticipant ──

    /**
     * Surcharge sans paramètre fields — utilisée par ClaimParticipantController.getClaimParticipants()
     */
    public static List<ClaimParticipant__c> getByClaimAndRole(Id claimId, String role) {
        return getByClaimAndRole(null, claimId, role);
    }

    /**
     * Retourne le détail complet d'un participant pour le formulaire d'édition.
     * Utilisée par ClaimParticipantController.getParticipantById()
     * et EMClaimParticipant.updateParticipant() pour récupérer le Claim__c.
     */
    public static ClaimParticipant__c getDetailById(Id recordId) {
        String detailFields =
            'Id, Name, Claim__c, ' +
            'ParticipantAccount__c, ParticipantAccount__r.Name, ' +
            'ParticipantAccount__r.Civility__c, ' +
            'ParticipantAccount__r.Email__c, ' +
            'ParticipantAccount__r.Phone, ' +
            'Roles__c, StateOfPerson__c, ' +
            'Vehicule__c, ' +
            'BirthDay__c, Sexe__c, MaritalStatus__c, ' +
            'ParticipantCNI__c, Adresse__c, Ville__c, Pays__c, ' +
            'isDriver__c, IPP__c, ITT__c, DateDeces__c, RevenuAnnuel__c';
        return (ClaimParticipant__c) DA_Utility.getById(detailFields, CLAIM_PARTICIPANT, recordId);
    }

    /**
     * Alias de existsByClaimRoleAndCIN avec signature attendue par EMClaimParticipant.
     * Vérifie le doublon CIN uniquement sur le même sinistre — autres sinistres autorisés.
     */
    public static Boolean isCinDuplicateInClaim(String cin, Id claimId, String role, Id excludeParticipantId) {
        if (String.isBlank(cin) || claimId == null) return false;
        return existsByClaimRoleAndCIN(claimId, role, cin, excludeParticipantId);
    }

    /**
     * Recherche un Account par email ou par nom.
     */
    public static Account findAccountByEmailOrName(String email, String fullName) {
        String conditions;
        if (String.isNotBlank(email)) {
            conditions = 'Email__c = \'' + String.escapeSingleQuotes(email) + '\'';
        } else if (String.isNotBlank(fullName)) {
            conditions = 'Name = \'' + String.escapeSingleQuotes(fullName) + '\'';
        } else {
            return null;
        }
        List<SObject> results = DA_Utility.query(
            'Id, Name, Email__c, Phone, CIN__c',
            'Account',
            conditions,
            null,
            1
        );
        return results.isEmpty() ? null : (Account) results[0];
    }

    /**
     * Retourne l'Id du véhicule associé à un sinistre.
     * Utilisée par EMClaimParticipant.createParticipant()
     */
    public static Id getClaimVehicleId(Id claimId) {
        if (claimId == null) return null;
        Claim__c c = getClaimById('Id, Vehicule__c', claimId);
        return c?.Vehicule__c;
    }
}