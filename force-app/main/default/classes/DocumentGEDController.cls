public with sharing class DocumentGEDController {

    /**
     * Point d'entrée unique pour le LWC.
     * Orchestre l'upload GED et la sauvegarde Salesforce.
     */
    @AuraEnabled
    public static String saveDocumentWithGED(
        Id recordId, 
        String base64Data, 
        String fileName, 
        String mimeType,
        String directory,
        String typeDocument,
        String natureDocument,
        Id numeroDeclarationId,
        Id sinistreId,
        Id policeId,
        String registrationNumber,
        Date occurrenceDate,
        Date dateOfReceipt,
        String issuer
    ) {
        try {
            // 1. Appel du service externe (Traitement GED isolé)
            String googleFileId = GoogleDriveService.uploadFile(base64Data, fileName, mimeType);
            
            // 2. Traitement des données Salesforce
            Document__c doc = new Document__c();
            
            if (recordId != null && recordId.getSObjectType() == Document__c.SObjectType) {
                doc.Id = recordId;
            }
            
            // Assignation des champs
            doc.Directory__c = directory;
            doc.Type_de_document__c = typeDocument;
            doc.Nature__c = natureDocument;
            doc.NumeroDeclaration__c = numeroDeclarationId;
            doc.Sinistre__c = sinistreId;
            doc.Police__c = policeId;
            doc.RegistrationNumber__c = registrationNumber;
            doc.OccurrenceDate__c = occurrenceDate;
            doc.dateOfReceipt__c = dateOfReceipt;
            doc.Issuer__c = issuer;
            
            // Enregistrement de la référence GED externe
            doc.IdDocument__c = googleFileId; 
            
            // 3. Sauvegarde en base de données
            upsert doc;
            
            return googleFileId;

        } catch (Exception e) {
            // Remonte l'erreur proprement au LWC
            throw new AuraHandledException('Erreur lors du traitement : ' + e.getMessage());
        }
    }
}