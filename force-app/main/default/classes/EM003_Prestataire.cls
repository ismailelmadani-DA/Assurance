public with sharing class EM003_Prestataire {

    private static final Map<String, String> TYPE_PREFIX = new Map<String, String>{
        'Expert Automobile' => 'EXP', 'Garagiste' => 'GAR', 'Avocat' => 'AVO',
        'Médecin' => 'MED', 'Clinique' => 'CLI', 'Centre radiologique' => 'RAD',
        'Pharmacie' => 'PHA', 'Hôpital' => 'HOP', 'Enquêteur' => 'ENQ'
    };

    public static void validatePrestataire(DA_lwc016_prestataireListController.SaveRequest req) {
        if (String.isBlank(req.name)) throw new AuraHandledException('Le nom est obligatoire.');
        if (String.isBlank(req.type)) throw new AuraHandledException('Le type est obligatoire.');
    }

    public static String generateUniqueCode(String type) {
        String prefix = TYPE_PREFIX.containsKey(type) ? TYPE_PREFIX.get(type) : 'PRE';
        Integer count = DM003_Prestataire.countPrestatairesByType(type);
        return prefix + '-' + String.valueOf(count + 1).leftPad(4, '0');
    }

    public static Account mapRequestToAccount(DA_lwc016_prestataireListController.SaveRequest req) {
        Account acc = new Account();
        if (String.isNotBlank(req.id)) acc.Id = req.id;

        acc.RecordTypeId         = DM003_Prestataire.getPrestataireRTId();
        acc.Name                 = req.name;
        acc.TypeDePrestataire__c = req.type;
        acc.Phone                = req.phone;
        acc.Email__c             = req.email;
        acc.Ville__c             = req.ville;
        acc.Adresse__c           = req.adresse;
        acc.Pays__c              = String.isNotBlank(req.pays) ? req.pays : 'Maroc';

        // Création → toujours générer le code
        // Modification → générer seulement si le type a changé  ← MODIFIÉ ✅
        Boolean isNew       = String.isBlank(req.id);
        Boolean typeChanged = !isNew 
                              && String.isNotBlank(req.oldType) 
                              && req.oldType != req.type;

        if (isNew || typeChanged) {
            acc.codeTier__c = generateUniqueCode(req.type);
        }

        return acc;
    }

    public static RIB__c mapRequestToRib(DA_lwc016_prestataireListController.SaveRequest req, Id accId) {
        if (String.isBlank(req.rib) && String.isBlank(req.banque)) return null;

        RIB__c rib = new RIB__c();
        if (String.isNotBlank(req.ribId)) rib.Id = req.ribId;
        rib.ParticipantAccount__c = accId;
        rib.CodeBanque__c         = req.banque;
        rib.RIB__c                = req.rib;
        rib.Actif__c              = true;
        rib.Statut__c             = 'RIB Validé';
        return rib;
    }

    public static void upsertPrestataire(Account acc, RIB__c rib) {
        upsert acc;
        if (rib != null) {
            rib.ParticipantAccount__c = acc.Id;
            upsert rib;
        }
    }
}