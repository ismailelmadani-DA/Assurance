public with sharing class DocumentGEDController {

    @AuraEnabled
    public static String saveDocumentWithGED(Id recordId, String base64Data, String fileName, String mimeType, String formDataJSON) {
        String googleFileId;

        try {
            googleFileId = GoogleDriveService.uploadFile(base64Data, fileName, mimeType);
            GoogleDriveService.makeFilePublic(googleFileId);
        } catch (Exception e) {
            throw buildAuraException('Erreur Google Drive : ' + e.getMessage());
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
            throw buildAuraException('Erreur d\'enregistrement Salesforce : ' + e.getMessage());
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
            throw buildAuraException('Erreur de récupération : ' + e.getMessage());
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
            throw buildAuraException('Erreur de récupération : ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Document__c> getDocumentsByInstruction(Id instructionId) {
        try {
            return [
                SELECT Id, Name, Directory__c, Type_de_document__c, dateOfReceipt__c,
                       Issuer__c, IdDocument__c, Statut__c, Nature__c, OccurrenceDate__c
                FROM Document__c
                WHERE Id IN (
                    SELECT Document__c
                    FROM Document_Link__c
                    WHERE Instruction__c = :instructionId
                )
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw buildAuraException('Erreur lors du chargement des documents : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Document__c getDocumentById(Id docId) {
        try {
            return [
                SELECT Id, Directory__c, Type_de_document__c, Nature__c,
                       OccurrenceDate__c, dateOfReceipt__c, Issuer__c, IdDocument__c
                FROM Document__c
                WHERE Id = :docId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw buildAuraException('Document introuvable : ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Case getCaseDetails(Id caseId) {
        return [
            SELECT Id, Claim__c, Police__c, Num_ro_d_immatriculation__c, DateOfOccurrence__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Case getCaseBySinistre(Id sinistreId) {
        List<Case> cases = [
            SELECT Id, Police__c, Num_ro_d_immatriculation__c, DateOfOccurrence__c
            FROM Case
            WHERE Claim__c = :sinistreId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return cases.isEmpty() ? null : cases[0];
    }

    @AuraEnabled(cacheable=true)
    public static Id getClaimIdForInstruction(Id instructionId) {
        try {
            List<Instruction__c> rows = [
                SELECT Claim__c FROM Instruction__c WHERE Id = :instructionId LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0].Claim__c;
        } catch (Exception e) {
            throw buildAuraException('Erreur lors de la résolution du sinistre : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Document__c> getAvailableDocumentsForInstruction(Id instructionId) {
        try {
            Id claimId = getClaimIdForInstruction(instructionId);
            if (claimId == null) {
                return new List<Document__c>();
            }

            Set<Id> sinistreDocs = new Set<Id>();
            for (Document_Link__c link : [
                SELECT Document__c
                FROM Document_Link__c
                WHERE Sinistre__c = :claimId
            ]) {
                if (link.Document__c != null) {
                    sinistreDocs.add(link.Document__c);
                }
            }

            for (Document_Link__c link : [
                SELECT Document__c
                FROM Document_Link__c
                WHERE Instruction__c = :instructionId
            ]) {
                if (link.Document__c != null) {
                    sinistreDocs.remove(link.Document__c);
                }
            }

            if (sinistreDocs.isEmpty()) {
                return new List<Document__c>();
            }

            return [
                SELECT Id, Name, Type_de_document__c, IdDocument__c,
                       dateOfReceipt__c, Statut__c, Police__c
                FROM Document__c
                WHERE Id IN :sinistreDocs
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw buildAuraException('Erreur lors du chargement des documents disponibles : ' + e.getMessage());
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
            throw buildAuraException('Erreur lors de la mise à jour : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteDocument(Id documentId) {
        try {
            List<Document_Link__c> linksToDelete = [
                SELECT Id FROM Document_Link__c WHERE Document__c = :documentId
            ];
            if (!linksToDelete.isEmpty()) {
                delete linksToDelete;
            }
            delete new Document__c(Id = documentId);
        } catch (Exception e) {
            throw buildAuraException('Erreur : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Integer associateDocumentsToInstruction(Id instructionId, List<Id> documentIds) {
        try {
            if (documentIds == null || documentIds.isEmpty()) {
                return 0;
            }

            Id claimId = getClaimIdForInstruction(instructionId);

            Set<Id> alreadyLinked = new Set<Id>();
            for (Document_Link__c link : [
                SELECT Document__c
                FROM Document_Link__c
                WHERE Instruction__c = :instructionId
                  AND Document__c IN :documentIds
            ]) {
                if (link.Document__c != null) {
                    alreadyLinked.add(link.Document__c);
                }
            }

            Map<Id, Document_Link__c> freeRowByDoc = new Map<Id, Document_Link__c>();
            Map<Id, Id> caseByDoc = new Map<Id, Id>();
            for (Document_Link__c link : [
                SELECT Id, Document__c, Case__c, Instruction__c
                FROM Document_Link__c
                WHERE Document__c IN :documentIds
                  AND Sinistre__c = :claimId
            ]) {
                if (link.Case__c != null && !caseByDoc.containsKey(link.Document__c)) {
                    caseByDoc.put(link.Document__c, link.Case__c);
                }
                if (link.Instruction__c == null && !freeRowByDoc.containsKey(link.Document__c)) {
                    freeRowByDoc.put(link.Document__c, link);
                }
            }

            List<Document_Link__c> toUpdate = new List<Document_Link__c>();
            List<Document_Link__c> toInsert = new List<Document_Link__c>();
            for (Id docId : documentIds) {
                if (alreadyLinked.contains(docId)) {
                    continue;
                }
                if (freeRowByDoc.containsKey(docId)) {
                    Document_Link__c link = freeRowByDoc.get(docId);
                    link.Instruction__c = instructionId;
                    toUpdate.add(link);
                } else {
                    toInsert.add(new Document_Link__c(
                        Document__c = docId,
                        Instruction__c = instructionId,
                        Sinistre__c = claimId,
                        Case__c = caseByDoc.get(docId)
                    ));
                }
            }

            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }
            if (!toInsert.isEmpty()) {
                insert toInsert;
            }
            return toUpdate.size() + toInsert.size();
        } catch (Exception e) {
            throw buildAuraException('Erreur lors de l\'association : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Integer moveRecentDocumentLinksToInstruction(Id instructionId, Id claimId, Long sinceMillis) {
        try {
            if (claimId == null) {
                return 0;
            }
            Datetime threshold = (sinceMillis != null)
                ? Datetime.newInstance(sinceMillis - 60000)
                : Datetime.now().addMinutes(-5);

            List<Document_Link__c> links = [
                SELECT Id, Sinistre__c, Case__c
                FROM Document_Link__c
                WHERE Sinistre__c = :claimId
                  AND CreatedDate >= :threshold
                  AND CreatedById = :UserInfo.getUserId()
                  AND Instruction__c = null
            ];
            for (Document_Link__c link : links) {
                link.Instruction__c = instructionId;
            }
            if (!links.isEmpty()) {
                update links;
            }
            return links.size();
        } catch (Exception e) {
            throw buildAuraException('Erreur lors du rattachement à l\'instruction : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void unlinkDocumentFromInstruction(Id instructionId, Id documentId) {
        try {
            List<Document_Link__c> links = [
                SELECT Id, Sinistre__c, Case__c
                FROM Document_Link__c
                WHERE Instruction__c = :instructionId
                  AND Document__c = :documentId
            ];
            if (links.isEmpty()) {
                return;
            }

            List<Document_Link__c> toUpdate = new List<Document_Link__c>();
            List<Document_Link__c> toDelete = new List<Document_Link__c>();

            for (Document_Link__c link : links) {
                if (link.Sinistre__c != null || link.Case__c != null) {
                    link.Instruction__c = null;
                    toUpdate.add(link);
                } else {
                    toDelete.add(link);
                }
            }
            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }
            if (!toDelete.isEmpty()) {
                delete toDelete;
            }
        } catch (Exception e) {
            throw buildAuraException('Erreur lors de la dissociation : ' + e.getMessage());
        }
    }

    private static AuraHandledException buildAuraException(String msg) {
        AuraHandledException ahe = new AuraHandledException(msg);
        ahe.setMessage(msg);
        return ahe;
    }
}
