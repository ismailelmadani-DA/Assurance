@isTest
public class PassagerControllerTest {
    
    @TestSetup
    static void setupTestData() {
        DA_TestBuilderFactory builder = new DA_TestBuilderFactory()
            .withAccount()
            .withPolicy();
        
        Account compte = builder.getAccounts()[0];
        InsurancePolicy__c police = builder.getPolicies()[0];
        
        builder.withCases(1, compte.Id, police.Id, 'Test Case Passager', null);
        Case caseRecord = builder.getCases()[0];
        
        builder.withPassengers(1, caseRecord.Id, compte.Id, null);
    }

    @isTest
    static void testGetPassengers() {
        Case caseRecord = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        List<Passager__c> result = PassagerController.getPassengers(caseRecord.Id);
        Test.stopTest();
        
        System.assertEquals(1, result.size());
    }
}