// ═══════════════════════════════════════════════════════════════
// DA_lwc031_DetailsPECController — Onglet [Détails PEC]
// Workflow PEC : Etude de document → Expertise → Correction devis
//                → Etablissement PEC → Réparation
// ═══════════════════════════════════════════════════════════════
public with sharing class DA_lwc031_DetailsPECController {

    private static final List<String> ETAPES = new List<String>{
        'Etude de document',
        'Expertise',
        'Correction devis',
        'Etablissement PEC',
        'Réparation'
    };

    private static final String FIELDS_INSTRUCTION =
        'Id, Name, Claim__c, EtapePEC__c, ' +
        'MontantDevisInitial__c, DateReceptionDevisInitial__c, OrigineDevis__c, ' +
        'Reparateur__c, Reparateur__r.Name, NouveauReparateurNonConventionne__c, ' +
        'NomReparateur__c, IdentifiantFiscal__c, ' +
        'MontantApprecie__c, NecessiteExpertise__c, CommentaireDevisInitial__c, ' +
        'MontantAccordePEC__c, FranchisePourcentage__c, FranchiseMin__c, FranchiseMax__c, ' +
        'PaiementFranchise__c, ObligationRapportExpertise__c, CommentairePEC__c, DateEnvoiPEC__c';

    // ── Wrapper ──────────────────────────────────────────────────────────────
    public class DetailsPECWrapper {
        @AuraEnabled public Instruction__c instruction;
        @AuraEnabled public List<Correction_Devis__c> corrections;
        @AuraEnabled public Date dateSinistre;
        @AuraEnabled public Date dateDeclaration;
    }

    // ── Lecture ──────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static DetailsPECWrapper getDetailsPEC(Id instructionId) {
        if (instructionId == null) {
            return null; // le wire se déclenche avant que recordId soit disponible
        }

        DetailsPECWrapper wrapper = new DetailsPECWrapper();
        wrapper.instruction = (Instruction__c) DA_Utility.getById(
            FIELDS_INSTRUCTION, 'Instruction__c', instructionId
        );
        if (wrapper.instruction == null) {
            throw new AuraHandledException('Instruction introuvable.');
        }

        wrapper.corrections = getCorrections(instructionId);

        // RG1 (devis initial) : dates de référence du sinistre / de la déclaration
        if (wrapper.instruction.Claim__c != null) {
            List<Claim__c> claims = [
                SELECT Id, DateOfOccurrence__c, Case__r.DateOfDeclarationCreation__c
                FROM Claim__c
                WHERE Id = :wrapper.instruction.Claim__c
                LIMIT 1
            ];
            if (!claims.isEmpty()) {
                if (claims[0].DateOfOccurrence__c != null) {
                    wrapper.dateSinistre = claims[0].DateOfOccurrence__c.date();
                }
                wrapper.dateDeclaration = claims[0].Case__r != null
                    ? claims[0].Case__r.DateOfDeclarationCreation__c
                    : null;
            }
        }
        return wrapper;
    }

    private static List<Correction_Devis__c> getCorrections(Id instructionId) {
        return [
            SELECT Id, Name, MontantDevisCorrige__c, OrigineCorrection__c,
                   Reparateur__c, Reparateur__r.Name, StatutCorrection__c, DateStatut__c,
                   CreatedDate
            FROM Correction_Devis__c
            WHERE Instruction__c = :instructionId
            ORDER BY CreatedDate ASC
        ];
    }

    /**
     * RG2 / RG3 : liste des garagistes filtrée sur le pays de l'utilisateur
     * connecté et sur le type conventionné / non conventionné.
     */
    @AuraEnabled
    public static List<Account> getGaragistes(Boolean conventionne) {
        Id rtId = DA_Utility.getRecordTypeId('Account', 'Prestataire');

        User currentUser = [SELECT Country FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String pays = currentUser.Country;

        String query = 'SELECT Id, Name, codeTier__c, Ville__c, Pays__c, Conventionne__c '
            + 'FROM Account '
            + 'WHERE RecordTypeId = :rtId '
            + 'AND TypeDePrestataire__c = \'Garagiste\' '
            + 'AND Conventionne__c = :conventionne ';
        if (String.isNotBlank(pays)) {
            query += 'AND Pays__c = :pays ';
        }
        query += 'ORDER BY Name LIMIT 200';

        return Database.query(query);
    }

    // ── US1 : Etape 1 — Etude de document (RG5) ──────────────────────────────
    @AuraEnabled
    public static void saveDevisInitial(Id instructionId, String payload) {
        Map<String, Object> data = parse(payload);
        Instruction__c instr = new Instruction__c(Id = instructionId);

        instr.MontantDevisInitial__c       = toDecimal(data.get('montantDevisInitial'));
        instr.DateReceptionDevisInitial__c = toDate(data.get('dateReceptionDevisInitial'));
        instr.OrigineDevis__c              = (String) data.get('origineDevis');
        instr.NouveauReparateurNonConventionne__c = data.get('nouveauReparateur') == true;
        instr.Reparateur__c                = toId(data.get('reparateurId'));
        instr.NomReparateur__c             = (String) data.get('nomReparateur');
        instr.IdentifiantFiscal__c         = (String) data.get('identifiantFiscal');
        instr.MontantApprecie__c           = toDecimal(data.get('montantApprecie'));
        instr.NecessiteExpertise__c        = (String) data.get('necessiteExpertise');
        instr.CommentaireDevisInitial__c   = (String) data.get('commentaire');

        // Contrôles champs obligatoires (RG5)
        if (instr.MontantDevisInitial__c == null)       throw new AuraHandledException('Le champ « Montant devis initial » est obligatoire.');
        if (instr.DateReceptionDevisInitial__c == null) throw new AuraHandledException('Le champ « Date réception devis initial » est obligatoire.');
        if (String.isBlank(instr.OrigineDevis__c))      throw new AuraHandledException('Le champ « Origine devis » est obligatoire.');
        if (String.isBlank(instr.NecessiteExpertise__c)) throw new AuraHandledException('Le champ « Nécessite une expertise ? » est obligatoire.');
        if (!instr.NouveauReparateurNonConventionne__c && instr.Reparateur__c == null) {
            throw new AuraHandledException('Veuillez sélectionner un réparateur ou cocher « Nouveau réparateur non conventionné ».');
        }
        if (instr.NouveauReparateurNonConventionne__c && String.isBlank(instr.NomReparateur__c)) {
            throw new AuraHandledException('Le champ « Nom réparateur » est obligatoire.');
        }

        // RG1 : la date de réception ne peut pas être antérieure à la date
        // sinistre ni à la date de déclaration
        DetailsPECWrapper ctx = getDetailsPEC(instructionId);
        if (ctx.dateSinistre != null && instr.DateReceptionDevisInitial__c < ctx.dateSinistre) {
            throw new AuraHandledException('La date de réception du devis ne peut pas être antérieure à la date du sinistre.');
        }
        if (ctx.dateDeclaration != null && instr.DateReceptionDevisInitial__c < ctx.dateDeclaration) {
            throw new AuraHandledException('La date de réception du devis ne peut pas être antérieure à la date de déclaration.');
        }

        update instr;
    }

    // ── US2 : Etape 2 — Expertise ────────────────────────────────────────────
    @AuraEnabled
    public static void saveExpertise(Id instructionId, String payload) {
        Map<String, Object> data = parse(payload);
        update new Instruction__c(
            Id                         = instructionId,
            MontantApprecie__c         = toDecimal(data.get('montantApprecie')),
            CommentaireDevisInitial__c = (String) data.get('commentaire')
        );
    }

    // ── US3 : Etape 3 — Correction devis (RG9) ───────────────────────────────
    @AuraEnabled
    public static void saveCorrection(Id instructionId, String payload) {
        Map<String, Object> data = parse(payload);
        Id correctionId = toId(data.get('id'));
        String statut   = (String) data.get('statutCorrection');

        if (String.isBlank(statut)) {
            throw new AuraHandledException('Le champ « Statut correction » est obligatoire.');
        }

        if (correctionId == null) {
            // Nouvelle ligne : tous les champs obligatoires
            Decimal montant     = toDecimal(data.get('montantDevisCorrige'));
            String origine      = (String) data.get('origineCorrection');
            Id reparateurId     = toId(data.get('reparateurId'));

            if (montant == null)              throw new AuraHandledException('Le champ « Montant devis corrigé » est obligatoire.');
            if (String.isBlank(origine))      throw new AuraHandledException('Le champ « Origine correction » est obligatoire.');
            if (reparateurId == null)         throw new AuraHandledException('Le champ « Réparateur » est obligatoire.');

            insert new Correction_Devis__c(
                Instruction__c         = instructionId,
                MontantDevisCorrige__c = montant,
                OrigineCorrection__c   = origine,
                Reparateur__c          = reparateurId,
                StatutCorrection__c    = statut,
                DateStatut__c          = Date.today()   // RG8 : date système
            );
        } else {
            // RG4/RG5/RG6 : seuls le statut (RG7) et la date statut évoluent
            Correction_Devis__c existing = [
                SELECT Id, StatutCorrection__c FROM Correction_Devis__c
                WHERE Id = :correctionId LIMIT 1
            ];
            existing.StatutCorrection__c = statut;
            existing.DateStatut__c       = Date.today(); // RG8
            update existing;
        }
    }

    // ── US4 : Etape 4 — Etablissement PEC (RG4) ──────────────────────────────
    @AuraEnabled
    public static void savePriseEnCharge(Id instructionId, String payload) {
        Map<String, Object> data = parse(payload);
        Instruction__c instr = new Instruction__c(Id = instructionId);

        instr.MontantAccordePEC__c          = toDecimal(data.get('montantAccordePEC'));
        instr.FranchisePourcentage__c       = toDecimal(data.get('franchisePourcentage'));
        instr.FranchiseMin__c               = toDecimal(data.get('franchiseMin'));
        instr.FranchiseMax__c               = toDecimal(data.get('franchiseMax'));
        instr.PaiementFranchise__c          = (String) data.get('paiementFranchise');
        instr.ObligationRapportExpertise__c = (String) data.get('obligationRapportExpertise');
        instr.CommentairePEC__c             = (String) data.get('commentaire');
        instr.DateEnvoiPEC__c               = toDate(data.get('dateEnvoiPEC'));

        if (instr.MontantAccordePEC__c == null)              throw new AuraHandledException('Le champ « Montant accordée PEC » est obligatoire.');
        if (instr.FranchisePourcentage__c == null)           throw new AuraHandledException('Le champ « Franchise (en %) » est obligatoire.');
        if (instr.FranchisePourcentage__c > 100)             throw new AuraHandledException('La franchise ne peut pas dépasser 100 %.'); // RG2
        if (instr.FranchiseMin__c == null)                   throw new AuraHandledException('Le champ « Franchise Min » est obligatoire.');
        if (instr.FranchiseMax__c == null)                   throw new AuraHandledException('Le champ « Franchise MAX » est obligatoire.');
        if (String.isBlank(instr.PaiementFranchise__c))      throw new AuraHandledException('Le champ « Paiement de la franchise » est obligatoire.');
        if (String.isBlank(instr.ObligationRapportExpertise__c)) throw new AuraHandledException('Le champ « Obligation Rapport d\'expertise post travaux » est obligatoire.');
        if (instr.DateEnvoiPEC__c == null)                   throw new AuraHandledException('Le champ « Date d\'envoi de la PEC » est obligatoire.');

        update instr;
    }

    /**
     * RG4 (devis initial) : création d'une requête « Création prestataire »
     * affectée au gestionnaire « Admin fonctionnel » (case à cocher sur
     * l'utilisateur) du pays de l'utilisateur, avec notification cloche
     * pointant vers l'instruction.
     */
    @AuraEnabled
    public static Id creerRequetePrestataire(Id instructionId, String nomReparateur, String identifiantFiscal) {
        if (String.isBlank(nomReparateur)) {
            throw new AuraHandledException('Le champ « Nom réparateur » est obligatoire.');
        }

        Instruction__c instr = [SELECT Id, Name FROM Instruction__c WHERE Id = :instructionId LIMIT 1];

        User currentUser = [SELECT Country FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        Id ownerId = findAdminFonctionnel(currentUser.Country);

        Case requete = new Case(
            RecordTypeId         = DM_Case.getRequeteRecordTypeId(),
            SourceRequete__c     = 'Instruction',
            CategorieRequete__c  = 'Création prestataire',
            TypeRequete__c       = 'Création prestataire',
            Priority             = 'Haute',
            Status               = 'Initiale',
            OwnerId              = ownerId,
            Delais_Traitement__c = 2,   // 2 JH
            Subject              = 'Création prestataire — ' + nomReparateur,
            Description          = 'Demande de création d\'un nouveau réparateur non conventionné.\n'
                                 + 'Nom réparateur : ' + nomReparateur + '\n'
                                 + 'Identifiant fiscal : ' + (String.isBlank(identifiantFiscal) ? '-' : identifiantFiscal) + '\n'
                                 + 'Réf source (instruction) : ' + instr.Id + ' (' + instr.Name + ')'
        );
        insert requete;

        sendNotificationCreationPrestataire(ownerId, instr, nomReparateur);
        return requete.Id;
    }

    // ── Avancement du workflow ───────────────────────────────────────────────
    @AuraEnabled
    public static String passerEtapeSuivante(Id instructionId) {
        Instruction__c instr = [SELECT Id, EtapePEC__c FROM Instruction__c WHERE Id = :instructionId LIMIT 1];

        String current = String.isBlank(instr.EtapePEC__c) ? ETAPES[0] : instr.EtapePEC__c;
        Integer idx = ETAPES.indexOf(current);
        if (idx < 0) idx = 0;
        if (idx >= ETAPES.size() - 1) {
            throw new AuraHandledException('L\'instruction est déjà à la dernière étape du workflow.');
        }

        instr.EtapePEC__c = ETAPES[idx + 1];
        update instr;
        return instr.EtapePEC__c;
    }

    /**
     * Navigation directe vers une étape via le stepper (avant / arrière).
     */
    @AuraEnabled
    public static String setEtape(Id instructionId, String etape) {
        if (!ETAPES.contains(etape)) {
            throw new AuraHandledException('Étape inconnue : ' + etape);
        }
        update new Instruction__c(Id = instructionId, EtapePEC__c = etape);
        return etape;
    }

    // ── Privé ────────────────────────────────────────────────────────────────
    // Le gestionnaire « Admin fonctionnel » est désigné via la case à cocher
    // AdminFonctionnel__c sur l'utilisateur (et non plus via un profil).
    private static Id findAdminFonctionnel(String pays) {
        List<User> admins;
        if (String.isNotBlank(pays)) {
            admins = [
                SELECT Id FROM User
                WHERE AdminFonctionnel__c = true AND IsActive = true AND Country = :pays
                LIMIT 1
            ];
            if (!admins.isEmpty()) return admins[0].Id;
        }
        admins = [
            SELECT Id FROM User
            WHERE AdminFonctionnel__c = true AND IsActive = true
            LIMIT 1
        ];
        return admins.isEmpty() ? UserInfo.getUserId() : admins[0].Id;
    }

    private static void sendNotificationCreationPrestataire(Id ownerId, Instruction__c instr, String nomReparateur) {
        List<CustomNotificationType> notifTypes = [
            SELECT Id FROM CustomNotificationType
            WHERE DeveloperName = 'Flag_Sinistre_Notification'
            LIMIT 1
        ];
        if (notifTypes.isEmpty()) return;

        try {
            Messaging.CustomNotification notif = new Messaging.CustomNotification();
            notif.setNotificationTypeId(notifTypes[0].Id);
            notif.setTitle('Création prestataire — ' + nomReparateur);
            notif.setBody('Une requête de création du prestataire « ' + nomReparateur
                + ' » a été générée depuis l\'instruction ' + instr.Name + '.');
            notif.setTargetId(instr.Id); // lien vers l'instruction d'origine
            notif.send(new Set<String>{ String.valueOf(ownerId) });
        } catch (Exception e) {
            System.debug('Erreur envoi notification: ' + e.getMessage());
        }
    }

    private static Map<String, Object> parse(String payload) {
        if (String.isBlank(payload)) {
            throw new AuraHandledException('Aucune donnée à enregistrer.');
        }
        return (Map<String, Object>) JSON.deserializeUntyped(payload);
    }

    private static Decimal toDecimal(Object value) {
        if (value == null) return null;
        if (value instanceof Decimal) return (Decimal) value;
        String s = String.valueOf(value);
        return String.isBlank(s) ? null : Decimal.valueOf(s);
    }

    private static Date toDate(Object value) {
        if (value == null) return null;
        String s = String.valueOf(value);
        return String.isBlank(s) ? null : Date.valueOf(s);
    }

    private static Id toId(Object value) {
        if (value == null) return null;
        String s = String.valueOf(value);
        return String.isBlank(s) ? null : (Id) s;
    }
}
