public with sharing class DA_ClaimSearchController {
    
    /**
     * Recherche les polices d'assurance selon plusieurs critères
     * Rectifié avec les bons API Names : AccountName__r et SituationPolice__c
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> searchPolicies(
        String policyNumber, 
        String registrationNumber, 
        String attestationNumber, 
        String chassisNumber
    ) {
        // Utilisation des API Names corrects validés précédemment
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

    /**
     * Formate les résultats SOQL en Map pour le LWC
     */
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

            // Extraction sécurisée via vehicle__r
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
    public static String createClaimCase(String payload) {
        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(payload);
            
            Case newCase = new Case();
            
            // Mapping des champs personnalisés
            newCase.CountryOfOccurrence__c = (String)data.get('country');
            newCase.CityOfOccurrence__c = (String)data.get('city');
            newCase.Description = 'Adresse: ' + (String)data.get('address') + '\nCommentaire: ' + (String)data.get('commentaire');
            
            String dateDepotStr = (String)data.get('dateDepot');
            if (String.isNotBlank(dateDepotStr)) {
                newCase.DateOfDeclarationSubmission__c = Date.valueOf(dateDepotStr);
            }
            
            newCase.Claimant__c = (String)data.get('declarant');
            newCase.IncidentReport__c = (String)data.get('pvConstat');
            newCase.Commentaire__c = (String)data.get('commentaire');
            
            // Lookups
            if (data.get('policyId') != null) newCase.Police__c = (Id)data.get('policyId');
            if (data.get('vehicleId') != null) newCase.Vehicule__c = (Id)data.get('vehicleId');
            
            // Infos contact (Champs standard Case)
            newCase.SuppliedName = (String)data.get('nomContact');
            newCase.SuppliedPhone = (String)data.get('telContact');
            newCase.SuppliedEmail = (String)data.get('mailContact');
            
            // Champs automatiques
            newCase.Status = 'New';
            newCase.Origin = 'Gestionnaire'; 
            newCase.DateOfDeclarationCreation__c = Date.today();

            // Insertion avec vérification de sécurité
            if (Schema.sObjectType.Case.isCreateable()) {
                insert newCase;
            } else {
                throw new AuraHandledException('Droits insuffisants pour créer une déclaration.');
            }
            
            return newCase.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lors de la création : ' + e.getMessage());
        }
    }

    // --- AJOUT : TRAITEMENT DES DOCUMENTS DANS SALESFORCE ---

    /**
     * Récupère les types de documents groupés par répertoire
     */
   @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getTypeDocumentsByReportoire() {
        Map<String, List<String>> result = new Map<String, List<String>>();
        result.put('Pièces d’identité', new List<String>{'CIN', 'Passeport', 'Permis de conduire'});
        result.put('Documents Véhicule', new List<String>{'Carte Grise', 'Attestation d’assurance', 'Visite Technique'});
        result.put('Documents Sinistre', new List<String>{'Constat Amiable', 'PV de Police', 'Rapport Expertise'});
        return result;
    }

    /**
     * Indexation locale Salesforce (SANS GED)
     */
    @AuraEnabled
    public static String saveDocumentLocally(Map<String, Object> fileData) {
        try {
            // Extraction des données
            Map<String, Object> docMap = (Map<String, Object>)fileData.get('document');
            Id caseId = (Id)fileData.get('caseId');
            String typeDoc = (String)fileData.get('typeDocument');

            // 1. Création de l'objet Document__c
            Document__c doc = new Document__c();
            doc.RegistrationNumber__c = (String)docMap.get('RegistrationNumber__c');
            doc.Police__c = (Id)docMap.get('Police__c');
            doc.Directory__c = (String)docMap.get('Directory__c');
            doc.Type_de_document__c = (String)docMap.get('Type_de_document__c');
            doc.dateOfReceipt__c = Date.today();
            doc.Statut__c = 'Validé';
            // Plus de champ IdDocument__c ici pour éviter l'erreur Apex
            
            insert doc;

            // 2. Création du lien Document_Link__c
            Document_Link__c link = new Document_Link__c();
            link.Document__c = doc.Id;
            link.Case__c = caseId;
            link.Name = 'Lien - ' + typeDoc;
            insert link;

            return 'Ok';
        } catch (Exception e) {
            throw new AuraHandledException('Erreur Salesforce : ' + e.getMessage());
        }
    }
    /**
     * Crée l'enregistrement Claim (Sinistre) lié au Case
     */
    @AuraEnabled
    public static String createClaimRecord(Id caseId, Id policyId, Id vehicleId, String registrationNumber, Map<String, Object> claimData) {
        try {
            // Initialisation du Claim avec les relations
            Claim__c newClaim = new Claim__c();
            newClaim.Case__c = caseId;
            newClaim.PolicyNumber__c = policyId;
            newClaim.Vehicule__c = vehicleId;
            newClaim.RegistrationNumber__c = registrationNumber;
            newClaim.Status__c = 'Ouvert';
            
            // Mapping dynamique des champs envoyés par le LWC
            newClaim.CausesAndCircumstances__c = (String)claimData.get('CausesAndCircumstances__c');
            newClaim.TriggeringEventOfClaim__c = (String)claimData.get('TriggeringEventOfClaim__c');
            newClaim.CausesOfClaim__c = (String)claimData.get('CausesOfClaim__c');
            newClaim.OpposingParty__c = (String)claimData.get('OpposingParty__c');
            newClaim.Commentaire__c = (String)claimData.get('Commentaire__c');
            
            // Gestion des types numériques et booléens
            if(claimData.containsKey('NumberOfVehiclesInvolved__c')) {
                newClaim.NumberOfVehiclesInvolved__c = Decimal.valueOf(String.valueOf(claimData.get('NumberOfVehiclesInvolved__c')));
            }
            if(claimData.containsKey('AnyDamage__c')) {
                newClaim.AnyDamage__c = Boolean.valueOf(claimData.get('AnyDamage__c'));
            }

            insert newClaim;
            return newClaim.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur création Claim : ' + e.getMessage());
        }
    }
}