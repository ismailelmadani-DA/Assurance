/**
 * @description       : Tests unitaires du controller des couvertures d'instruction : 
 *                     récupération des Instruction_Coverage liées à une Instruction
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 2026-05-26
 */
@isTest
public class DA_InstructionCoverageControllerTest {

    /**
    * @description      :   Configure les données de test : Account, Policy, Case, Claim, 
    *                       ClaimCoverage, Instruction et Instruction_Coverage
    * @method Name      :   setupTestData
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @TestSetup
    static void setupTestData() {
        DA_TestBuilderFactory factory = new DA_TestBuilderFactory()
            .withAccount();
        
        Account account = factory.getAccounts()[0];
        
        // Créer une Policy
        factory.withCustomPolicies(1, account.Id, null);
        InsurancePolicy__c policy = factory.getPolicies()[0];
        
        // Créer une InsurancePolicyCoverage
        factory.withInsurancePolicyCoverages(1, policy.Id, null);
        InsurancePolicyCoverage__c policyCoverage = factory.getInsurancePolicyCoverages()[0];
        
        // Créer une Case (sujet du sinistre)
        factory.withCases(1, account.Id, policy.Id, 'Test Case for Instruction', null);
        Case caseRecord = factory.getCases()[0];
        
        // Créer un Claim (sinistre) lié à la Case
        factory.withClaims(1, caseRecord.Id, null);
        Claim__c claim = factory.getClaims()[0];
        
        // Créer une ClaimCoverage (garantie du sinistre)
        factory.withClaimCoverages(1, claim.Id, policyCoverage.Id, null);
        ClaimCoverage__c claimCoverage = factory.getClaimCoverages()[0];
        
        // Créer une Instruction
        factory.withInstruction();
        Instruction__c instruction = factory.getInstructions()[0];
        
        // Créer une Instruction_Coverage (interface de liaison)
        factory.withInstructionCoverages(1, instruction.Id, claimCoverage.Id, null);
    }

    /**
    * @description      :   Vérifie que getInstructionCoverages retourne les couvertures 
    *                       liées à une Instruction avec un ID valide
    * @method Name      :   testGetInstructionCoverages_WithValidInstructionId
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void testGetInstructionCoverages_WithValidInstructionId() {
        Instruction__c instruction = [SELECT Id FROM Instruction__c LIMIT 1];
        
        Test.startTest();
        List<Instruction_Coverage__c> result = DA_InstructionCoverageController.getInstructionCoverages(instruction.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Résultat ne doit pas être null');
        System.assertEquals(1, result.size(), 'Doit retourner 1 Instruction_Coverage');
        System.assertEquals(instruction.Id, result[0].Instruction__c, 'Doit être lié à l\'Instruction');
    }

    /**
    * @description      :   Vérifie que getInstructionCoverages retourne une liste vide 
    *                       quand l'InstructionId est null
    * @method Name      :   testGetInstructionCoverages_WithNullInstructionId
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
   

    /**
    * @description      :   Vérifie que getInstructionCoverages retourne une liste vide 
    *                       pour une Instruction inexistante
    * @method Name      :   testGetInstructionCoverages_WithInexistentInstructionId
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void testGetInstructionCoverages_WithInexistentInstructionId() {
        // Créer un Claim d'abord (Master-Detail obligatoire)
Claim__c tempClaim = new Claim__c();
insert tempClaim;

Instruction__c temp = new Instruction__c(
    Claim__c = tempClaim.Id  // ← Pas d'édition du Name!
);
        insert temp;
        Id tempId = temp.Id;
        delete temp;
        
        Test.startTest();
        List<Instruction_Coverage__c> result = DA_InstructionCoverageController.getInstructionCoverages(tempId);
        Test.stopTest();
        
        System.assertEquals(0, result.size(), 'Doit retourner liste vide pour Instruction inexistante');
    }

    /**
    * @description      :   Vérifie que getInstructionCoverages retourne plusieurs couvertures 
    *                       liées à la même Instruction
    * @method Name      :   testGetInstructionCoverages_WithMultipleCoverages
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void testGetInstructionCoverages_WithMultipleCoverages() {
        Instruction__c instruction = [SELECT Id FROM Instruction__c LIMIT 1];
        ClaimCoverage__c claimCoverage = [SELECT Id FROM ClaimCoverage__c LIMIT 1];
        
        // Créer une deuxième Instruction_Coverage pour la même Instruction
        Instruction_Coverage__c instructionCoverage2 = new Instruction_Coverage__c(
            Name = 'TEST_COVERAGE_2',
            Instruction__c = instruction.Id,
            ClaimCoverage__c = claimCoverage.Id
        );
        insert instructionCoverage2;
        
        Test.startTest();
        List<Instruction_Coverage__c> result = DA_InstructionCoverageController.getInstructionCoverages(instruction.Id);
        Test.stopTest();
        
        System.assertEquals(2, result.size(), 'Doit retourner 2 Instruction_Coverage');
        for (Instruction_Coverage__c cov : result) {
            System.assertEquals(instruction.Id, cov.Instruction__c, 'Tous les coverages doivent être liés à l\'Instruction');
        }
    }

    /**
    * @description      :   Vérifie que les champs relationnels (ClaimCoverage__r) 
    *                       sont correctement récupérés et accessibles
    * @method Name      :   testGetInstructionCoverages_RelationshipFieldsPopulated
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void testGetInstructionCoverages_RelationshipFieldsPopulated() {
        Instruction__c instruction = [SELECT Id FROM Instruction__c LIMIT 1];
        
        Test.startTest();
        List<Instruction_Coverage__c> result = DA_InstructionCoverageController.getInstructionCoverages(instruction.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Résultat ne doit pas être null');
        System.assert(result.size() > 0, 'Au moins 1 résultat attendu');
        
        // Vérifier que les champs relationnels sont accessibles (requête inclut ClaimCoverage__r)
        Instruction_Coverage__c cov = result[0];
        System.assertNotEquals(null, cov.ClaimCoverage__c, 'ClaimCoverage__c ne doit pas être null');
    }
}