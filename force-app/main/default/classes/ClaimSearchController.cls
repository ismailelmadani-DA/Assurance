public with sharing class ClaimSearchController {
   
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> searchPolicies(
        String policyNumber, 
        String registrationNumber, 
        String attestationNumber,  
        String chassisNumber
    ) {
        String query = 'SELECT Id, PolicyNumber__c, AccountName__r.Name, PolicyCategory__c, Status__c, ' +
                       'SituationPolice__c, SituationPrime__c, DateEffet__c, DateExpiration__c, QuotePartCoass__c, ' +
                       '(SELECT Id, RegistrationNumber__c, ChassisNumber__c, Brand__c, AttestationNumber__c, DateOfFirstRegistration__c FROM vehicle__r LIMIT 1) ' +
                       'FROM InsurancePolicy__c WHERE ';
        
        List<String> conditions = new List<String>();

        if (String.isNotBlank(policyNumber)) {
            conditions.add('PolicyNumber__c = :policyNumber');
        }

        if (String.isNotBlank(registrationNumber) || String.isNotBlank(chassisNumber)) {
            String vehicleFilter = 'Id IN (SELECT InsurancePolicy__c FROM Vehicule__c WHERE ';
            List<String> vConditions = new List<String>();
            if (String.isNotBlank(registrationNumber)) vConditions.add('RegistrationNumber__c = :registrationNumber');
            if (String.isNotBlank(chassisNumber)) vConditions.add('ChassisNumber__c = :chassisNumber');
            vehicleFilter += String.join(vConditions, ' AND ') + ')';
            conditions.add(vehicleFilter);
        }

        if (String.isNotBlank(attestationNumber)) {
            conditions.add('AttestationNumber__c = :attestationNumber');
        }

        if (conditions.isEmpty()) return new List<Map<String, Object>>();
        
        query += String.join(conditions, ' AND ');

        try {
            List<InsurancePolicy__c> results = Database.query(query);
            return formatResults(results);
        } catch (Exception e) {
            throw new AuraHandledException('Erreur de recherche : ' + e.getMessage());
        }
    }

    private static List<Map<String, Object>> formatResults(List<InsurancePolicy__c> policies) {
        List<Map<String, Object>> formatted = new List<Map<String, Object>>();
        for(InsurancePolicy__c ip : policies) {
            Map<String, Object> row = new Map<String, Object>{
                'Id' => ip.Id,
                'PolicyNumber' => ip.PolicyNumber__c,
                'InsuredName' => ip.AccountName__r != null ? ip.AccountName__r.Name : 'N/A',
                'Category' => ip.PolicyCategory__c,
                'Status' => ip.Status__c,
                'SituationPolice' => ip.SituationPolice__c,
                'SituationPrime' => ip.SituationPrime__c,
                'DateEffet' => ip.DateEffet__c,
                'DateExpiration' => ip.DateExpiration__c,
                'QuotePart' => ip.QuotePartCoass__c
            };

            List<SObject> vehicles = ip.getSObjects('vehicle__r');
            if (vehicles != null && !vehicles.isEmpty()) {
                SObject v = vehicles[0];
                row.put('vehicleId', v.Id);
                row.put('RegistrationNumber', v.get('RegistrationNumber__c'));
                row.put('ChassisNumber', v.get('ChassisNumber__c'));
                row.put('Brand', v.get('Brand__c'));
                row.put('AttestationNumber', v.get('AttestationNumber__c'));
                row.put('DateMiseCirculation', v.get('DateOfFirstRegistration__c'));
            }
            formatted.add(row);
        }
        return formatted;
    }

    
    @AuraEnabled
    public static Map<String, String> createCase(String payload) {
        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(payload);
            Id policyId = (Id)data.get('policyId');
            Boolean insuredIsContact = false;
            if (data.get('insuredIsContact') != null) {
                insuredIsContact = (Boolean)data.get('insuredIsContact');
            }
            Case newCase = new Case();
            newCase.Police__c = policyId;
            newCase.Vehicule__c = (Id)data.get('vehicleId');
            
            newCase.CountryOfOccurrence__c = (String)data.get('country');
            newCase.CityOfOccurrence__c = (String)data.get('city');
            newCase.AddressOfOccurrence__c = (String)data.get('address');
            newCase.Commentaire__c = (String)data.get('commentaire');
            
            if (data.get('dateSurvenance') != null && String.isNotBlank((String)data.get('dateSurvenance'))) {
                newCase.DateOfOccurrence__c = Date.valueOf((String)data.get('dateSurvenance'));
            }

            newCase.Claimant__c = (String)data.get('declarant');
            
            newCase.IncidentReport__c = (String)data.get('pvConstat');
            
            if (data.get('dateDepot') != null && String.isNotBlank((String)data.get('dateDepot'))) {
                newCase.DateOfDeclarationSubmission__c = Date.valueOf((String)data.get('dateDepot'));
            }

            Id finalAccountId;

            if (insuredIsContact) {

                InsurancePolicy__c policy = [SELECT AccountName__c FROM InsurancePolicy__c WHERE Id = :policyId LIMIT 1];
                finalAccountId = policy.AccountName__c;

                if (finalAccountId != null) {
                    Account accUpdate = new Account(Id = finalAccountId);
                    accUpdate.Phone = (String)data.get('telContact');
                    accUpdate.Email__c = (String)data.get('mailContact');
                    accUpdate.MoyenNotification__c = (String)data.get('moyenNotification'); 
                    update accUpdate;
                }
            } else {
                Account newAcc = new Account();
                newAcc.Name = (String)data.get('nomContact'); 
                newAcc.Nom__c = (String)data.get('nomContact');
                newAcc.Phone = (String)data.get('telContact');
                newAcc.Email__c = (String)data.get('mailContact');
                newAcc.MoyenNotification__c = (String)data.get('moyenNotification'); 
                
                insert newAcc;
                finalAccountId = newAcc.Id;
            }

            newCase.AccountId = finalAccountId; 

            newCase.Status = 'En cours';
            newCase.Origin = 'Gestionnaire';
            newCase.DateOfDeclarationCreation__c = Date.today();
            Id declarationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Declaration').getRecordTypeId();
            newCase.RecordTypeId = declarationRecordTypeId;

            insert newCase;

            Case insertedCase = [SELECT Id, CaseNumber FROM Case WHERE Id = :newCase.Id LIMIT 1];
            
            return new Map<String, String>{
                'id' => insertedCase.Id,
                'caseNumber' => insertedCase.CaseNumber
            };

        } catch (Exception e) {
            throw new AuraHandledException('Erreur Apex : ' + e.getMessage());
        }
    }

   
    @AuraEnabled(cacheable=true)
    public static Account getInsuredDetails(Id policyId) {
        try {
            InsurancePolicy__c policy = [SELECT AccountName__c FROM InsurancePolicy__c WHERE Id = :policyId LIMIT 1];
            if (policy.AccountName__c == null) return null;

            return [SELECT Id, Name, Civility__c, Pays__c, Ville__c, Adresse__c, 
                           DateDeNaissance__c, Origine_du_permis__c, TypeOfLicense__c, 
                           LicenseNumber__c, DateOfIssue__c, ConditionOfPerson__c, MaritalStatus__c,
                           CIN__c FROM Account WHERE Id = :policy.AccountName__c LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException('Erreur récupération assuré : ' + e.getMessage());
        }
    }

    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPicklistValues(String objectName, String fieldName) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            Schema.DescribeFieldResult fieldDescribe = objType.getDescribe().fields.getMap().get(fieldName).getDescribe();
            for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
                if (entry.isActive()) {
                    options.add(new Map<String, String>{'label' => entry.getLabel(), 'value' => entry.getValue()});
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Erreur picklist ' + fieldName + ' : ' + e.getMessage());
        }
        return options;
    }

   
  
    @AuraEnabled
    public static void savePassengers(Id caseId, String passengersJson) {
        try {
            List<Case> cases = [SELECT Id, Vehicule__c FROM Case WHERE Id = :caseId LIMIT 1];
            if (cases.isEmpty()) {
                throw new AuraHandledException('Le dossier (Case) est introuvable.');
            }

            List<Object> passList = (List<Object>) JSON.deserializeUntyped(passengersJson);
            List<Passager__c> toUpsert = new List<Passager__c>();

          

            List<Passager__c> existingPassagers = [SELECT Id, CIN__c, Name FROM Passager__c WHERE Case__c = :caseId AND Roles__c = 'Passager assuré'];
            Map<String, Id> passagerIdMap = new Map<String, Id>();
            for(Passager__c ep : existingPassagers) {
                if (String.isNotBlank(ep.CIN__c)) passagerIdMap.put(ep.CIN__c, ep.Id);
                else passagerIdMap.put(ep.Name, ep.Id);
            }

            // =========================================================
            // ÉTAPE B : GESTION INTELLIGENTE DES COMPTES (Accounts)
            // =========================================================
            Set<String> cins = new Set<String>();
            Set<String> names = new Set<String>();
            
            for (Object obj : passList) {
                Map<String, Object> p = (Map<String, Object>) obj;
                if (p.get('CIN__c') != null) cins.add((String)p.get('CIN__c'));
                
                String fullName = (p.get('Nom__c') != null && p.get('Prenom__c') != null) ? 
                                  (String)p.get('Nom__c') + ' ' + (String)p.get('Prenom__c') : 
                                  (String)p.get('Name__c');
                if(fullName != null) names.add(fullName);
            }

            List<Account> existingAccounts = [SELECT Id, CIN__c, Name FROM Account WHERE CIN__c IN :cins OR Name IN :names];
            Map<String, Account> accountMap = new Map<String, Account>();
            for (Account acc : existingAccounts) {
                if (String.isNotBlank(acc.CIN__c)) accountMap.put(acc.CIN__c, acc);
                accountMap.put(acc.Name, acc);
            }

            List<Account> accountsToInsert = new List<Account>();
            for (Object obj : passList) {
                Map<String, Object> p = (Map<String, Object>) obj;
                String cin = (String)p.get('CIN__c');
                String fullName = (p.get('Nom__c') != null && p.get('Prenom__c') != null) ? 
                                  (String)p.get('Nom__c') + ' ' + (String)p.get('Prenom__c') : 
                                  (String)p.get('Name__c');

                if (String.isNotBlank(cin) && !accountMap.containsKey(cin)) {
                    Account newAcc = new Account(Name = fullName, CIN__c = cin);
                    if (p.get('Telephone__c') != null) newAcc.Phone = String.valueOf(p.get('Telephone__c'));
                    if (p.get('Email__c') != null) newAcc.Email__c = (String)p.get('Email__c');
                    accountsToInsert.add(newAcc);
                    accountMap.put(cin, newAcc); 
                } else if (String.isBlank(cin) && String.isNotBlank(fullName) && !accountMap.containsKey(fullName)) {
                    Account newAcc = new Account(Name = fullName);
                    if (p.get('Telephone__c') != null) newAcc.Phone = String.valueOf(p.get('Telephone__c'));
                    if (p.get('Email__c') != null) newAcc.Email__c = (String)p.get('Email__c');
                    accountsToInsert.add(newAcc);
                    accountMap.put(fullName, newAcc);
                }
            }
            if (!accountsToInsert.isEmpty()) {
                insert accountsToInsert; 
            }

          

            for (Object obj : passList) {
                Map<String, Object> p = (Map<String, Object>) obj;
                Passager__c newP = new Passager__c();
                
                newP.Case__c = caseId;
                newP.Vehicule__c = cases[0].Vehicule__c;
                newP.Roles__c = 'Passager assuré';

                String fullName = (p.get('Nom__c') != null && p.get('Prenom__c') != null) ? 
                                  (String)p.get('Nom__c') + ' ' + (String)p.get('Prenom__c') : 
                                  (String)p.get('Name__c');
                if (fullName == null && p.get('Name') != null) fullName = (String)p.get('Name');
                
                newP.Name = fullName != null ? fullName : 'Passager Inconnu';
                newP.CIN__c = (String)p.get('CIN__c');

                if (p.get('Id') != null && String.isNotBlank((String)p.get('Id'))) {
                    newP.Id = (Id)p.get('Id'); 
                } else if (String.isNotBlank(newP.CIN__c) && passagerIdMap.containsKey(newP.CIN__c)) {
                    newP.Id = passagerIdMap.get(newP.CIN__c); 
                } else if (passagerIdMap.containsKey(newP.Name)) {
                    newP.Id = passagerIdMap.get(newP.Name); 
                }

                if (String.isNotBlank(newP.CIN__c) && accountMap.containsKey(newP.CIN__c)) {
                    newP.Compte__c = accountMap.get(newP.CIN__c).Id;
                } else if (accountMap.containsKey(newP.Name)) {
                    newP.Compte__c = accountMap.get(newP.Name).Id;
                }

                newP.Civilite__c = (String)p.get('Civilite__c');
                if(p.get('BirthDay__c') != null && String.isNotBlank((String)p.get('BirthDay__c'))) {
                    newP.BirthDay__c = Date.valueOf((String)p.get('BirthDay__c'));
                }
                newP.Pays__c = (String)p.get('Pays__c');
                newP.Ville__c = (String)p.get('Ville__c');
                newP.Adresse__c = (String)p.get('Adresse__c');
                newP.StateOfPerson__c = (String)p.get('StateOfPerson__c');
                newP.MaritalStatus__c = (String)p.get('MaritalStatus__c');
                newP.MoyenNotification__c = (String)p.get('MoyenNotification__c'); 

                if (p.get('Telephone__c') != null) newP.Telephone__c = String.valueOf(p.get('Telephone__c'));
                else if (p.get('Telephone') != null) newP.Telephone__c = String.valueOf(p.get('Telephone'));
                
                if (p.get('Email__c') != null) newP.Email__c = (String)p.get('Email__c');

                if (p.get('CompagnieAdverse__c') != null && String.isNotBlank((String)p.get('CompagnieAdverse__c'))) { 
                    newP.Account__c = (Id)p.get('CompagnieAdverse__c'); 
                }

                toUpsert.add(newP);
            }

            if (!toUpsert.isEmpty()) {
                upsert toUpsert; 
            }
        } catch (Exception e) {
            throw new AuraHandledException('Erreur passagers : ' + e.getMessage() + ' Ligne: ' + e.getLineNumber());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getTypeDocumentsByReportoire() {
        Map<String, List<String>> result = new Map<String, List<String>>();
        result.put('Pièces d’identité', new List<String>{'CIN', 'Passeport', 'Permis de conduire'});
        result.put('Documents Véhicule', new List<String>{'Carte Grise', 'Attestation d’assurance', 'Visite Technique'});
        result.put('Documents Sinistre', new List<String>{'Constat Amiable', 'PV de Police', 'Rapport Expertise'});
        return result;
    }

    @AuraEnabled
    public static String saveDocumentLocally(Map<String, Object> fileData) {
        try {
            Map<String, Object> docMap = (Map<String, Object>)fileData.get('document');
            Id caseId = (Id)fileData.get('caseId');

            Document__c doc = new Document__c();
            doc.RegistrationNumber__c = (String)docMap.get('RegistrationNumber__c');
            doc.Police__c = (Id)docMap.get('Police__c');
            doc.Directory__c = (String)docMap.get('Directory__c');
            doc.Type_de_document__c = (String)docMap.get('Type_de_document__c');
            doc.dateOfReceipt__c = Date.today();
            doc.Statut__c = 'Validé';
            insert doc;
            
            return 'Ok';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateCaseRecord(Id caseId, Map<String, Object> caseData) {
        try {
            if (caseId == null) {
                throw new AuraHandledException('L\'identifiant de la déclaration (Case) est manquant.');
            }

            Case caseToUpdate = new Case(Id = caseId);
            
            if (caseData.containsKey('CausesAndCircumstances__c')) {
                caseToUpdate.CausesAndCircumstances__c = (String)caseData.get('CausesAndCircumstances__c');
            }
            if (caseData.containsKey('TriggeringEventOfClaim__c')) {
                caseToUpdate.TriggeringEventOfClaim__c = (String)caseData.get('TriggeringEventOfClaim__c');
            }
            if (caseData.containsKey('CausesOfClaim__c')) {
                caseToUpdate.CausesOfClaim__c = (String)caseData.get('CausesOfClaim__c');
            }
            if (caseData.containsKey('OpposingParty__c')) {
                caseToUpdate.OpposingParty__c = (String)caseData.get('OpposingParty__c');
            }
            
            if (caseData.get('NumberOfVehiclesInvolved__c') != null) {
                String val = String.valueOf(caseData.get('NumberOfVehiclesInvolved__c'));
                if (String.isNotBlank(val)) {
                    caseToUpdate.NumberOfVehiclesInvolved__c = Decimal.valueOf(val);
                }
            }

            if (caseData.get('AnyDamage__c') != null) {
                caseToUpdate.AnyDamage__c = Boolean.valueOf(caseData.get('AnyDamage__c'));
            }
            if (caseData.containsKey('PointsDeChoc__c')) {
                caseToUpdate.PointsDeChoc__c = (String)caseData.get('PointsDeChoc__c');
            }
            if (caseData.containsKey('PrecisionsDommages__c')) {
                caseToUpdate.PrecisionsDommages__c = (String)caseData.get('PrecisionsDommages__c');
            }

            update caseToUpdate;

        } catch (Exception e) {
            throw new AuraHandledException('Erreur Apex (Ligne ' + e.getLineNumber() + ') : ' + e.getMessage());
        }
    }
  
   @AuraEnabled
    public static void saveAdverseVehicle(Id caseId, String adverseDataJson) {
        try {
            if (caseId == null || String.isBlank(adverseDataJson)) {
                throw new AuraHandledException('Données manquantes pour la sauvegarde du véhicule adverse.');
            }

           
            Case currentCase = [SELECT Id, AccountId FROM Case WHERE Id = :caseId LIMIT 1];
            Id accountIdToUse = currentCase.AccountId;
            
            if (accountIdToUse == null) {
                Account defaultAcc = new Account(Name = 'Dossier Sans Compte - Tiers Générique');
                insert defaultAcc;
                accountIdToUse = defaultAcc.Id;
                currentCase.AccountId = accountIdToUse;
                update currentCase;
            }

            List<Object> vehiclesList = (List<Object>) JSON.deserializeUntyped(adverseDataJson);
            List<VehicleCaseAssignment__c> assignmentsToInsert = new List<VehicleCaseAssignment__c>();
            List<Passager__c> passagersToInsert = new List<Passager__c>();
            
            String etatVehiculePourCase = null; 

            for (Object obj : vehiclesList) {
                Map<String, Object> v = (Map<String, Object>) obj;
                
                
                Id currentVehiculeId = (String)v.get('Vehicule__c');
                
                if (String.isBlank(currentVehiculeId)) {
                    Vehicule__c newCar = new Vehicule__c();
                    newCar.RegistrationNumber__c = (String)v.get('RegistrationNumber__c');
                    newCar.Brand__c = (String)v.get('Marque__c'); 
                    newCar.TypeVehicule__c = (String)v.get('TypeVehicule__c');
                    newCar.NbDeContratDAssurance__c = (String)v.get('Numéro_de_contrat__c');
                    newCar.isOpposingCar__c = true; 
                    
                    if (v.get('DateMiseEnCirculation__c') != null && String.isNotBlank((String)v.get('DateMiseEnCirculation__c'))) {
                        newCar.DateOfFirstRegistration__c = Date.valueOf((String)v.get('DateMiseEnCirculation__c'));
                    }
                    
                    insert newCar; 
                    currentVehiculeId = newCar.Id; 
                }

               

                VehicleCaseAssignment__c newAssignment = new VehicleCaseAssignment__c();
                newAssignment.Case__c = caseId;
                newAssignment.Vehicule__c = currentVehiculeId; 
                
                if (v.get('Adversaire_Assure__c') != null) {
                    newAssignment.AdversaireAssure__c = Boolean.valueOf((String)v.get('Adversaire_Assure__c'));
                }
                if (v.get('CompagnieAdverse__c') != null && String.isNotBlank((String)v.get('CompagnieAdverse__c'))) {
                    newAssignment.CompagnieAdverse__c = (Id)v.get('CompagnieAdverse__c');
                }
                if (v.get('NbDePassagerBlesses__c') != null && String.isNotBlank(String.valueOf(v.get('NbDePassagerBlesses__c')))) {
                    newAssignment.NbDePassagerBlesses__c = Integer.valueOf(v.get('NbDePassagerBlesses__c'));
                }
                if (etatVehiculePourCase == null) {
                    etatVehiculePourCase = (String)v.get('VehicleIsDamaged__c');
                }
                
                assignmentsToInsert.add(newAssignment);

                
                if (v.get('passengers') != null) {
                    List<Object> passListObj = (List<Object>) v.get('passengers');
                    
                    for (Object pObj : passListObj) {
                        Map<String, Object> pMap = (Map<String, Object>) pObj;
                        
                        Passager__c newPass = new Passager__c();
                        newPass.Case__c = caseId; 
                        newPass.Roles__c = 'Passager adverse'; 
                        newPass.Vehicule__c = currentVehiculeId; 
                        newPass.Compte__c = accountIdToUse; 
                        
                        newPass.Name = (String)pMap.get('Name__c'); 
                        
                        newPass.Civilite__c = (String)pMap.get('Civilite__c');
                        newPass.CIN__c = (String)pMap.get('CIN__c');
                        newPass.Pays__c = (String)pMap.get('Pays__c');
                        newPass.Adresse__c = (String)pMap.get('Adresse__c');
                        
                        if (pMap.get('BirthDay__c') != null && String.isNotBlank((String)pMap.get('BirthDay__c'))) {
                            newPass.BirthDay__c = Date.valueOf((String)pMap.get('BirthDay__c'));
                        }

                        newPass.MaritalStatus__c = (String)pMap.get('MaritalStatus__c');
                        newPass.Ville__c = (String)pMap.get('Ville__c');
                        newPass.StateOfPerson__c = (String)pMap.get('StateOfPerson__c');
                        
                        if (pMap.get('Telephone__c') != null) {
                            newPass.Telephone__c = String.valueOf(pMap.get('Telephone__c'));
                        } else if (pMap.get('Telephone') != null) {
                            newPass.Telephone__c = String.valueOf(pMap.get('Telephone'));
                        }
                        
                        if (pMap.get('Email__c') != null) {
                            newPass.Email__c = (String)pMap.get('Email__c');
                        }

                        passagersToInsert.add(newPass);
                    }
                }
            } 

            
            if (!assignmentsToInsert.isEmpty()) {
                insert assignmentsToInsert;
            }
            if (!passagersToInsert.isEmpty()) {
                insert passagersToInsert;
            }
            if (etatVehiculePourCase != null) {
                update new Case(Id = caseId, VehicleIsDamaged__c = etatVehiculePourCase);
            }

        } catch (Exception e) {
            throw new AuraHandledException('Erreur : ' + e.getMessage() + ' (Ligne ' + e.getLineNumber() + ')');
        }
    }

    @AuraEnabled
    public static void saveOtherParties(Id caseId, String partiesJson) {
        try {
            if (String.isBlank(partiesJson) || partiesJson == '[]') {
                return; 
            }

            Case currentCase = [SELECT Id, AccountId, Vehicule__c FROM Case WHERE Id = :caseId LIMIT 1];
            Id accountIdToUse = currentCase.AccountId;

            if (accountIdToUse == null) {
                Account defaultAcc = new Account(Name = 'Dossier Sans Compte - Tiers Générique');
                insert defaultAcc;
                accountIdToUse = defaultAcc.Id;
                
                currentCase.AccountId = accountIdToUse;
                update currentCase;
            }

            List<Object> partyList = (List<Object>) JSON.deserializeUntyped(partiesJson);
            List<Passager__c> toInsert = new List<Passager__c>();

            if (!partyList.isEmpty()) {
                Map<String, Object> firstParty = (Map<String, Object>) partyList[0];
                update new Case(
                    Id = caseId, 
                    OpposingParty__c = (String)firstParty.get('OpposingParty__c')
                );
            }

            for (Object obj : partyList) {
                Map<String, Object> p = (Map<String, Object>) obj;
                Passager__c newP = new Passager__c();
                
              
                newP.Compte__c = accountIdToUse; 
                newP.Case__c = caseId;           
                
                newP.Vehicule__c = currentCase.Vehicule__c;   

                String fullName = (String)p.get('Nom__c') + ' ' + (String)p.get('Prenom__c');
                newP.Name = fullName;             

                newP.Civilite__c = (String)p.get('Civilite__c');
                newP.CIN__c = (String)p.get('CIN__c');
                
                if(p.get('BirthDay__c') != null && String.isNotBlank((String)p.get('BirthDay__c'))) {
                    newP.BirthDay__c = Date.valueOf((String)p.get('BirthDay__c'));
                }
                
                newP.Pays__c = (String)p.get('Pays__c');
                newP.Ville__c = (String)p.get('Ville__c');
                newP.Adresse__c = (String)p.get('Adresse__c');
                newP.StateOfPerson__c = (String)p.get('StateOfPerson__c');
                newP.MaritalStatus__c = (String)p.get('MaritalStatus__c');
                newP.Roles__c = 'Autres partie'; 

                newP.MoyenNotification__c = (String)p.get('MoyenNotification__c');
                if (p.get('Telephone__c') != null) {
                    newP.Telephone__c = String.valueOf(p.get('Telephone__c'));
                } else if (p.get('Telephone') != null) {
                    newP.Telephone__c = String.valueOf(p.get('Telephone'));
                }
                
                if (p.get('Email__c') != null) {
                    newP.Email__c = (String)p.get('Email__c');
                }
                
                if (p.get('CompagnieAdverse__c') != null && String.isNotBlank((String)p.get('CompagnieAdverse__c'))) {
                    newP.Account__c = (Id)p.get('CompagnieAdverse__c');
                }

                toInsert.add(newP);
            }

            if (!toInsert.isEmpty()) {
                insert toInsert;
            }

        } catch (Exception e) {
            String errorMsg = 'Erreur d\'enregistrement : ' + e.getMessage() + ' (Ligne ' + e.getLineNumber() + ')';
            AuraHandledException ex = new AuraHandledException(errorMsg);
            ex.setMessage(errorMsg);
            throw ex;
        }
    }
    @AuraEnabled
    public static Id finalizeClaimProcess(Id caseId) {
        Savepoint sp = Database.setSavepoint();
        
        try {
            
            Case currentCase = [SELECT Id, Police__c, Vehicule__c, Vehicule__r.RegistrationNumber__c, 
                                    CausesAndCircumstances__c, TriggeringEventOfClaim__c, CausesOfClaim__c, 
                                    OpposingParty__c, NumberOfVehiclesInvolved__c, AnyDamage__c,
                                    PointsDeChoc__c, PrecisionsDommages__c,InsuredIsContact__c,
                                    AddressOfOccurrence__c ,CountryOfOccurrence__c,IncidentReport__c ,CityOfOccurrence__c 
                                FROM Case WHERE Id = :caseId LIMIT 1];


            Claim__c newClaim = new Claim__c();
            newClaim.Case__c = caseId; 
            newClaim.PolicyNumber__c = currentCase.Police__c;
            newClaim.Vehicule__c = currentCase.Vehicule__c;
            
            newClaim.Status__c = 'En cours de traitement';
            newClaim.AddressOfOccurrence__c = currentCase.AddressOfOccurrence__c;
            newClaim.CountryOfOccurrence__c = currentCase.CountryOfOccurrence__c;
            newClaim.IncidentReport__c = currentCase.IncidentReport__c;
        
            newClaim.CausesAndCircumstances__c = currentCase.CausesAndCircumstances__c;
            newClaim.TriggeringEventOfClaim__c = currentCase.TriggeringEventOfClaim__c;
            newClaim.CausesOfClaim__c = currentCase.CausesOfClaim__c;
            newClaim.OpposingParty__c = currentCase.OpposingParty__c;
            newClaim.NumberOfVehiclesInvolved__c = currentCase.NumberOfVehiclesInvolved__c;
            newClaim.IncidentReport__c = currentCase.IncidentReport__c;
            newClaim.CityOfOccurrence__c = currentCase.CityOfOccurrence__c;
            newClaim.AnyDamage__c = currentCase.AnyDamage__c;
            newClaim.PointsDeChoc__c = currentCase.PointsDeChoc__c;
            newClaim.PrecisionsDommages__c = currentCase.PrecisionsDommages__c;
            newClaim.InsuredIsContact__c = currentCase.InsuredIsContact__c;
            
            insert newClaim;
            

            List<Passager__c> passagers = [SELECT Id, Roles__c FROM Passager__c WHERE Case__c = :caseId];
            
            if (!passagers.isEmpty()) {
                List<ClaimParticipant__c> participantsToInsert = new List<ClaimParticipant__c>();
                for (Passager__c p : passagers) {
                    ClaimParticipant__c participant = new ClaimParticipant__c();
                    participant.Claim__c = newClaim.Id;    
                    participant.Passager__c = p.Id;        
                    participant.Roles__c = p.Roles__c;  
                    participant.ParticipantAccount__c = p.Compte__c;    
                    participantsToInsert.add(participant);
                }
                insert participantsToInsert;
                
                for(Passager__c p : passagers) { 
                    p.Claim__c = newClaim.Id; 
                }
                update passagers;
            }


            List<VehicleCaseAssignment__c> assignments = [
                SELECT Id, Claim__c 
                FROM VehicleCaseAssignment__c 
                WHERE Case__c = :caseId
            ];
            
            if (!assignments.isEmpty()) {
                for (VehicleCaseAssignment__c vca : assignments) {
                    vca.Claim__c = newClaim.Id; 
                }
                update assignments; 
            }

           
            currentCase.Status = 'En cours ';
            currentCase.Claim__c = newClaim.Id;
            update currentCase;

            return newClaim.Id;

        } catch (Exception e) {
            Database.rollback(sp); 
            throw new AuraHandledException('Erreur lors de la création du sinistre : ' + e.getMessage() + ' (Ligne ' + e.getLineNumber() + ')');
        }
    }
}