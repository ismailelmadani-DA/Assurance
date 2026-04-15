public with sharing class ClaimSearchController {
    
    /**
     * Recherche les polices d'assurance selon plusieurs critères
     */
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

    /**
     * Crée l'enregistrement de déclaration (Case)
     */
    @AuraEnabled
    public static Map<String, String> createClaimCase(String payload) {
        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(payload);
            Case newCase = new Case();
            
            newCase.CountryOfOccurrence__c = (String)data.get('country');
            newCase.CityOfOccurrence__c = (String)data.get('city');
            newCase.Description = 'Adresse: ' + (String)data.get('address') + '\nCommentaire: ' + (String)data.get('commentaire');
            
            if (String.isNotBlank((String)data.get('dateDepot'))) {
                newCase.DateOfDeclarationSubmission__c = Date.valueOf((String)data.get('dateDepot'));
            }
            
            newCase.Claimant__c = (String)data.get('declarant');
            newCase.IncidentReport__c = (String)data.get('pvConstat');
            newCase.Commentaire__c = (String)data.get('commentaire');
            
            if (data.get('policyId') != null) newCase.Police__c = (Id)data.get('policyId');
            if (data.get('vehicleId') != null) newCase.Vehicule__c = (Id)data.get('vehicleId');
            
            newCase.SuppliedName = (String)data.get('nomContact');
            newCase.SuppliedPhone = (String)data.get('telContact');
            newCase.SuppliedEmail = (String)data.get('mailContact');
            
            newCase.Status = 'New';
            newCase.Origin = 'Gestionnaire'; 
            newCase.DateOfDeclarationCreation__c = Date.today();

            insert newCase;
            Case insertedCase = [SELECT Id, CaseNumber FROM Case WHERE Id = :newCase.Id LIMIT 1];
            
            return new Map<String, String>{
                'id' => insertedCase.Id,
                'caseNumber' => insertedCase.CaseNumber
            };
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lors de la création : ' + e.getMessage());
        }
    }

    /**
     * Récupération des infos de l'assuré (Étape 7)
     */
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

    /**
     * Récupération dynamique des Picklists (Étape 7 & 8)
     */
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

    /**
     * Enregistrement des passagers (Étape 8)
     */
    @AuraEnabled
    public static void savePassengers(Id caseId, String passengersJson) {
        try {
            // 1. Récupération du Case et du Compte associé (via AccountId ou via la Police)
            List<Case> cases = [SELECT Id, AccountId, Police__r.AccountName__c FROM Case WHERE Id = :caseId LIMIT 1];
            
            if (cases.isEmpty()) {
                throw new AuraHandledException('Le dossier (Case) est introuvable.');
            }
            
            // On cherche l'ID du compte : soit sur le Case, soit sur la Police liée au Case
            Id parentAccountId = cases[0].AccountId != null ? cases[0].AccountId : cases[0].Police__r.AccountName__c;
            
            if (parentAccountId == null) {
                throw new AuraHandledException('Erreur : Aucun compte client n\'est lié à ce dossier. Impossible de créer des passagers (Champ obligatoire).');
            }

            List<Object> passList = (List<Object>) JSON.deserializeUntyped(passengersJson);
            List<Passager__c> toInsert = new List<Passager__c>();

            for (Object obj : passList) {
                Map<String, Object> p = (Map<String, Object>) obj;
                Passager__c newP = new Passager__c();
                
                // Relation Master-Detail Obligatoire
                newP.Compte__c = parentAccountId; 
                newP.Case__c = caseId;
                
                // Mapping des données
                newP.Name__c = (String)p.get('Name__c');
                newP.CIN__c = (String)p.get('CIN__c');
                newP.Civilite__c = (String)p.get('Civilite__c');
                
                if(p.get('BirthDay__c') != null && String.isNotBlank((String)p.get('BirthDay__c'))) {
                    newP.BirthDay__c = Date.valueOf((String)p.get('BirthDay__c'));
                }
                
                newP.Pays__c = (String)p.get('Pays__c');
                newP.Ville__c = (String)p.get('Ville__c');
                newP.Adresse__c = (String)p.get('Adresse__c');
                newP.StateOfPerson__c = (String)p.get('StateOfPerson__c');
                newP.MaritalStatus__c = (String)p.get('MaritalStatus__c');
                newP.Roles__c = 'Passager assuré';
                
                toInsert.add(newP);
            }

            if (!toInsert.isEmpty()) {
                insert toInsert;
            }
        } catch (Exception e) {
            // Renvoie le message d'erreur spécifique au LWC
            throw new AuraHandledException(e.getMessage());
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

            Document_Link__c link = new Document_Link__c();
            link.Document__c = doc.Id;
            link.Case__c = caseId;
            link.Name = 'Lien - ' + (String)docMap.get('Type_de_document__c');
            insert link;
            return 'Ok';
        } catch (Exception e) {
            throw new AuraHandledException('Erreur Salesforce : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String createClaimRecord(Id caseId, Id policyId, Id vehicleId, String registrationNumber, Map<String, Object> claimData) {
        try {
            Claim__c newClaim = new Claim__c();
            newClaim.Case__c = caseId;
            newClaim.PolicyNumber__c = policyId;
            newClaim.Vehicule__c = vehicleId;
            newClaim.RegistrationNumber__c = registrationNumber;
            newClaim.CausesAndCircumstances__c = (String)claimData.get('CausesAndCircumstances__c');
            newClaim.TriggeringEventOfClaim__c = (String)claimData.get('TriggeringEventOfClaim__c');
            newClaim.CausesOfClaim__c = (String)claimData.get('CausesOfClaim__c');
            newClaim.OpposingParty__c = (String)claimData.get('OpposingParty__c');
            newClaim.Commentaire__c = (String)claimData.get('Commentaire__c');
            newClaim.PointsDeChoc__c = (String)claimData.get('PointsDeChoc__c');
            newClaim.PrecisionsDommages__c = (String)claimData.get('PrecisionsDommages__c');
            if(claimData.containsKey('NumberOfVehiclesInvolved__c')) newClaim.NumberOfVehiclesInvolved__c = Decimal.valueOf(String.valueOf(claimData.get('NumberOfVehiclesInvolved__c')));
            newClaim.AnyDamage__c = Boolean.valueOf(claimData.get('AnyDamage__c'));

            insert newClaim;
            return newClaim.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lors de la création du sinistre : ' + e.getMessage());
        }
    }
    /**
 * Enregistre les informations du véhicule adverse (Étape 9)
 * Crée un record dans l'objet VehicleCaseAssignment__c
 */
   @AuraEnabled
    public static void saveAdverseVehicle(Id caseId, String adverseDataJson) {
        try {
            if (caseId == null || String.isBlank(adverseDataJson)) {
                throw new AuraHandledException('Données manquantes pour la sauvegarde du véhicule adverse.');
            }

            // Désérialisation du JSON envoyé par le LWC
            List<Object> vehiclesList = (List<Object>) JSON.deserializeUntyped(adverseDataJson);
            List<VehicleCaseAssignment__c> assignmentsToInsert = new List<VehicleCaseAssignment__c>();
            String etatVehiculePourCase = null; 

            for (Object obj : vehiclesList) {
                Map<String, Object> v = (Map<String, Object>) obj;
                VehicleCaseAssignment__c newAssignment = new VehicleCaseAssignment__c();
                
                // Lien obligatoire avec la déclaration
                newAssignment.Case__c = caseId; 

                // ==========================================
                // ÉTAPE 1 : GESTION DE LA VOITURE PHYSIQUE (Vehicule__c)
                // ==========================================
                String vehiculeId = (String)v.get('Vehicule__c'); 
                
                if (String.isNotBlank(vehiculeId)) {
                    // Le véhicule a été trouvé via la barre de recherche, on le lie directement
                    newAssignment.Vehicule__c = (Id)vehiculeId;
                } else {
                    // Le véhicule est INCONNU : on le crée dans la base de données !
                    Vehicule__c newCar = new Vehicule__c();
                    
                    newCar.RegistrationNumber__c = (String)v.get('RegistrationNumber__c');
                    newCar.Brand__c = (String)v.get('Marque__c'); 
                    newCar.TypeVehicule__c = (String)v.get('TypeVehicule__c');
                    
                    // ---> CORRECTION : Le numéro de contrat se place bien sur le véhicule ici <---
                    newCar.NbDeContratDAssurance__c = (String)v.get('Numéro_de_contrat__c');
                    
                    // Gestion de la Date de mise en circulation sur le Véhicule
                    if (v.get('DateMiseEnCirculation__c') != null && String.isNotBlank((String)v.get('DateMiseEnCirculation__c'))) {
                        newCar.DateOfFirstRegistration__c = Date.valueOf((String)v.get('DateMiseEnCirculation__c'));
                    }
                    
                    // On insère le nouveau véhicule pour générer son ID Salesforce
                    insert newCar; 
                    
                    // On relie l'accident à ce tout nouveau véhicule
                    newAssignment.Vehicule__c = newCar.Id; 
                }

                // ==========================================
                // ÉTAPE 2 : INFORMATIONS DE L'ACCIDENT (VehicleCaseAssignment__c)
                // ==========================================
                
                // Conversion propre du texte en Booléen
                if (v.get('Adversaire_Assure__c') != null) {
                    newAssignment.AdversaireAssure__c = Boolean.valueOf((String)v.get('Adversaire_Assure__c'));
                }

                // Gestion des Lookups (Compagnie d'assurance)
                if (v.get('CompagnieAdverse__c') != null && String.isNotBlank((String)v.get('CompagnieAdverse__c'))) {
                    newAssignment.CompagnieAdverse__c = (Id)v.get('CompagnieAdverse__c');
                }

                // Gestion des Nombres (Passagers blessés)
                if (v.get('NbDePassagerBlesses__c') != null && String.isNotBlank(String.valueOf(v.get('NbDePassagerBlesses__c')))) {
                    newAssignment.NbDePassagerBlesses__c = Integer.valueOf(v.get('NbDePassagerBlesses__c'));
                }

                // Ajout à la liste d'insertion
                assignmentsToInsert.add(newAssignment);
                
                // ==========================================
                // ÉTAPE 3 : CAPTURE DE L'ÉTAT POUR L'OBJET CASE
                // ==========================================
                if (etatVehiculePourCase == null) {
                    etatVehiculePourCase = (String)v.get('VehicleIsDamaged__c');
                }
            }

            // --- SAUVEGARDE FINALE EN BASE DE DONNÉES ---
            
            // 1. On insère les liaisons Véhicules <-> Accident
            if (!assignmentsToInsert.isEmpty()) {
                insert assignmentsToInsert;
            }
            
            // 2. On met à jour la déclaration (Case) avec l'état d'endommagement
            if (etatVehiculePourCase != null) {
                update new Case(Id = caseId, VehicleIsDamaged__c = etatVehiculePourCase);
            }

        } catch (Exception e) {
            // En cas d'erreur, on renvoie la ligne exacte pour faciliter le débogage
            throw new AuraHandledException('Erreur : ' + e.getMessage() + ' (Ligne ' + e.getLineNumber() + ')');
        }
    }
    @AuraEnabled
    public static void saveOtherParties(Id caseId, Id claimId, String partiesJson) {
        try {
            // Sécurité : On sort tout de suite si aucune donnée n'a été saisie
            if (String.isBlank(partiesJson) || partiesJson == '[]') {
                return; 
            }

            // 1. Récupérer le Case (sans déclencher d'erreur si AccountId est null)
            Case currentCase = [SELECT Id, AccountId FROM Case WHERE Id = :caseId LIMIT 1];

            List<Object> partyList = (List<Object>) JSON.deserializeUntyped(partiesJson);
            List<Passager__c> toInsert = new List<Passager__c>();

            // 2. Mise à jour du type de partie adverse sur le Sinistre (Claim__c)
            if (!partyList.isEmpty()) {
                Map<String, Object> firstParty = (Map<String, Object>) partyList[0];
                update new Claim__c(
                    Id = claimId, 
                    OpposingParty__c = (String)firstParty.get('OpposingParty__c')
                );
            }

            // 3. Boucle de création des Tiers
            for (Object obj : partyList) {
                Map<String, Object> p = (Map<String, Object>) obj;
                Passager__c newP = new Passager__c();
                
                // --- MODIFICATION ICI : On assigne le compte uniquement s'il existe ---
                if (currentCase.AccountId != null) {
                    newP.Compte__c = currentCase.AccountId;
                }
                
                newP.Case__c = caseId;

                // --- NOMS ---
                String fullName = (String)p.get('Nom__c') + ' ' + (String)p.get('Prenom__c');
                newP.Name = (String)p.get('Nom__c'); 
                newP.Name__c = fullName;             

                // --- INFORMATIONS PERSONNELLES ---
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

                // --- NOTIFICATION & ASSURANCE ---
                newP.MoyenNotification__c = (String)p.get('MoyenNotification__c');
                
                if (p.get('CompagnieAdverse__c') != null && String.isNotBlank((String)p.get('CompagnieAdverse__c'))) {
                    newP.Account__c = (Id)p.get('CompagnieAdverse__c');
                }

                toInsert.add(newP);
            }

            // 4. Insertion en base de données
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
}