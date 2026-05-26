// ═══════════════════════════════════════════════════════════════
// DM008_Instruction — Data Manager (lecture uniquement)
// ═══════════════════════════════════════════════════════════════
public with sharing class DM008_Instruction {

    private static final String OBJECT_INSTRUCTION = 'Instruction__c';
    private static final String OBJECT_CLAIM       = 'Claim__c';
    private static final String OBJECT_VEHICULE    = 'Vehicule__c';
    private static final String OBJECT_PARTICIPANT = 'ClaimParticipant__c';
    private static final String OBJECT_COVERAGE    = 'ClaimCoverage__c';

    private static final String FIELDS_INSTRUCTION =
        'Id, Name, InstructionType__c, TypeDegat__c, Statut__c, ' +
        'Vehicule__c, Vehicule__r.Name, ' +
        'Victimes__c, Victimes__r.Name, ' +
        'Victimes__r.ParticipantAccount__c, Victimes__r.ParticipantAccount__r.Name, ' +
        'CreatedDate, RecordTypeId, RecordType.DeveloperName';

    private static final String FIELDS_VEHICULE =
        'Id, Name, RegistrationNumber__c, Brand__c, Modele__c, TypeVehicule__c, ' +
        'ProprietaireDuVehicule__c, ProprietaireDuVehicule__r.Name, ' +
        'AttestationNumber__c, DateOfFirstRegistration__c';

    private static final String FIELDS_PARTICIPANT =
        'Id, Name, ParticipantAccount__c, ParticipantAccount__r.Name, ' +
        'Roles__c, StateOfPerson__c, BirthDay__c, TypeContact__c, ' +
        'isDriver__c, Civilite__c, Sexe__c';

    private static final String FIELDS_COVERAGE =
        'Id, Name, CodeGarantie__c, Insurance_Policy_Coverage__c, Claim__c';

    /**
     * Récupère les instructions liées à un sinistre.
     */
    public static List<Instruction__c> getByClaimId(Id claimId) {
        if (claimId == null) return new List<Instruction__c>();
        String safeId    = String.escapeSingleQuotes(String.valueOf(claimId));
        String conditions = 'Claim__c = \'' + safeId + '\'';
        return (List<Instruction__c>) DA_Utility.query(
            FIELDS_INSTRUCTION, OBJECT_INSTRUCTION, conditions, 'CreatedDate DESC', null
        );
    }

    /**
     * Récupère une instruction par son Id (avec Claim__c).
     */
    public static Instruction__c getById(Id instructionId) {
        if (instructionId == null) return null;
        return (Instruction__c) DA_Utility.getById(
            'Id, Claim__c', OBJECT_INSTRUCTION, instructionId
        );
    }

    /**
     * Récupère le véhicule lié à un sinistre (via Claim__c.Vehicule__c).
     */
    public static List<Vehicule__c> getVehiculesByClaimId(Id claimId) {
        if (claimId == null) return new List<Vehicule__c>();
        Claim__c claim = (Claim__c) DA_Utility.getById('Id, Vehicule__c', OBJECT_CLAIM, claimId);
        if (claim == null || claim.Vehicule__c == null) {
            return new List<Vehicule__c>();
        }
        String safeVehId = String.escapeSingleQuotes(String.valueOf(claim.Vehicule__c));
        String conditions = 'Id = \'' + safeVehId + '\'';
        return (List<Vehicule__c>) DA_Utility.query(
            FIELDS_VEHICULE, OBJECT_VEHICULE, conditions, null, 1
        );
    }

    /**
     * Récupère les victimes / passagers liés à un sinistre.
     */
    public static List<ClaimParticipant__c> getVictimesByClaimId(Id claimId) {
        if (claimId == null) return new List<ClaimParticipant__c>();
        String safeId    = String.escapeSingleQuotes(String.valueOf(claimId));
        String conditions = 'Claim__c = \'' + safeId + '\'';
        return (List<ClaimParticipant__c>) DA_Utility.query(
            FIELDS_PARTICIPANT, OBJECT_PARTICIPANT, conditions, 'Name', null
        );
    }

    /**
     * Récupère les garanties (ClaimCoverage__c) liées à un sinistre.
     */
    public static List<ClaimCoverage__c> getCoveragesByClaimId(Id claimId) {
        if (claimId == null) return new List<ClaimCoverage__c>();
        String safeId    = String.escapeSingleQuotes(String.valueOf(claimId));
        String conditions = 'Claim__c = \'' + safeId + '\'';
        return (List<ClaimCoverage__c>) DA_Utility.query(
            FIELDS_COVERAGE, OBJECT_COVERAGE, conditions, 'Name', null
        );
    }
}