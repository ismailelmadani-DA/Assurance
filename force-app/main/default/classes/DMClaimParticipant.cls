public with sharing class DMClaimParticipant {

    private static final String OBJ  = 'ClaimParticipant__c';
    private static final String ACCT = 'Account';

    private static final String LIST_FIELDS =
        'Id, Name, ParticipantCNI__c, Roles__c, isDriver__c, ' +
        'StateOfPerson__c, Pays__c, Ville__c, Adresse__c, ' +
        'BirthDay__c, MaritalStatus__c, Sexe__c, ' +
        'IPP__c, ITT__c, DateDeces__c, RevenuAnnuel__c, ' +
        'ParticipantAccount__c, ' +
        'ParticipantAccount__r.Name, ' +
        'ParticipantAccount__r.Civility__c, ' +
        'ParticipantAccount__r.Email__c, ' +
        'ParticipantAccount__r.Phone';

    private static final String DETAIL_FIELDS =
        'Id, Name, Claim__c, Roles__c, ParticipantCNI__c, ' +
        'BirthDay__c, MaritalStatus__c, Sexe__c, ' +
        'Pays__c, Ville__c, Adresse__c, ' +
        'StateOfPerson__c, isDriver__c, ' +
        'ITT__c, IPP__c, DateDeces__c, RevenuAnnuel__c, ' +
        'ParticipantAccount__c, ' +
        'ParticipantAccount__r.Name, ' +
        'ParticipantAccount__r.Civility__c, ' +
        'ParticipantAccount__r.Email__c, ' +
        'ParticipantAccount__r.Phone';

    private static final String ACCT_SEARCH_FIELDS = 'Id';
    private static final String ACCT_DETAIL_FIELDS =
        'Id, Name, CIN__c, Email__c, Phone, Civility__c, ' +
        'Adresse__c, Ville__c, Pays__c, ' +
        'DateDeNaissance__c, Sexe__c, MaritalStatus__c';

    // ══════════════════════════════════════════════════════════════════════
    // PARTICIPANTS
    // ══════════════════════════════════════════════════════════════════════

    public static List<SObject> getByClaimAndRole(Id claimId, String role) {
        String safeId   = String.escapeSingleQuotes(String.valueOf(claimId));
        String safeRole = String.escapeSingleQuotes(role);
        String whereClause = 'Claim__c = \'' + safeId + '\' AND Roles__c = \'' + safeRole + '\'';
        return DA_Utility.query(LIST_FIELDS, OBJ, whereClause, 'CreatedDate DESC', null);
    }

    public static ClaimParticipant__c getDetailById(Id participantId) {
        String condition = 'Id = \'' + String.escapeSingleQuotes(String.valueOf(participantId)) + '\'';
        List<SObject> results = DA_Utility.query(DETAIL_FIELDS, OBJ, condition, null, 1);
        return results.isEmpty() ? null : (ClaimParticipant__c) results[0];
    }

    /**
     * Récupère l'Id du véhicule lié au sinistre.
     * CORRECTION : l'objet API name est bien 'Claim__c' (objet custom).
     * On vérifie que le champ Vehicule__c est non-null avant de caster.
     */
    public static Id getClaimVehicleId(Id claimId) {
        if (claimId == null) return null;
        String condition = 'Id = \'' + String.escapeSingleQuotes(String.valueOf(claimId)) + '\'';
        List<SObject> results = DA_Utility.query('Id, Vehicule__c', 'Claim__c', condition, null, 1);
        if (results.isEmpty()) return null;
        Object vehicleField = results[0].get('Vehicule__c');
        return vehicleField != null ? (Id) vehicleField : null;
    }

    // ══════════════════════════════════════════════════════════════════════
    // COMPTES
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Vérifie si un CIN est déjà utilisé sur un Account (scope global, tous sinistres).
     * NON utilisé pour la validation métier CIN — conserver pour d'autres usages
     * mais NE PAS utiliser pour bloquer la création d'un passager.
     * La règle métier est : un CIN unique PAR sinistre, pas globalement.
     */
    public static Boolean isCinDuplicate(String cin, Id excludeAccountId) {
        if (String.isBlank(cin)) return false;
        String conditions = 'CIN__c = \'' + String.escapeSingleQuotes(cin) + '\'';
        if (excludeAccountId != null) {
            conditions += ' AND Id != \'' + String.escapeSingleQuotes(String.valueOf(excludeAccountId)) + '\'';
        }
        List<SObject> results = DA_Utility.query(ACCT_SEARCH_FIELDS, ACCT, conditions, null, 1);
        return !results.isEmpty();
    }

    /**
     * Vérifie si un CIN est déjà utilisé par un autre passager du MÊME sinistre.
     * C'est la seule validation CIN utilisée pour les passagers assurés.
     *
     * Règle :
     *   - Un même CIN peut exister sur plusieurs sinistres différents (autorisé).
     *   - Un même CIN ne peut pas apparaître deux fois sur le même sinistre (bloqué).
     *
     * @param cin                  Le CIN à vérifier (ignoré si blank)
     * @param claimId              L'identifiant du sinistre courant
     * @param role                 Le rôle du participant (ex. 'Passager assuré')
     * @param excludeParticipantId En mode édition, Id du participant en cours (exclu de la recherche)
     * @return true si un doublon existe sur CE sinistre (hors exclusion)
     */
    public static Boolean isCinDuplicateInClaim(String cin, Id claimId, String role, Id excludeParticipantId) {
        if (String.isBlank(cin) || claimId == null || String.isBlank(role)) return false;

        String safeClaimId = String.escapeSingleQuotes(String.valueOf(claimId));
        String safeRole    = String.escapeSingleQuotes(role);
        String safeCin     = String.escapeSingleQuotes(cin.trim());

        // Scope strict : même sinistre + même rôle + même CIN
        String conditions =
            'Claim__c = \'' + safeClaimId + '\'' +
            ' AND Roles__c = \'' + safeRole + '\'' +
            ' AND ParticipantCNI__c = \'' + safeCin + '\'';

        // En édition, on exclut le participant actuel pour ne pas se bloquer soi-même
        if (excludeParticipantId != null) {
            conditions += ' AND Id != \'' + String.escapeSingleQuotes(String.valueOf(excludeParticipantId)) + '\'';
        }

        List<SObject> results = DA_Utility.query('Id', OBJ, conditions, null, 1);
        return !results.isEmpty();
    }

    public static Account findAccountByEmailOrName(String email, String fullName) {
        String conditions = String.isNotBlank(email)
            ? 'Email__c = \'' + String.escapeSingleQuotes(email) + '\''
            : 'Name = \''     + String.escapeSingleQuotes(fullName) + '\'';
        List<SObject> found = DA_Utility.query(ACCT_DETAIL_FIELDS, ACCT, conditions, null, 1);
        return found.isEmpty() ? null : (Account) found[0];
    }

    public static Account getAccountById(Id accountId) {
        String condition = 'Id = \'' + String.escapeSingleQuotes(String.valueOf(accountId)) + '\'';
        List<SObject> results = DA_Utility.query(ACCT_DETAIL_FIELDS, ACCT, condition, null, 1);
        return results.isEmpty() ? null : (Account) results[0];
    }

    public static List<SObject> searchAccounts(
            String searchField, String searchTerm, String extraConditions, Integer lim) {
        return DA_Utility.search(
            ACCT_SEARCH_FIELDS, ACCT, searchField, searchTerm, extraConditions, lim
        );
    }
}