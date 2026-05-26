public with sharing class DA_lwc026_ReaffectationController {

    // ─── Lecture ────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Id> getEligibleUserIds() {
        List<Id> ids = new List<Id>();
        for (User u : DM_Case.getEligibleUsers()) {
            ids.add(u.Id);
        }
        return ids;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getRequeteInfo(Id requeteId) {
        Case requete = DM_Case.getRequeteById(requeteId);
        return new Map<String, String>{
            'reaffecterAName'   => requete.ReaffecterA__r?.Name,
            'declarationNumber' => requete.Declaration_Liee__r?.CaseNumber,
            'motif'             => requete.Motif_Reaffectation__c
        };
    }

    // ─── Écriture ───────────────────────────────────────────────────

    @AuraEnabled
    public static String createRequeteReaffectation(Id declarationId, Id targetUserId, String motif) {
        User currentUser = DA_Utility.getCurrentUserInfo();
        if (currentUser.ManagerId == null) {
            throw new AuraHandledException(
                'Vous n\'avez pas de manager renseigné dans votre profil. ' +
                'Veuillez contacter votre administrateur.'
            );
        }
        return EM_Case.upsertRequeteReaffectation(declarationId, targetUserId, motif, currentUser.ManagerId);
    }

    @AuraEnabled
    public static void validerReaffectation(Id requeteId) {
        EM_Case.validerReaffectation(requeteId);
    }

    @AuraEnabled
    public static void rejeterReaffectation(Id requeteId, String motif) {
        if (String.isBlank(motif)) {
            throw new AuraHandledException('Le motif de rejet est obligatoire.');
        }
        EM_Case.rejeterReaffectation(requeteId, motif);
    }
}