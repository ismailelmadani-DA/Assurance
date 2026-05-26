public with sharing class DocumentGEDController {

    @AuraEnabled
    public static String saveDocumentWithGED(Id recordId, String base64Data, String fileName, String mimeType, String formDataJSON) {
        
        String googleFileId;

        try {
            
            googleFileId = GoogleDriveService.uploadFile(base64Data, fileName, mimeType);
            GoogleDriveService.makeFilePublic(googleFileId);   
                     
        } catch (Exception e) {
            throw new AuraHandledException('Erreur Google Drive : ' + e.getMessage());
        }

        Savepoint sp = Database.setSavepoint();
        
        try {
            Document__c doc = new Document__c();
            if (String.isNotBlank(formDataJSON)) {
                doc = (Document__c) JSON.deserialize(formDataJSON, Document__c.class);
            }
            
            doc.IdDocument__c = googleFileId; 
            
            insert doc; 
            
            Document_Link__c docLink = new Document_Link__c();
            docLink.Document__c = doc.Id; 
            
            docLink.Sinistre__c = doc.Sinistre__c;
            docLink.Case__c = doc.NumeroDeclaration__c; 
            
            if (docLink.Sinistre__c != null || docLink.Case__c != null) {
                insert docLink;
            }
            
            return googleFileId;

        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Erreur d\'enregistrement Salesforce : ' + e.getMessage());
        }
    }
   // @AuraEnabled(cacheable=true)
   // public static List<Document__c> getDocumentsBySinistre(Id sinistreId) {
     //    return [
   //         SELECT Id, Name, Directory__c, Type_de_document__c, dateOfReceipt__c, Statut__c
    //        FROM Document__c 
     //       WHERE Sinistre__c = :sinistreId 
   //         ORDER BY CreatedDate DESC
     //   ];
   // }

     @AuraEnabled(cacheable=true)
    public static Case getCaseDetails(Id caseId) {
        return [SELECT Id, Claim__c, Police__c, Num_ro_d_immatriculation__c, DateOfOccurrence__c
                FROM Case WHERE Id = :caseId LIMIT 1];
    }

    @AuraEnabled(cacheable=true)
    public static Case getCaseBySinistre(Id sinistreId) {
        List<Case> cases = [SELECT Id, Police__c, Num_ro_d_immatriculation__c,DateOfOccurrence__c
                            FROM Case WHERE Claim__c = :sinistreId 
                            ORDER BY CreatedDate DESC LIMIT 1];
        return cases.isEmpty() ? null : cases[0];
    }
    @AuraEnabled
    public static void deleteDocument(Id documentId) {
        try {
            List<Document_Link__c> linksToDelete = [SELECT Id FROM Document_Link__c WHERE Document__c = :documentId];
            if (!linksToDelete.isEmpty()) { delete linksToDelete; }
            delete new Document__c(Id = documentId);
        } catch (Exception e) {
            throw new AuraHandledException('Erreur : ' + e.getMessage());
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<Document__c> getDocumentsBySinistre(Id sinistreId) {
        try {
            return [
                SELECT Id, Name, Directory__c, Type_de_document__c, dateOfReceipt__c, Issuer__c, IdDocument__c
                FROM Document__c 
                WHERE Id IN (
                    SELECT Document__c 
                    FROM Document_Link__c 
                    WHERE Sinistre__c = :sinistreId
                )
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Erreur de récupération : ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static void updateDocumentDetails(Id docId, String repertoire, String typeDoc, String nature, 
                                             String compagnieAdverse, Date dateSurvenance, Date dateReception, String emetteur) {
        try {
            Document__c docToUpdate = new Document__c(
                Id = docId,
                Directory__c = repertoire,
                Type_de_document__c = typeDoc,
                Nature__c = nature,
                OccurrenceDate__c = dateSurvenance,  
                dateOfReceipt__c = dateReception,    
                Issuer__c = emetteur
                
            );
            
            update docToUpdate;
            
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lors de la mise à jour : ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static Document__c getDocumentById(Id docId) {
        try {
            return [SELECT Id, Directory__c, Type_de_document__c, Nature__c, 
                            OccurrenceDate__c, dateOfReceipt__c, Issuer__c,IdDocument__c
                    FROM Document__c 
                    WHERE Id = :docId 
                    LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException('Document introuvable : ' + e.getMessage());
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<Document__c> getDocumentsByCase(Id caseId) {
        try {
            return [
                SELECT Id, Name, Directory__c, Type_de_document__c, Nature__c, OccurrenceDate__c, IdDocument__c
                FROM Document__c 
                WHERE Id IN (
                    SELECT Document__c 
                    FROM Document_Link__c 
                    WHERE Case__c = :caseId
                )
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Erreur de récupération : ' + e.getMessage());
        }
    }
}