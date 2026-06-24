public with sharing class ClaimSearchController {
   
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> searchPolicies(
        String policyNumber, 
        String registrationNumber, 
        String attestationNumber,  
        String chassisNumber
    ) {
        String query = 'SELECT Id, PolicyNumber__c, AccountName__r.Name, AccountName__r.Email__c, AccountName__r.Phone, PolicyCategory__c, Status__c, ' +
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
                'InsuredEmail' => ip.AccountName__r != null ? ip.AccountName__r.Email__c : null,
                'InsuredPhone' => ip.AccountName__r != null ? ip.AccountName__r.Phone : null,
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
            newCase.InsuredIsContact__c = insuredIsContact;
            
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

            String rejectMotif = (String) data.get('rejectMotif');
            if (String.isNotBlank(rejectMotif)) {
                newCase.Status = 'Rejetée';
                newCase.MotifRejet__c = rejectMotif;
            } else {
                newCase.Status = 'En cours';
            }
            newCase.Origin = 'Gestionnaire';
            newCase.DateOfDeclarationCreation__c = Date.today();
            Id declarationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Declaration').getRecordTypeId();
            newCase.RecordTypeId = declarationRecordTypeId;

            newCase.LastWizardStep__c = 5;

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
            Id passagerRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Passager').getRecordTypeId();

            List<Account> accountsToInsert = new List<Account>();
            for (Object obj : passList) {
                Map<String, Object> p = (Map<String, Object>) obj;
                String cin = (String)p.get('CIN__c');
                String fullName = (p.get('Nom__c') != null && p.get('Prenom__c') != null) ? 
                                  (String)p.get('Nom__c') + ' ' + (String)p.get('Prenom__c') : 
                                  (String)p.get('Name__c');

                if (String.isNotBlank(cin) && !accountMap.containsKey(cin)) {
                    Account newAcc = new Account(Name = fullName, CIN__c = cin);
                    newAcc.RecordTypeId = passagerRTId;
                    if (p.get('Telephone__c') != null) newAcc.Phone = String.valueOf(p.get('Telephone__c'));
                    if (p.get('Email__c') != null) newAcc.Email__c = (String)p.get('Email__c');
                    accountsToInsert.add(newAcc);
                    accountMap.put(cin, newAcc); 
                } else if (String.isBlank(cin) && String.isNotBlank(fullName) && !accountMap.containsKey(fullName)) {
                    Account newAcc = new Account(Name = fullName);
                    newAcc.RecordTypeId = passagerRTId;
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

                // On n'accepte le champ 'Id' comme identifiant du passager que s'il
                // s'agit réellement d'un Id de Passager__c. Un autre type d'Id (ex : un
                // Id de compte 001...) doit être ignoré pour éviter l'erreur
                // « Invalid id value for this SObject type ». On retombe alors sur la
                // correspondance par CIN puis par nom.
                String rawPassagerId = (String) p.get('Id');
                Boolean isValidPassagerId = String.isNotBlank(rawPassagerId)
                    && ((Id) rawPassagerId).getSObjectType() == Passager__c.SObjectType;

                if (isValidPassagerId) {
                    newP.Id = (Id) rawPassagerId;
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

                // État du véhicule au niveau de chaque véhicule adverse (affiché
                // sur la liste « Véhicules adverses » du sinistre).
                if (v.get('VehicleIsDamaged__c') != null && String.isNotBlank((String)v.get('VehicleIsDamaged__c'))) {
                    newAssignment.EtatVehicule__c = (String)v.get('VehicleIsDamaged__c');
                }

                // Date de mise en circulation : la liste « Véhicules adverses » du
                // sinistre lit ce champ sur l'affectation (et non sur le véhicule).
                if (v.get('DateMiseEnCirculation__c') != null && String.isNotBlank((String)v.get('DateMiseEnCirculation__c'))) {
                    newAssignment.DateMiseEnCirculation__c = Date.valueOf((String)v.get('DateMiseEnCirculation__c'));
                }

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

                        if (pMap.get('isDriver__c') != null) {
                            newPass.isDriver__c = Boolean.valueOf(pMap.get('isDriver__c'));
                        }
                        
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
            

            List<Passager__c> passagers = [
                SELECT Id, Roles__c, Compte__c, Account__c, StateOfPerson__c, CIN__c,
                       isDriver__c, Vehicule__c, Pays__c, Ville__c, Adresse__c,
                       BirthDay__c, MaritalStatus__c, Civilite__c
                FROM Passager__c WHERE Case__c = :caseId
            ];

            if (!passagers.isEmpty()) {
                List<ClaimParticipant__c> participantsToInsert = new List<ClaimParticipant__c>();
                for (Passager__c p : passagers) {
                    ClaimParticipant__c participant = new ClaimParticipant__c();
                    participant.Claim__c = newClaim.Id;
                    participant.Passager__c = p.Id;
                    participant.Roles__c = p.Roles__c;
                    participant.StateOfPerson__c = p.StateOfPerson__c;
                    participant.ParticipantAccount__c = p.Compte__c;
                    // Report complet des données du passager (assuré comme adverse)
                    // vers le participant du sinistre, afin qu'elles soient visibles
                    // sur la fiche Sinistre (véhicule, conducteur, localisation…).
                    // ParticipantCNI__c est une formule : la CNI provient du compte lié.
                    participant.isDriver__c = p.isDriver__c;
                    participant.Vehicule__c = p.Vehicule__c;
                    participant.Pays__c = p.Pays__c;
                    participant.Ville__c = p.Ville__c;
                    participant.Adresse__c = p.Adresse__c;
                    participant.BirthDay__c = p.BirthDay__c;
                    participant.CompagnieAdverse__c = p.Account__c;
                    // Civilite__c / MaritalStatus__c volontairement non reportés :
                    // ce sont des listes restreintes dont les valeurs diffèrent de
                    // celles de Passager__c (ex : « M. ») et qui ne sont pas affichées
                    // dans la liste des passagers adverses ; la civilité provient du
                    // compte lié (ParticipantAccount__r.Civility__c).
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

           
            List<CaseCoverage__c> caseCoverages = DM009_CaseCoverage.getByCaseId('Id, Name, CodeGarantie__c, Insurance_Policy_Coverage__c', caseId);

            if (!caseCoverages.isEmpty()) {
                List<ClaimCoverage__c> claimCoverages = new List<ClaimCoverage__c>();
                for (CaseCoverage__c cc : caseCoverages) {
                    claimCoverages.add(new ClaimCoverage__c(
                        Claim__c = newClaim.Id,
                        Name = cc.Name,
                        CodeGarantie__c = cc.CodeGarantie__c,
                        Insurance_Policy_Coverage__c = cc.Insurance_Policy_Coverage__c
                    ));
                }
                insert claimCoverages;
            }
            List<Document_Link__c> docLinks = [
                SELECT Id, Sinistre__c 
                FROM Document_Link__c 
                WHERE Case__c = :caseId
            ];
            
            if (!docLinks.isEmpty()) {
                for (Document_Link__c dl : docLinks) {
                    dl.Sinistre__c = newClaim.Id; 
                }
                update docLinks;
            }
            
            currentCase.Status = 'En cours';
            currentCase.Claim__c = newClaim.Id;
            currentCase.LastWizardStep__c = null;
            update currentCase;

            return newClaim.Id;

        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Erreur lors de la création du sinistre : ' + e.getMessage() + ' (Ligne ' + e.getLineNumber() + ')');
        }
    }

    @AuraEnabled
    public static void updateWizardStep(Id caseId, Integer step) {
        try {
            if (caseId == null || step == null) return;
            update new Case(Id = caseId, LastWizardStep__c = step);
        } catch (Exception e) {
            throw new AuraHandledException('Erreur sauvegarde étape : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> getClaimProgressSnapshot(Id caseId) {
        try {
            Case c = [
                SELECT Id, CaseNumber, Status, LastWizardStep__c,
                       Police__c, Vehicule__c, AccountId,
                       CountryOfOccurrence__c, CityOfOccurrence__c, AddressOfOccurrence__c,
                       DateOfOccurrence__c, DateOfDeclarationSubmission__c,
                       Claimant__c, IncidentReport__c, Commentaire__c,
                       CausesAndCircumstances__c, TriggeringEventOfClaim__c, CausesOfClaim__c,
                       OpposingParty__c, NumberOfVehiclesInvolved__c, AnyDamage__c,
                       PointsDeChoc__c, PrecisionsDommages__c, VehicleIsDamaged__c, InsuredIsContact__c,
                       Account.Name, Account.Phone, Account.Email__c, Account.MoyenNotification__c,
                       Police__r.PolicyNumber__c, Police__r.PolicyCategory__c, Police__r.Status__c,
                       Police__r.SituationPolice__c, Police__r.SituationPrime__c,
                       Police__r.DateEffet__c, Police__r.DateExpiration__c, Police__r.QuotePartCoass__c,
                       Police__r.AccountName__r.Name, Police__r.AccountName__r.Phone,
                       Police__r.AccountName__r.Email__c,
                       Vehicule__r.RegistrationNumber__c, Vehicule__r.ChassisNumber__c,
                       Vehicule__r.Brand__c, Vehicule__r.AttestationNumber__c,
                       Vehicule__r.DateOfFirstRegistration__c
                FROM Case WHERE Id = :caseId LIMIT 1
            ];

            Map<String, Object> result = new Map<String, Object>();
            result.put('caseId', c.Id);
            result.put('caseNumber', c.CaseNumber);
            result.put('lastStep', c.LastWizardStep__c != null ? Integer.valueOf(c.LastWizardStep__c) : 5);
            result.put('dateSurvenance', c.DateOfOccurrence__c);
            result.put('selectedPolicyId', c.Police__c);

            Map<String, Object> caseData = new Map<String, Object>();
            caseData.put('country', c.CountryOfOccurrence__c);
            caseData.put('city', c.CityOfOccurrence__c);
            caseData.put('address', c.AddressOfOccurrence__c);
            caseData.put('dateDepot', c.DateOfDeclarationSubmission__c);
            caseData.put('declarant', c.Claimant__c);
            caseData.put('pvConstat', c.IncidentReport__c);
            caseData.put('commentaire', c.Commentaire__c);
            caseData.put('nomContact', c.Account != null ? c.Account.Name : null);
            caseData.put('telContact', c.Account != null ? c.Account.Phone : null);
            caseData.put('mailContact', c.Account != null ? c.Account.Email__c : null);
            caseData.put('moyenNotification', c.Account != null ? c.Account.MoyenNotification__c : null);
            result.put('caseData', caseData);
            result.put('isSameAsInsured', c.InsuredIsContact__c == true);

            if (c.Police__c != null) {
                Map<String, Object> policy = new Map<String, Object>();
                policy.put('Id', c.Police__c);
                policy.put('PolicyNumber', c.Police__r.PolicyNumber__c);
                policy.put('Category', c.Police__r.PolicyCategory__c);
                policy.put('Status', c.Police__r.Status__c);
                policy.put('SituationPolice', c.Police__r.SituationPolice__c);
                policy.put('SituationPrime', c.Police__r.SituationPrime__c);
                policy.put('DateEffet', c.Police__r.DateEffet__c);
                policy.put('DateExpiration', c.Police__r.DateExpiration__c);
                policy.put('QuotePart', c.Police__r.QuotePartCoass__c);
                policy.put('InsuredName', c.Police__r.AccountName__r != null ? c.Police__r.AccountName__r.Name : null);
                policy.put('InsuredPhone', c.Police__r.AccountName__r != null ? c.Police__r.AccountName__r.Phone : null);
                policy.put('InsuredEmail', c.Police__r.AccountName__r != null ? c.Police__r.AccountName__r.Email__c : null);
                if (c.Vehicule__c != null) {
                    policy.put('vehicleId', c.Vehicule__c);
                    policy.put('RegistrationNumber', c.Vehicule__r.RegistrationNumber__c);
                    policy.put('ChassisNumber', c.Vehicule__r.ChassisNumber__c);
                    policy.put('Brand', c.Vehicule__r.Brand__c);
                    policy.put('AttestationNumber', c.Vehicule__r.AttestationNumber__c);
                    policy.put('DateMiseCirculation', c.Vehicule__r.DateOfFirstRegistration__c);
                }
                result.put('selectedPolicyRecord', policy);
            }

            Map<String, Object> circ = new Map<String, Object>();
            circ.put('CausesAndCircumstances__c', c.CausesAndCircumstances__c);
            circ.put('TriggeringEventOfClaim__c', c.TriggeringEventOfClaim__c);
            circ.put('CausesOfClaim__c', c.CausesOfClaim__c);
            circ.put('OpposingParty__c', c.OpposingParty__c);
            circ.put('NumberOfVehiclesInvolved__c', c.NumberOfVehiclesInvolved__c);
            circ.put('AnyDamage__c', c.AnyDamage__c);
            circ.put('PointsDeChoc__c', c.PointsDeChoc__c);
            circ.put('PrecisionsDommages__c', c.PrecisionsDommages__c);
            circ.put('VehicleIsDamaged__c', c.VehicleIsDamaged__c);
            result.put('circumstancesData', circ);

            List<Passager__c> passagers = [
                SELECT Id, Name, Roles__c, Civilite__c, CIN__c, Pays__c, Ville__c, Adresse__c,
                       BirthDay__c, MaritalStatus__c, StateOfPerson__c, Telephone__c, Email__c,
                       MoyenNotification__c, Vehicule__c, Account__c, Compte__c, isDriver__c
                FROM Passager__c WHERE Case__c = :caseId
            ];

            List<Map<String, Object>> passengersInsured = new List<Map<String, Object>>();
            List<Map<String, Object>> otherParties = new List<Map<String, Object>>();
            Map<Id, List<Map<String, Object>>> advPassengersByVehicle = new Map<Id, List<Map<String, Object>>>();

            for (Passager__c p : passagers) {
                Map<String, Object> row = new Map<String, Object>{
                    'Id' => p.Id,
                    'Name__c' => p.Name,
                    'Civilite__c' => p.Civilite__c,
                    'CIN__c' => p.CIN__c,
                    'Pays__c' => p.Pays__c,
                    'Ville__c' => p.Ville__c,
                    'Adresse__c' => p.Adresse__c,
                    'BirthDay__c' => p.BirthDay__c,
                    'MaritalStatus__c' => p.MaritalStatus__c,
                    'StateOfPerson__c' => p.StateOfPerson__c,
                    'Telephone__c' => p.Telephone__c,
                    'Email__c' => p.Email__c,
                    'MoyenNotification__c' => p.MoyenNotification__c,
                    'CompagnieAdverse__c' => p.Account__c,
                    'isDriver__c' => p.isDriver__c
                };
                if (p.Roles__c == 'Passager assuré') {
                    passengersInsured.add(row);
                } else if (p.Roles__c == 'Autres partie') {
                    row.put('OpposingParty__c', c.OpposingParty__c);
                    otherParties.add(row);
                } else if (p.Roles__c == 'Passager adverse' && p.Vehicule__c != null) {
                    if (!advPassengersByVehicle.containsKey(p.Vehicule__c)) {
                        advPassengersByVehicle.put(p.Vehicule__c, new List<Map<String, Object>>());
                    }
                    advPassengersByVehicle.get(p.Vehicule__c).add(row);
                }
            }
            result.put('passengersData', passengersInsured);
            result.put('otherPartiesData', otherParties);

            List<VehicleCaseAssignment__c> assignments = [
                SELECT Id, Vehicule__c, AdversaireAssure__c, CompagnieAdverse__c, NbDePassagerBlesses__c,
                       Vehicule__r.RegistrationNumber__c, Vehicule__r.Brand__c, Vehicule__r.TypeVehicule__c,
                       Vehicule__r.NbDeContratDAssurance__c, Vehicule__r.DateOfFirstRegistration__c
                FROM VehicleCaseAssignment__c WHERE Case__c = :caseId
            ];
            List<Map<String, Object>> adverseVehicles = new List<Map<String, Object>>();
            for (VehicleCaseAssignment__c a : assignments) {
                Map<String, Object> v = new Map<String, Object>{
                    'Id' => a.Id,
                    'Vehicule__c' => a.Vehicule__c,
                    'RegistrationNumber__c' => a.Vehicule__r != null ? a.Vehicule__r.RegistrationNumber__c : null,
                    'Marque__c' => a.Vehicule__r != null ? a.Vehicule__r.Brand__c : null,
                    'TypeVehicule__c' => a.Vehicule__r != null ? a.Vehicule__r.TypeVehicule__c : null,
                    'Numéro_de_contrat__c' => a.Vehicule__r != null ? a.Vehicule__r.NbDeContratDAssurance__c : null,
                    'DateMiseEnCirculation__c' => a.Vehicule__r != null ? a.Vehicule__r.DateOfFirstRegistration__c : null,
                    'Adversaire_Assure__c' => a.AdversaireAssure__c,
                    'CompagnieAdverse__c' => a.CompagnieAdverse__c,
                    'NbDePassagerBlesses__c' => a.NbDePassagerBlesses__c,
                    'VehicleIsDamaged__c' => c.VehicleIsDamaged__c,
                    'passengers' => advPassengersByVehicle.containsKey(a.Vehicule__c)
                        ? advPassengersByVehicle.get(a.Vehicule__c)
                        : new List<Map<String, Object>>()
                };
                adverseVehicles.add(v);
            }
            result.put('adverseVehicleData', adverseVehicles);

            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur snapshot : ' + e.getMessage() + ' (Ligne ' + e.getLineNumber() + ')');
        }
    }
}