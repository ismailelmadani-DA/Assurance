/**
 * @description  : Classe de test pour DA_lwc024_ClaimCompactLayoutController
 * @author       : D&A Technologies
 * @group        : Tests
 **/
@isTest
private class DA_lwc024_TestClaimCompactLayout {

    // ============================================================
    // SETUP - Construction des données de test
    // ============================================================
    
    private static DA_TestBuilderFactory setupCompleteClaimData() {
        DA_TestBuilderFactory builder = new DA_TestBuilderFactory()
            .withAccount()
            .withPolicy()
            .withVehicle();
            
        Account acc = builder.getAccounts()[0];
        InsurancePolicy__c pol = builder.getPolicies()[0];
        Vehicule__c veh = builder.getVehicles()[0];
        
        // Création d'un événement associé
        Evenement__c evenement = DA_TestDataFactory.createTestEvenement(
            new Map<String, Object>{
                'Libelle__c' => 'Test Event',
                'Categorie__c' => 'Catastrophe naturelle',
                'Type__c' => 'Inondation'
            }
        );
        insert evenement;
        
        // Création du Case
        builder.withCases(1, acc.Id, pol.Id, 'Test Claim Case', null);
        Case caseRecord = builder.getCases()[0];
        
        // Création du Claim
        builder.withClaims(1, caseRecord.Id,
            new Map<String, Object>{
                'Account__c' => acc.Id,
                'PolicyNumber__c' => pol.Id,
                'Vehicule__c' => veh.Id,
                'Case__c' => caseRecord.Id,
                'EvenementAssocie__c' => evenement.Id,
                'Status__c' => 'En cours de traitement'
            }
        );
        
        return builder;
    }
    
    private static DA_TestBuilderFactory setupMinimalClaimData() {
        DA_TestBuilderFactory builder = new DA_TestBuilderFactory()
            .withAccount()
            .withPolicy();
            
        Account acc = builder.getAccounts()[0];
        InsurancePolicy__c pol = builder.getPolicies()[0];
        
        builder.withCases(1, acc.Id, pol.Id, 'Minimal Case', null);
        Case caseRecord = builder.getCases()[0];
        
        builder.withClaims(1, caseRecord.Id,
            new Map<String, Object>{
                'Status__c' => 'En cours de traitement'
            }
        );
        
        return builder;
    }
    
    // ============================================================
    // TESTS
    // ============================================================
    
    @isTest
    static void testGetClaimData_Success() {
        DA_TestBuilderFactory builder = setupCompleteClaimData();
        Claim__c claim = builder.getClaims()[0];
        
        Test.startTest();
        DA_lwc024_ClaimCompactLayoutController.ClaimData result = 
            DA_lwc024_ClaimCompactLayoutController.getClaimData(claim.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.claimName);
        System.assertEquals(5, result.fields.size());
    }
    
    @isTest
    static void testGetClaimData_LookupField_Account() {
        DA_TestBuilderFactory builder = setupCompleteClaimData();
        Claim__c claim = builder.getClaims()[0];
        Account acc = builder.getAccounts()[0];
        
        Test.startTest();
        DA_lwc024_ClaimCompactLayoutController.ClaimData result = 
            DA_lwc024_ClaimCompactLayoutController.getClaimData(claim.Id);
        Test.stopTest();
        
        Boolean foundField = false;
        for (DA_lwc024_ClaimCompactLayoutController.FieldItem field : result.fields) {
            if (field.fieldPath == 'Account__c') {
                foundField = true;
                System.assertEquals('Assuré', field.label);
                System.assertEquals(true, field.isLookup);
                System.assertEquals(acc.Id, field.lookupId);
                break;
            }
        }
        System.assertEquals(true, foundField);
    }
    
    @isTest
    static void testGetClaimData_LookupField_Vehicule() {
        DA_TestBuilderFactory builder = setupCompleteClaimData();
        Claim__c claim = builder.getClaims()[0];
        Vehicule__c veh = builder.getVehicles()[0];
        
        Test.startTest();
        DA_lwc024_ClaimCompactLayoutController.ClaimData result = 
            DA_lwc024_ClaimCompactLayoutController.getClaimData(claim.Id);
        Test.stopTest();
        
        Boolean foundField = false;
        for (DA_lwc024_ClaimCompactLayoutController.FieldItem field : result.fields) {
            if (field.fieldPath == 'Vehicule__c') {
                foundField = true;
                System.assertEquals('Véhicule', field.label);
                System.assertEquals(true, field.isLookup);
                System.assertEquals(veh.Id, field.lookupId);
                System.assertEquals(veh.RegistrationNumber__c, field.displayValue);
                break;
            }
        }
        System.assertEquals(true, foundField);
    }
    
    @isTest
    static void testGetClaimData_LookupField_PolicyNumber() {
        DA_TestBuilderFactory builder = setupCompleteClaimData();
        Claim__c claim = builder.getClaims()[0];
        InsurancePolicy__c pol = builder.getPolicies()[0];
        
        Test.startTest();
        DA_lwc024_ClaimCompactLayoutController.ClaimData result = 
            DA_lwc024_ClaimCompactLayoutController.getClaimData(claim.Id);
        Test.stopTest();
        
        Boolean foundField = false;
        for (DA_lwc024_ClaimCompactLayoutController.FieldItem field : result.fields) {
            if (field.fieldPath == 'PolicyNumber__c') {
                foundField = true;
                System.assertEquals('Policy Number', field.label);
                System.assertEquals(true, field.isLookup);
                System.assertEquals(pol.Id, field.lookupId);
                System.assertEquals(pol.PolicyNumber__c, field.displayValue);
                break;
            }
        }
        System.assertEquals(true, foundField);
    }
    
