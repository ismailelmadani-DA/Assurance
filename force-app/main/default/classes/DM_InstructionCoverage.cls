public with sharing class DM_InstructionCoverage {
    
    public static List<Instruction_Coverage__c> getInstructionCoverages(String instructionId) {
            String fields = 'Id, Name, CurrencyIsoCode, ' +'ClaimCoverage__r.Name, ClaimCoverage__r.CodeGarantie__c, ' +
                           'Instruction__r.Name, Instruction__r.InstructionType__c, Instruction__r.TypeDegat__c';
            String conditions = 'Instruction__c = \'' + String.escapeSingleQuotes(instructionId) + '\'';
            String orderBy = 'Name ASC';
            List<SObject> results = DA_Utility.query(fields, 'Instruction_Coverage__c', conditions, orderBy, null);
            System.debug('DM_InstructionCoverage - Instruction ID: ' + instructionId);
            System.debug('DM_InstructionCoverage - Résultats trouvés: ' + results.size());
            return (List<Instruction_Coverage__c>) results;
        
    }
}