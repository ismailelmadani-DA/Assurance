@isTest
public class EM001_PassagerTest {
    
    @TestSetup
    static void setupTestData() {
        DA_TestBuilderFactory factory = new DA_TestBuilderFactory()
            .withAccount()
            .withPolicy();
        
        Account compte = factory.getAccounts()[0];
        InsurancePolicy__c police = factory.getPolicies()[0];
        
        factory.withCases(1, compte.Id, police.Id, 'Test Case EM001', null);
        Case caseRecord = factory.getCases()[0];
        
        factory.withPassengers(1, caseRecord.Id, compte.Id, new Map<String, Object>{
            'Name' => 'Passager Existant',
            'CIN__c' => 'CIN_EXISTING_12345'
        });
    }

    @isTest
    static void testValidatePassager_WithValidData() {
        Map<String, Object> data = new Map<String, Object>{
            'Name__c' => 'Jean Dupont',
            'CIN__c' => 'CIN123456',
            'Civilite__c' => 'Mr'
        };
        
        Test.startTest();
        try {
            EM001_Passager.validatePassager(data);
            System.assert(true);
        } catch (Exception e) {
            System.assert(false, e.getMessage());
        }
        Test.stopTest();
    }
    
    // ===== TEST 2: DIAGNOSTIC =====
    @isTest
    static void testValidatePassager_MissingName() {
        Map<String, Object> data = new Map<String, Object>{
            'Name__c' => '',
            'CIN__c' => 'CIN123456',
            'Civilite__c' => 'Mr'
        };
        
        Test.startTest();
        try {
            EM001_Passager.validatePassager(data);
            System.assert(false, 'Doit lever une exception');
        } catch (Exception e) {
            System.debug('=== TEST 2 DIAGNOSTIC ===');
            System.debug('Exception TYPE: ' + e.getTypeName());
            System.debug('Exception MESSAGE: ' + e.getMessage());
            System.debug('Exception STACK: ' + e.getStackTraceString());
            System.assert(true, 'Exception levée: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    // ===== TEST 3: DIAGNOSTIC =====
    @isTest
    static void testValidatePassager_MissingCIN() {
        Map<String, Object> data = new Map<String, Object>{
            'Name__c' => 'Jean',
            'CIN__c' => '',
            'Civilite__c' => 'Mr'
        };
        
        Test.startTest();
        try {
            EM001_Passager.validatePassager(data);
            System.assert(false, 'Doit lever une exception');
        } catch (Exception e) {
            System.debug('=== TEST 3 DIAGNOSTIC ===');
            System.debug('Exception TYPE: ' + e.getTypeName());
            System.debug('Exception MESSAGE: ' + e.getMessage());
            System.debug('Exception STACK: ' + e.getStackTraceString());
            System.assert(true, 'Exception levée: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    // ===== TEST 4: DIAGNOSTIC =====
    @isTest
    static void testValidatePassager_MissingCivilite() {
        Map<String, Object> data = new Map<String, Object>{
            'Name__c' => 'Jean',
            'CIN__c' => 'CIN123456',
            'Civilite__c' => ''
        };
        
        Test.startTest();
        try {
            EM001_Passager.validatePassager(data);
            System.assert(false, 'Doit lever une exception');
        } catch (Exception e) {
            System.debug('=== TEST 4 DIAGNOSTIC ===');
            System.debug('Exception TYPE: ' + e.getTypeName());
            System.debug('Exception MESSAGE: ' + e.getMessage());
            System.debug('Exception STACK: ' + e.getStackTraceString());
            System.assert(true, 'Exception levée: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidatePassagers_MultipleValid() {
        List<Map<String, Object>> dataList = new List<Map<String, Object>>{
            new Map<String, Object>{'Name__c' => 'Jean', 'CIN__c' => 'CIN1', 'Civilite__c' => 'Mr'},
            new Map<String, Object>{'Name__c' => 'Marie', 'CIN__c' => 'CIN2', 'Civilite__c' => 'Mme'},
            new Map<String, Object>{'Name__c' => 'Ahmed', 'CIN__c' => 'CIN3', 'Civilite__c' => 'Mr'}
        };
        
        Test.startTest();
        try {
            EM001_Passager.validatePassagers(dataList);
            System.assert(true);
        } catch (Exception e) {
            System.assert(false, e.getMessage());
        }
        Test.stopTest();
    }
    
    // ===== TEST 6: DIAGNOSTIC =====
    @isTest
    static void testValidatePassagers_SecondInvalid() {
        List<Map<String, Object>> dataList = new List<Map<String, Object>>{
            new Map<String, Object>{'Name__c' => 'Jean', 'CIN__c' => 'CIN1', 'Civilite__c' => 'Mr'},
            new Map<String, Object>{'Name__c' => '', 'CIN__c' => 'CIN2', 'Civilite__c' => 'Mme'},
            new Map<String, Object>{'Name__c' => 'Ahmed', 'CIN__c' => 'CIN3', 'Civilite__c' => 'Mr'}
        };
        
        Test.startTest();
        try {
            EM001_Passager.validatePassagers(dataList);
            System.assert(false, 'Doit lever une exception');
        } catch (Exception e) {
            System.debug('=== TEST 6 DIAGNOSTIC ===');
            System.debug('Exception TYPE: ' + e.getTypeName());
            System.debug('Exception MESSAGE: ' + e.getMessage());
            System.debug('Exception STACK: ' + e.getStackTraceString());
            System.assert(true, 'Exception levée: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCheckDuplicateCIN_NoDuplicate() {
        Case caseRecord = [SELECT Id FROM Case LIMIT 1];
        String uniqueCIN = 'CIN_UNIQUE_' + System.currentTimeMillis();
        
        Test.startTest();
        try {
            EM001_Passager.checkDuplicateCIN(uniqueCIN, caseRecord.Id);
            System.assert(true);
        } catch (Exception e) {
            System.assert(false, e.getMessage());
        }
        Test.stopTest();
    }
    
    // ===== TEST 8: DIAGNOSTIC =====
    @isTest
    static void testCheckDuplicateCIN_WithDuplicate() {
        Case caseRecord = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        try {
            EM001_Passager.checkDuplicateCIN('CIN_EXISTING_12345', caseRecord.Id);
            System.assert(false, 'Doit lever une exception');
        } catch (Exception e) {
            System.debug('=== TEST 8 DIAGNOSTIC ===');
            System.debug('Exception TYPE: ' + e.getTypeName());
            System.debug('Exception MESSAGE: ' + e.getMessage());
            System.debug('Exception STACK: ' + e.getStackTraceString());
            System.assert(true, 'Exception levée: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testMapDataToPassager() {
        Case caseRecord = [SELECT Id FROM Case LIMIT 1];
        Account compte = [SELECT Id FROM Account LIMIT 1];
        
        Map<String, Object> data = new Map<String, Object>{
            'Name__c' => 'Jean Dupont',
            'CIN__c' => 'CIN123456',
            'Civilite__c' => 'Mr',
            'Pays__c' => 'Maroc',
            'Ville__c' => 'Casablanca',
            'Email__c' => 'jean@test.com'
        };
        
        Test.startTest();
        Passager__c p = EM001_Passager.mapDataToPassager(data, caseRecord.Id, compte.Id);
        Test.stopTest();
        
        System.assertEquals('Jean Dupont', p.Name__c);
        System.assertEquals('CIN123456', p.CIN__c);
        System.assertEquals('Mr', p.Civilite__c);
        System.assertEquals('Maroc', p.Pays__c);
    }
    
    @isTest
    static void testMapDataToPassager_WithDate() {
        Case caseRecord = [SELECT Id FROM Case LIMIT 1];
        Account compte = [SELECT Id FROM Account LIMIT 1];
        
        Map<String, Object> data = new Map<String, Object>{
            'Name__c' => 'Jean',
            'CIN__c' => 'CIN123',
            'Civilite__c' => 'Mr',
            'BirthDay__c' => '1990-05-15'
        };
        
        Test.startTest();
        Passager__c p = EM001_Passager.mapDataToPassager(data, caseRecord.Id, compte.Id);
        Test.stopTest();
        
        System.assertEquals(Date.valueOf('1990-05-15'), p.BirthDay__c);
    }
    
    @isTest
    static void testInsertPassagers() {
        Case caseRecord = [SELECT Id FROM Case LIMIT 1];
        Account compte = [SELECT Id FROM Account LIMIT 1];
        
        DA_TestBuilderFactory factory = new DA_TestBuilderFactory()
            .withPassengers(3, caseRecord.Id, compte.Id, null);
        
        List<Passager__c> inserted = factory.getPassengers();
        
        Test.startTest();
        Test.stopTest();
        
        System.assertEquals(3, inserted.size());
    }
    
    @isTest
    static void testDeletePassagerById() {
        Case caseRecord = [SELECT Id FROM Case LIMIT 1];
        Account compte = [SELECT Id FROM Account LIMIT 1];
        
        DA_TestBuilderFactory factory = new DA_TestBuilderFactory()
            .withPassengers(1, caseRecord.Id, compte.Id, null);
        
        Passager__c p = factory.getPassengers()[0];
        Id passagerId = p.Id;
        
        Test.startTest();
        EM001_Passager.deletePassagerById(passagerId);
        Test.stopTest();
        
        List<Passager__c> remaining = [SELECT Id FROM Passager__c WHERE Id = :passagerId];
        System.assertEquals(0, remaining.size());
    }
    
    @isTest
    static void testMapOtherPartyToPassager() {
        Case caseRecord = [SELECT Id FROM Case LIMIT 1];
        Account compte = [SELECT Id FROM Account LIMIT 1];
        
        Map<String, Object> data = new Map<String, Object>{
            'Nom__c' => 'Dupont',
            'Prenom__c' => 'Pierre',
            'CIN__c' => 'CIN999',
            'Civilite__c' => 'Mr'
        };
        
        Test.startTest();
        Passager__c p = EM001_Passager.mapOtherPartyToPassager(data, caseRecord.Id, compte.Id);
        Test.stopTest();
        
        System.assertEquals('Dupont Pierre', p.Name__c);
        System.assertEquals('Autres partie', p.Roles__c);
    }
    
    // ===== TEST 14: DIAGNOSTIC =====
    @isTest
    static void testCheckDuplicateCINs_DuplicateInList() {
        Case caseRecord = [SELECT Id FROM Case LIMIT 1];
        
        List<Map<String, Object>> dataList = new List<Map<String, Object>>{
            new Map<String, Object>{'CIN__c' => 'CIN_DUP_1'},
            new Map<String, Object>{'CIN__c' => 'CIN_DUP_1'}
        };
        
        Test.startTest();
        try {
            EM001_Passager.checkDuplicateCINs(dataList, caseRecord.Id);
            System.assert(false, 'Doit lever une exception');
        } catch (Exception e) {
            System.debug('=== TEST 14 DIAGNOSTIC ===');
            System.debug('Exception TYPE: ' + e.getTypeName());
            System.debug('Exception MESSAGE: ' + e.getMessage());
            System.debug('Exception STACK: ' + e.getStackTraceString());
            System.assert(true, 'Exception levée: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCheckDuplicateCINs_NoDuplicate() {
        Case caseRecord = [SELECT Id FROM Case LIMIT 1];
        
        List<Map<String, Object>> dataList = new List<Map<String, Object>>{
            new Map<String, Object>{'CIN__c' => 'CIN_UNIQUE_1'},
            new Map<String, Object>{'CIN__c' => 'CIN_UNIQUE_2'},
            new Map<String, Object>{'CIN__c' => 'CIN_UNIQUE_3'}
        };
        
        Test.startTest();
        try {
            EM001_Passager.checkDuplicateCINs(dataList, caseRecord.Id);
            System.assert(true);
        } catch (Exception e) {
            System.assert(false, e.getMessage());
        }
        Test.stopTest();
    }

}