    @isTest
    static void testGetClaimData_DateTimeField_DateOfOccurrence() {
        DA_TestBuilderFactory builder = setupCompleteClaimData();
        Claim__c claim = builder.getClaims()[0];
        
        Test.startTest();
        DA_lwc024_ClaimCompactLayoutController.ClaimData result = 
            DA_lwc024_ClaimCompactLayoutController.getClaimData(claim.Id);
        Test.stopTest();
        
        Boolean foundField = false;
        for (DA_lwc024_ClaimCompactLayoutController.FieldItem field : result.fields) {
            if (field.fieldPath == 'DateOfOccurrence__c') {
                foundField = true;
                System.assertEquals('Date de survenance', field.label);
                System.assertEquals(true, field.isDateTime);
                break;
            }
        }
        System.assertEquals(true, foundField);
    }
    
    @isTest
    static void testGetClaimData_LookupField_EvenementAssocie() {
        DA_TestBuilderFactory builder = setupCompleteClaimData();
        Claim__c claim = builder.getClaims()[0];
        
        // Récupérer l'événement directement via SOQL
        Evenement__c evenement = [SELECT Id, Libelle__c FROM Evenement__c WHERE Libelle__c LIKE 'Test Event%' LIMIT 1];
        
        Test.startTest();
        DA_lwc024_ClaimCompactLayoutController.ClaimData result = 
            DA_lwc024_ClaimCompactLayoutController.getClaimData(claim.Id);
        Test.stopTest();
        
        Boolean foundField = false;
        for (DA_lwc024_ClaimCompactLayoutController.FieldItem field : result.fields) {
            if (field.fieldPath == 'EvenementAssocie__c') {
                foundField = true;
                System.assertEquals('Événement associé', field.label);
                System.assertEquals(true, field.isLookup);
                System.assertEquals(evenement.Id, field.lookupId);
                System.assertEquals(evenement.Libelle__c, field.displayValue);
                break;
            }
        }
        System.assertEquals(true, foundField);
    }
    
    @isTest
    static void testGetClaimData_WithNullRelations_NoException() {
        DA_TestBuilderFactory builder = setupMinimalClaimData();
        Claim__c claim = builder.getClaims()[0];
        
        Test.startTest();
        DA_lwc024_ClaimCompactLayoutController.ClaimData result = 
            DA_lwc024_ClaimCompactLayoutController.getClaimData(claim.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.claimName);
        
        boolean hasAccountField = false;
        for (DA_lwc024_ClaimCompactLayoutController.FieldItem field : result.fields) {
            if (field.fieldPath == 'Account__c') {
                hasAccountField = true;
                break;
            }
        }
        System.assertEquals(true, hasAccountField);
    }
    
    @isTest
    static void testGetClaimData_NullRecordId_ThrowsException() {
        Test.startTest();
        try {
            DA_lwc024_ClaimCompactLayoutController.getClaimData(null);
            System.assert(false, 'Une exception doit être levée');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetClaimData_InvalidRecordId_ThrowsException() {
        Account fakeAccount = DA_TestDataFactory.createTestAccount(null);
        insert fakeAccount;
        
        Test.startTest();
        try {
            DA_lwc024_ClaimCompactLayoutController.getClaimData(fakeAccount.Id);
            System.assert(false, 'Une exception doit être levée');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetClaimData_FieldOrder_RespectsFieldSet() {
        DA_TestBuilderFactory builder = setupCompleteClaimData();
        Claim__c claim = builder.getClaims()[0];
        
        Test.startTest();
        DA_lwc024_ClaimCompactLayoutController.ClaimData result = 
            DA_lwc024_ClaimCompactLayoutController.getClaimData(claim.Id);
        Test.stopTest();
        
        List<String> expectedOrder = new List<String>{
            'Account__c', 'Vehicule__c', 'PolicyNumber__c',
            'DateOfOccurrence__c', 'EvenementAssocie__c'
        };
        
        System.assertEquals(5, result.fields.size());
        for (Integer i = 0; i < result.fields.size(); i++) {
            System.assertEquals(expectedOrder[i], result.fields[i].fieldPath);
        }
    }
    
    @isTest
    static void testGetClaimData_RunAsStandardUser() {
        DA_TestBuilderFactory builder = setupCompleteClaimData();
        Claim__c claim = builder.getClaims()[0];
        
        builder.withUser('stdusr', 'StandardUser');
        User stdUser = builder.getUser('stdusr');
        
        DA_lwc024_ClaimCompactLayoutController.ClaimData result;
        Test.startTest();
        System.runAs(stdUser) {
            result = DA_lwc024_ClaimCompactLayoutController.getClaimData(claim.Id);
        }
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.claimName);
        System.assertEquals(5, result.fields.size());
    }
    
    @isTest
    static void testGetClaimData_DateFormat_ValidISOFormat() {
        DA_TestBuilderFactory builder = setupCompleteClaimData();
        Claim__c claim = builder.getClaims()[0];
        
        Test.startTest();
        DA_lwc024_ClaimCompactLayoutController.ClaimData result = 
            DA_lwc024_ClaimCompactLayoutController.getClaimData(claim.Id);
        Test.stopTest();
        
        for (DA_lwc024_ClaimCompactLayoutController.FieldItem field : result.fields) {
            if (field.fieldPath == 'DateOfOccurrence__c') {
                if (field.displayValue != null && field.displayValue != '') {
                    System.assert(field.displayValue.contains('T') || field.displayValue.contains('-'));
                }
                break;
            }
        }
    }
}