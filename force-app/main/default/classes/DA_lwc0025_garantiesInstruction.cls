/**
 * DA_lwc0025_garantiesInstruction
 */
public with sharing class DA_lwc0025_garantiesInstruction {
    
    @AuraEnabled(cacheable=true)
    public static List<Instruction_Coverage__c> getInstructionCoverages(String instructionId) {
        return DM_InstructionCoverage.getInstructionCoverages(instructionId);
    }
}