public with sharing class DM_Case {

    private static final String OBJ = 'Case';
    private static final Integer MAX_LIMIT = 200;

    private static final String FIELDS_MISSIONS =
        'Id, CaseNumber, NatureMission__c, Status, CreatedDate, CreatedById, CreatedBy.Name';

    // ─── Réaffectation ──────────────────────────────────────────────

    private static final String FIELDS_DECLARATION =
        'Id, CaseNumber, OwnerId, Police__c, Vehicule__c, DateOfOccurrence__c, Num_ro_d_immatriculation__c';

    private static final String FIELDS_REQUETE =
        'Id, Status, OwnerId, CreatedById, ReaffecterA__c, Declaration_Liee__c, ' +
        'Declaration_Liee__r.CaseNumber, Motif_Reaffectation__c, ReaffecterA__r.Name';

    public static Id getRequeteRecordTypeId() {
        return DA_Utility.getRecordTypeId(OBJ, 'Requete');
    }

    public static List<User> getEligibleUsers() {
        return (List<User>) DA_Utility.query(
            'Id',
            'User',
            'IsActive = true AND Profile.Name IN (\'System Administrator\', \'Manager\', \'Directeur\', \'Gestionnaire\')',
            null,
            null
        );
    }

    public static Case getRequeteById(Id requeteId) {
        return (Case) DA_Utility.getById(FIELDS_REQUETE, OBJ, requeteId);
    }

    public static Case getDeclarationById(Id declarationId) {
        return (Case) DA_Utility.getById(FIELDS_DECLARATION, OBJ, declarationId);
    }

    public static Case getRequeteReaffectationExistante(Id declarationId) {
        List<Case> existantes = (List<Case>) DA_Utility.query(
            'Id, Status, OwnerId, CreatedById, ReaffecterA__c, Motif_Reaffectation__c',
            OBJ,
            'Declaration_Liee__c = \'' + declarationId + '\'' +
            ' AND TypeRequete__c = \'Réaffecter la déclaration\'' +
            ' AND CategorieRequete__c = \'Réaffectation\'',
            'CreatedDate DESC',
            1
        );
        return existantes.isEmpty() ? null : existantes[0];
    }

    // ─── Générique ──────────────────────────────────────────────────

    public static Case getById(String fields, Id caseId) {
        if (caseId == null) return null;
        return (Case) DA_Utility.getById(fields, OBJ, caseId);
    }

    public static List<Case> getMissionsByAccountId(Id accountId) {
        if (accountId == null) return new List<Case>();

        String conditions =
            'Prestataire__c = \'' + accountId + '\'' +
            ' AND RecordType.DeveloperName = \'Mission\'';

        return (List<Case>) DA_Utility.query(
            FIELDS_MISSIONS,
            OBJ,
            conditions,
            'CreatedDate DESC',
            MAX_LIMIT
        );
    }
}