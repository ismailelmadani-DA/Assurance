// ═══════════════════════════════════════════════════════════════
// EM004_Instruction — Entity Manager (logique métier / écriture)
// ═══════════════════════════════════════════════════════════════
public with sharing class EM004_Instruction {

    private static final String OBJECT_INSTRUCTION = 'Instruction__c';

    private static final String TYPE_DEGAT_MATERIEL = 'Materiel';
    private static final String TYPE_DEGAT_CORPOREL = 'Corporel';

    /**
     * Crée ou met à jour une instruction à partir des données du formulaire LWC.
     */
    public static Instruction__c saveFromPayload(Map<String, Object> data) {
        Instruction__c instr = resolveInstruction(data);

        applyMandatoryFields(instr, data);
        applyDamageTarget(instr, data);

        upsert instr;

        associateCoverage(instr.Id, (String) data.get('coverageId'));

        return instr;
    }

    /**
     * Crée la liaison Instruction_Coverage__c entre l'instruction et la garantie
     * sélectionnée. Idempotent : ne réinsère pas si la liaison existe déjà.
     */
    private static void associateCoverage(Id instructionId, String coverageId) {
        if (instructionId == null || String.isBlank(coverageId)) return;

        String safeInstr = String.escapeSingleQuotes(String.valueOf(instructionId));
        String safeCov   = String.escapeSingleQuotes(coverageId);
        Integer existing = DA_Utility.count(
            'Instruction_Coverage__c',
            'Instruction__c = \'' + safeInstr + '\' AND ClaimCoverage__c = \'' + safeCov + '\''
        );
        if (existing > 0) return;

        Instruction_Coverage__c link = new Instruction_Coverage__c(
            Instruction__c   = instructionId,
            ClaimCoverage__c = (Id) coverageId
        );
        insert link;
    }

    /**
     * Supprime une instruction par son Id.
     */
    public static void deleteInstruction(Id instructionId) {
        DA_Utility.deleteById(OBJECT_INSTRUCTION, instructionId);
    }

    // ─────────────────────────────────────────────────────────────
    // Helpers privés
    // ─────────────────────────────────────────────────────────────

    private static Instruction__c resolveInstruction(Map<String, Object> data) {
        String instrId = (String) data.get('id');

        if (String.isNotBlank(instrId)) {
            Instruction__c existing = DM008_Instruction.getById((Id) instrId);
            if (existing == null) {
                throw new AuraHandledException('Instruction introuvable.');
            }
            return existing;
        }

        Instruction__c instr = new Instruction__c();

        String sinisterId = (String) data.get('sinisterId');
        if (String.isBlank(sinisterId)) {
            throw new AuraHandledException(
                'sinisterId est vide — vérifiez que le composant est placé sur une page Sinistre.'
            );
        }
        instr.Claim__c = (Id) sinisterId;

        applyRecordType(instr, (String) data.get('recordTypeName'));
        return instr;
    }

    private static void applyRecordType(Instruction__c instr, String recordTypeName) {
        if (String.isBlank(recordTypeName)) return;

        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Instruction__c.getRecordTypeInfosByDeveloperName();

        if (!rtMap.containsKey(recordTypeName)) {
            throw new AuraHandledException(
                'Record Type introuvable : "' + recordTypeName + '". '
                + 'Valeurs disponibles : ' + String.join(new List<String>(rtMap.keySet()), ', ')
            );
        }

        Schema.RecordTypeInfo rti = rtMap.get(recordTypeName);
        if (!rti.isAvailable()) {
            throw new AuraHandledException(
                'Le type d\'enregistrement "' + recordTypeName + '" n\'est pas assigné à votre profil. '
                + 'Contactez votre administrateur Salesforce.'
            );
        }
        instr.RecordTypeId = rti.getRecordTypeId();
    }

    private static void applyMandatoryFields(Instruction__c instr, Map<String, Object> data) {
        String instructionType = (String) data.get('instructionType');
        String typeDegat       = (String) data.get('typeDegat');
        String statut          = (String) data.get('statut');

        if (String.isBlank(instructionType)) {
            throw new AuraHandledException('Le champ "Type d\'instruction" est obligatoire.');
        }
        if (String.isBlank(typeDegat)) {
            throw new AuraHandledException('Le champ "Type de dégât" est obligatoire.');
        }

        instr.InstructionType__c = instructionType;
        instr.TypeDegat__c       = typeDegat;
        instr.Statut__c          = statut;
    }

    private static void applyDamageTarget(Instruction__c instr, Map<String, Object> data) {
        String typeDegat = (String) data.get('typeDegat');

        if (typeDegat == TYPE_DEGAT_MATERIEL) {
            String vehiculeId = (String) data.get('vehiculeId');
            if (String.isBlank(vehiculeId)) {
                throw new AuraHandledException('Veuillez sélectionner un véhicule.');
            }
            instr.Vehicule__c = (Id) vehiculeId;
            instr.Victimes__c = null;
        } else if (typeDegat == TYPE_DEGAT_CORPOREL) {
            String victimeId = (String) data.get('victimeId');
            if (String.isBlank(victimeId)) {
                throw new AuraHandledException('Veuillez sélectionner une victime / passager.');
            }
            instr.Victimes__c = (Id) victimeId;
            instr.Vehicule__c = null;
        }
    }
}