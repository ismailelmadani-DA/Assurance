@isTest
public class DM001_PassagerTest {
    
    @isTest
    static void testGetPassengersByCase() {
        // Setup avec Builder
        DA_TestBuilderFactory factory = new DA_TestBuilderFactory()
            .withAccount()                                  // Crée 1 Account
            .withCases(1, null, null, 'Test Case', null);  // Crée 1 Case
        
        Account compte = factory.getAccounts()[0];
        Case caseRecord = factory.getCases()[0];
        
        // Ajouter des Passagers
        List<Passager__c> testPassengers = new DA_TestBuilderFactory()
            .withPassengers(2, caseRecord.Id, compte.Id, null)  // Crée 2 Passagers
            .getPassengers();
        
        // Test
        Test.startTest();
        List<Passager__c> result = DM001_Passager.getPassengersByCase(caseRecord.Id, 'Passager assuré');
        Test.stopTest();
        
        // Verify
        System.assertEquals(2, result.size());
    }
    
    @isTest
    static void testGetPassagerById() {
        // Setup
        DA_TestBuilderFactory factory = new DA_TestBuilderFactory()
            .withAccount()
            .withCases(1, null, null, 'Test Case', null);
        
        Account compte = factory.getAccounts()[0];
        Case caseRecord = factory.getCases()[0];
        
        Passager__c p = new DA_TestBuilderFactory()
            .withPassengers(1, caseRecord.Id, compte.Id, null)
            .getPassengers()[0];
        
        // Test
        Test.startTest();
        Passager__c result = DM001_Passager.getPassagerById(p.Id);
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, result);
        System.assertEquals(p.Id, result.Id);
    }
    
    @isTest
    static void testGetPassagersByCIN() {
        // Setup
        DA_TestBuilderFactory factory = new DA_TestBuilderFactory()
            .withAccount()
            .withCases(1, null, null, 'Test Case', null);
        
        Account compte = factory.getAccounts()[0];
        Case caseRecord = factory.getCases()[0];
        
        List<Passager__c> testPassengers = new DA_TestBuilderFactory()
            .withPassengers(2, caseRecord.Id, compte.Id, null)
            .getPassengers();
        
        // Test
        Test.startTest();
        List<Passager__c> result = DM001_Passager.getPassagersByCIN(testPassengers[0].CIN__c, caseRecord.Id);
        Test.stopTest();
        
        // Verify
        System.assertEquals(1, result.size());
    }
    
    @isTest
    static void testGetPassagersAdversesByCase() {
        // Setup
        DA_TestBuilderFactory factory = new DA_TestBuilderFactory()
            .withAccount()
            .withCases(1, null, null, 'Test Case', null);
        
        Account compte = factory.getAccounts()[0];
        Case caseRecord = factory.getCases()[0];
        
        new DA_TestBuilderFactory()
            .withPassengers(2, caseRecord.Id, compte.Id, null);
        
        // Test
        Test.startTest();
        List<Passager__c> result = DM001_Passager.getPassagersAdversesByCase(caseRecord.Id);
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, result);
    }
}