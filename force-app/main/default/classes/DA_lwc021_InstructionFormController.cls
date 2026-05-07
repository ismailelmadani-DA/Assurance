/**
 * InstructionFormController
 * ─────────────────────────────────────────────────────────────────
 * Apex controller for the instructionForm LWC component.
 *
 * Methods:
 *  - getVehiclesByClaim     : Returns vehicles linked to a sinistre
 *  - getParticipantsByClaim : Returns claim participants (victims) linked to a sinistre
 *  - createInstruction      : Creates an Instruction__c record with auto status/step
 * ─────────────────────────────────────────────────────────────────
 */
public with sharing class DA_lwc021_InstructionFormController {

    // ─── Statuts & Étapes constants ───────────────────────────────────────────
    private static final String STATUT_CREATED  = 'Instruction créée';
    private static final String ETAPE_DOCS      = 'Étude de documents';

    // ─────────────────────────────────────────────────────────────────────────
    //  1. Get vehicles linked to a Claim
    // ─────────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<Vehicule__c> getVehiclesByClaim(Id claimId) {
        if (claimId == null) {
            throw new AuraHandledException('claimId est obligatoire.');
        }

        // The Claim has a direct Vehicule__c lookup (Vehicule__c field on Claim__c).
        // We also query vehicles that appear on ClaimParticipant__c linked to the claim
        // to capture all involved vehicles.
        Set<Id> vehicleIds = new Set<Id>();

        // Direct vehicle on the claim
        List<Claim__c> claims = [
            SELECT Id, Vehicule__c
            FROM Claim__c
            WHERE Id = :claimId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (!claims.isEmpty() && claims[0].Vehicule__c != null) {
            vehicleIds.add(claims[0].Vehicule__c);
        }

        // Vehicles from participants
        for (ClaimParticipant__c cp : [
            SELECT Vehicule__c
            FROM ClaimParticipant__c
            WHERE Claim__c = :claimId
            AND Vehicule__c != null
            WITH SECURITY_ENFORCED
        ]) {
            vehicleIds.add(cp.Vehicule__c);
        }

        if (vehicleIds.isEmpty()) {
            return new List<Vehicule__c>();
        }

        return [
            SELECT Id, Name, RegistrationNumber__c
            FROM Vehicule__c
            WHERE Id IN :vehicleIds
            WITH SECURITY_ENFORCED
            ORDER BY Name ASC
        ];
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  2. Get claim participants linked to a Claim
    // ─────────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<ClaimParticipant__c> getParticipantsByClaim(Id claimId) {
        if (claimId == null) {
            throw new AuraHandledException('claimId est obligatoire.');
        }

        return [
            SELECT Id, Name, Roles__c, StateOfPerson__c,
                   Civilite__c, BirthDay__c, ParticipantAccount__c,
                   TypeContact__c, isDriver__c
            FROM ClaimParticipant__c
            WHERE Claim__c = :claimId
            WITH SECURITY_ENFORCED
            ORDER BY Name ASC
        ];
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  3. Create Instruction
    // ─────────────────────────────────────────────────────────────────────────
    @AuraEnabled
    public static Instruction__c createInstruction(String params) {
        if (String.isBlank(params)) {
            throw new AuraHandledException('Les paramètres sont obligatoires.');
        }

        // Parse JSON payload from LWC
        Map<String, Object> payload;
        try {
            payload = (Map<String, Object>) JSON.deserializeUntyped(params);
        } catch (Exception e) {
            throw new AuraHandledException('Paramètres invalides : ' + e.getMessage());
        }

        Id    claimId       = (Id)    String.valueOf(payload.get('claimId'));
        String instrType    = (String) payload.get('instructionType');
        String typeDegat    = (String) payload.get('typeDegat');
        String vehicleId    = (String) payload.get('vehicleId');
        String participantId = (String) payload.get('participantId');

        // Validate mandatory fields
        if (claimId == null) {
            throw new AuraHandledException('Le sinistre est obligatoire.');
        }
        if (String.isBlank(instrType)) {
            throw new AuraHandledException('Le type d\'instruction est obligatoire.');
        }

        // Build the new Instruction record
        Instruction__c instr = new Instruction__c();
        instr.Claim__c            = claimId;
        instr.InstructionType__c  = instrType;
        instr.TypeDegat__c        = typeDegat;

        // Auto-set status and step as per business rules
        instr.Statut__c           = STATUT_CREATED;
       // instr.Etape__c            = ETAPE_DOCS;

        // Conditional assignment based on type of damage
        if (typeDegat == 'Corporel' && String.isNotBlank(participantId)) {
            instr.Victimes__c = (Id) participantId;
        }

        // Insert with security check
        try {
            insert as user instr;
        } catch (DmlException e) {
            throw new AuraHandledException('Erreur lors de la création : ' + e.getDmlMessage(0));
        }

        // Re-query to get auto-number Name and other populated fields
        return [
            SELECT Id, Name, Statut__c, InstructionType__c, TypeDegat__c, Victimes__c
            FROM Instruction__c
            WHERE Id = :instr.Id
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
    }
}