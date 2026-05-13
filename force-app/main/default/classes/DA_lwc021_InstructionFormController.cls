/**
 * @description  : Controller LWC — Formulaire d'instruction
 * @author       : D&A Technologies
 */
public with sharing class DA_lwc021_InstructionFormController {

    // ─── Récupérer les instructions liées à un sinistre ───────────────────────
    @AuraEnabled(cacheable=true)
    public static List<Instruction__c> getInstructions(Id sinisterId) {
        try {
            return DM008_Instruction.getByClaimId(sinisterId);
        } catch (Exception e) {
            throw new AuraHandledException('getInstructions: ' + e.getMessage());
        }
    }

    // ─── Récupérer le(s) véhicule(s) lié(s) au sinistre ─────────────────────
    @AuraEnabled(cacheable=true)
    public static List<Vehicule__c> getVehiculesBySinistre(Id sinisterId) {
        try {
            return DM008_Instruction.getVehiculesByClaimId(sinisterId);
        } catch (Exception e) {
            throw new AuraHandledException('getVehiculesBySinistre: ' + e.getMessage());
        }
    }

    // ─── Récupérer les victimes / passagers liés au sinistre ─────────────────
    @AuraEnabled(cacheable=true)
    public static List<ClaimParticipant__c> getVictimesBySinistre(Id sinisterId) {
        try {
            return DM008_Instruction.getVictimesByClaimId(sinisterId);
        } catch (Exception e) {
            throw new AuraHandledException('getVictimesBySinistre: ' + e.getMessage());
        }
    }

    // ─── Récupérer les garanties (ClaimCoverage__c) liées au sinistre ────────
    @AuraEnabled(cacheable=true)
    public static List<ClaimCoverage__c> getCoveragesBySinistre(Id sinisterId) {
        try {
            return DM008_Instruction.getCoveragesByClaimId(sinisterId);
        } catch (Exception e) {
            throw new AuraHandledException('getCoveragesBySinistre: ' + e.getMessage());
        }
    }

    // ─── Créer ou modifier une instruction ───────────────────────────────────
    @AuraEnabled
    public static void saveInstruction(String payload) {
        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(payload);
            EM004_Instruction.saveFromPayload(data);
        } catch (AuraHandledException e) {
            throw e;
        } catch (DmlException e) {
            throw new AuraHandledException('Erreur DML : ' + e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException('Erreur inattendue : ' + e.getMessage());
        }
    }

    // ─── Supprimer une instruction ───────────────────────────────────────────
    @AuraEnabled
    public static void deleteInstruction(Id instructionId) {
        try {
            EM004_Instruction.deleteInstruction(instructionId);
        } catch (Exception e) {
            throw new AuraHandledException('deleteInstruction: ' + e.getMessage());
        }
    }
}