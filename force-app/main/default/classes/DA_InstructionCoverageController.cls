public with sharing class DA_InstructionCoverageController {
    
    @AuraEnabled(cacheable=true)
    public static List<Instruction_Coverage__c> getInstructionCoverages(String instructionId) {
        System.debug('Controller reçu instructionId: ' + instructionId);
        return DM_InstructionCoverage.getInstructionCoverages(instructionId);
    }
}