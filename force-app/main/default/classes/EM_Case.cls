public with sharing class EM_Case {

    // ─── Réaffectation ──────────────────────────────────────────────

    public static Id upsertRequeteReaffectation(Id declarationId, Id targetUserId, String motif, Id managerId) {
        Case existante = DM_Case.getRequeteReaffectationExistante(declarationId);

        if (existante == null) {
            return insertRequeteReaffectation(declarationId, targetUserId, motif, managerId);
        }

        String statut = existante.Status;

        if (statut == 'Clôturée') {
            throw new AuraHandledException(
                'Cette déclaration est déjà clôturée. Aucune réaffectation possible.'
            );
        }

        if (statut == 'Rejetée') {
            deleteRequete(existante.Id);
            return insertRequeteReaffectation(declarationId, targetUserId, motif, managerId);
        }

        existante.ReaffecterA__c         = targetUserId;
        existante.Motif_Reaffectation__c = motif;

        if (statut == 'En cours') {
            existante.Status  = 'Initiale';
            existante.OwnerId = managerId;
        }

        return updateRequete(existante);
    }

    public static void validerReaffectation(Id requeteId) {
        Case requete = DM_Case.getRequeteById(requeteId);
        requete.OwnerId = requete.ReaffecterA__c;
        requete.Status  = 'En cours';
        updateRequete(requete);
    }

    public static void rejeterReaffectation(Id requeteId, String motif) {
        Case requete = DM_Case.getRequeteById(requeteId);
        requete.OwnerId       = requete.CreatedById;
        requete.Status        = 'Rejetée';
        requete.MotifRejet__c = motif;
        updateRequete(requete);
    }

    // ─── DA_lwc025 ──────────────────────────────────────────────────

    public static void closeCase(Id recordId) {
        update new Case(Id = recordId, Status = 'Clôturé');
    }

    public static void cancelCase(Id recordId) {
        update new Case(Id = recordId, Status = 'Annulé');
    }

    public static void takeOverCase(Id recordId) {
        update new Case(Id = recordId, OwnerId = UserInfo.getUserId(), Status = 'En cours');
    }

    // ─── DML privés ─────────────────────────────────────────────────

    private static Id insertRequeteReaffectation(Id declarationId, Id targetUserId, String motif, Id managerId) {
        Case declaration = DM_Case.getDeclarationById(declarationId);
        Case requete = new Case(
            RecordTypeId           = DM_Case.getRequeteRecordTypeId(),
            SourceRequete__c       = 'Déclaration',
            CategorieRequete__c    = 'Réaffectation',
            TypeRequete__c         = 'Réaffecter la déclaration',
            Priority               = 'Normale',
            Status                 = 'Initiale',
            OwnerId                = managerId,
            ReaffecterA__c         = targetUserId,
            Motif_Reaffectation__c = motif,
            Declaration_Liee__c    = declarationId,
            Delais_Traitement__c   = 7,
            Police__c              = declaration.Police__c,
            Vehicule__c            = declaration.Vehicule__c,
            DateOfOccurrence__c    = declaration.DateOfOccurrence__c
        );
        insert requete;
        return requete.Id;
    }

    private static Id updateRequete(Case requete) {
        update requete;
        return requete.Id;
    }

    private static void deleteRequete(Id requeteId) {
        delete new Case(Id = requeteId);
    }
}