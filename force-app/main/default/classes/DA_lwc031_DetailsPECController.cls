// ═══════════════════════════════════════════════════════════════
// DA_lwc031_DetailsPECController — Onglet [Détails PEC]
// Workflow PEC : Etude de document → Expertise → Correction devis
//                → Etablissement PEC → Réparation
// ═══════════════════════════════════════════════════════════════
public with sharing class DA_lwc031_DetailsPECController {

    private static final List<String> ETAPES = new List<String>{
        'Étude de documents',
        'Expertise',
        'Correction du devis',
        'Établissement d\'une PEC',
        'Réparation'
    };

    // ── Constantes métier (valeurs de picklist / record types) ───────────────
    private static final String ETAPE_ETUDE_DOCUMENT  = 'Étude de documents';
    private static final String ETAPE_EXPERTISE       = 'Expertise';
    private static final String ETAPE_CORRECTION      = 'Correction du devis';
    private static final String ETAPE_ETABLISSEMENT_PEC = 'Établissement d\'une PEC';
    private static final String ETAPE_REPARATION        = 'Réparation';

    private static final String STATUT_ETUDE_DOC_TERMINEE  = 'Etude document terminée';
    private static final String STATUT_EXPERTISE_TERMINEE  = 'Expertise terminée';
    private static final String STATUT_CORRECTION_TERMINEE = 'Correction devis terminée';
    private static final String STATUT_PEC_ACCORDEE        = 'Prise en charge accordée';
    private static final String STATUT_INSTRUCTION_ANNULEE = 'Instruction annulée';
    private static final String STATUT_INSTRUCTION_TERMINEE = 'Instruction terminée';

    // Motifs d'annulation (valeurs de picklist MotifAnnulation__c)
    private static final String MOTIF_PASSAGE_AUTRE_TYPE = 'Passage à un autre type d\'instruction';
    private static final String MOTIF_DESISTEMENT        = 'Désistement de l\'assuré';

    // Statuts de mission (Case) considérés comme clôturés : une mission est
    // « en cours » tant que son statut n'appartient pas à cet ensemble.
    private static final Set<String> STATUTS_MISSION_CLOTUREE = new Set<String>{
        'Rejetée', 'Clôturé', 'Traitée'
    };

    private static final String TYPE_DOC_PEC_RETOURNEE = 'PEC retournée';

    private static final String STATUT_CORRECTION_CONFIRMEE = 'Confirmée';
    private static final String TYPE_DOC_DEVIS_DEFINITIF    = 'Devis définitif';
    private static final String TYPE_DOC_ACCORD_PEC         = 'ACCORD PRISE EN CHARGE MAT';
    private static final String TYPE_DOC_BON_SORTIE         = 'Bon de sortie MAT';
    private static final String TYPE_DOC_RAPPORT_POST_TRAVAUX = 'Rapport post travaux';

    private static final String PAIEMENT_FRANCHISE_COMPAGNIE = 'A la compagnie';
    private static final String OBLIGATION_RAPPORT_OUI       = 'Oui';

    private static final String NECESSITE_EXPERTISE_OUI = 'Oui';

    private static final String RT_MISSION                  = 'Mission';
    private static final String TYPE_PRESTATAIRE_EXPERT     = 'Expert Automobile';
    private static final String TYPE_PRESTATAIRE_GARAGISTE  = 'Garagiste';
    private static final String NATURE_MISSION_APPRECIATION = 'Appréciation';

    private static final Set<String> TYPES_DOC_DEVIS_INITIAL = new Set<String>{
        'Devis', 'Devis Initial', 'Devis estimatif'
    };

    private static final Set<String> TYPES_DOC_RAPPORT_EXPERTISE = new Set<String>{
        'Rapport d’expertise', 'Rapport d’évaluation', 'Rapport Additif'
    };

    private static final String FIELDS_INSTRUCTION =
        'Id, Name, Claim__c, Etape__c, Statut__c, ' +
        'MontantDevisInitial__c, DateReceptionDevisInitial__c, OrigineDevis__c, ' +
        'Reparateur__c, Reparateur__r.Name, NouveauReparateurNonConventionne__c, ' +
        'NomReparateur__c, IdentifiantFiscal__c, RemiseFondsDocumentaire__c, ' +
        'MontantApprecie__c, NecessiteExpertise__c, CommentaireDevisInitial__c, ' +
        'MontantAccordePEC__c, FranchisePourcentage__c, FranchiseMin__c, FranchiseMax__c, ' +
        'PaiementFranchise__c, PaiementFranchiseRecu__c, ObligationRapportExpertise__c, ' +
        'CommentairePEC__c, DateEnvoiPEC__c, DebutTravaux__c, MotifAnnulation__c';

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
        instr.RemiseFondsDocumentaire__c   = data.get('remiseFondsDocumentaire') == true;

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
        instr.PaiementFranchiseRecu__c      = data.get('paiementFranchiseRecu') == true;

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

    // ── Avancement du workflow : « Marquer étape comme terminée » ────────────

    /**
     * Résultat d'un contrôle de clôture d'étape renvoyé au LWC.
     */
    public class EtapeResultWrapper {
        @AuraEnabled public Boolean ok;
        @AuraEnabled public List<String> erreurs;     // libellés des contrôles KO
        @AuraEnabled public String nouvelleEtape;     // étape à surligner en vert
        @AuraEnabled public String nouveauStatut;     // statut appliqué à l'instruction
        @AuraEnabled public Boolean expertiseIgnoree; // true => étape Expertise grisée (non activée)
        @AuraEnabled public Boolean instructionTerminee; // true => fin de parcours (étape Réparation)

        public EtapeResultWrapper() {
            this.ok = false;
            this.erreurs = new List<String>();
            this.expertiseIgnoree = false;
            this.instructionTerminee = false;
        }
    }

    /**
     * @description Déclenche les contrôles de clôture de l'étape courante.
     *              Si tous les contrôles sont OK : met à jour le statut /
     *              l'étape de l'instruction et renvoie l'étape suivante à
     *              surligner. Sinon, renvoie la liste des contrôles KO sans
     *              faire avancer le workflow.
     * @param instructionId Id de l'instruction à contrôler
     * @return EtapeResultWrapper
     */
    @AuraEnabled
    public static EtapeResultWrapper marquerEtapeTerminee(Id instructionId) {
        Instruction__c instr = Database.query(
            'SELECT ' + FIELDS_INSTRUCTION + ' FROM Instruction__c WHERE Id = :instructionId LIMIT 1'
        );
        String etape = String.isBlank(instr.Etape__c) ? ETAPES[0] : instr.Etape__c;

        if (etape == ETAPE_ETUDE_DOCUMENT) {
            return controlerEtudeDocument(instr);
        }
        if (etape == ETAPE_EXPERTISE) {
            return controlerExpertise(instr);
        }
        if (etape == ETAPE_CORRECTION) {
            return controlerCorrectionDevis(instr);
        }
        if (etape == ETAPE_ETABLISSEMENT_PEC) {
            return controlerEtablissementPEC(instr);
        }
        if (etape == ETAPE_REPARATION) {
            return controlerReparation(instr);
        }

        // Aucun cas connu : avancement simple (sécurité).
        EtapeResultWrapper res = new EtapeResultWrapper();
        res.ok = true;
        res.nouvelleEtape = passerEtapeSuivante(instructionId);
        return res;
    }

    /**
     * @description Étape 1 — Etude de document. Contrôles CR1 à CR4.
     * @param instr Instruction chargée (champs FIELDS_INSTRUCTION)
     * @return EtapeResultWrapper
     */
    private static EtapeResultWrapper controlerEtudeDocument(Instruction__c instr) {
        EtapeResultWrapper res = new EtapeResultWrapper();
        Boolean expertiseRequise = (instr.NecessiteExpertise__c == NECESSITE_EXPERTISE_OUI);

        // CR1 : un document de type Devis / Devis Initial / Devis estimatif lié à l'instruction
        Integer nbDevis = [
            SELECT COUNT()
            FROM Document_Link__c
            WHERE Instruction__c = :instr.Id
              AND Document__r.Type_de_document__c IN :TYPES_DOC_DEVIS_INITIAL
        ];
        if (nbDevis == 0) {
            res.erreurs.add('ajouter un devis à l\'instruction');
        }

        // CR2 : les données du bloc « Données devis initial » sont renseignées
        if (!estDevisInitialRenseigne(instr)) {
            res.erreurs.add('renseigner les données du devis initial reçu du client');
        }

        // CR3 : si expertise requise => au moins une mission avec un prestataire de type Expert
        if (expertiseRequise) {
            Integer nbMissionsExpert = [
                SELECT COUNT()
                FROM Case
                WHERE Instruction__c = :instr.Id
                  AND RecordType.DeveloperName = :RT_MISSION
                  AND TypePrestataire__c = :TYPE_PRESTATAIRE_EXPERT
            ];
            if (nbMissionsExpert == 0) {
                res.erreurs.add('missionner un expert');
            }
        }

        // CR4 : si expertise requise => action « Remise du fonds documentaire » cochée
        if (expertiseRequise && instr.RemiseFondsDocumentaire__c != true) {
            res.erreurs.add('remettre le fonds documentaire / billet d\'expertise à l\'expert');
        }

        if (!res.erreurs.isEmpty()) {
            return res; // KO : on bloque l'avancement
        }

        // Tous les contrôles OK : mise à jour statut + positionnement étape
        instr.Statut__c   = STATUT_ETUDE_DOC_TERMINEE;
        instr.Etape__c = expertiseRequise ? ETAPE_EXPERTISE : ETAPE_CORRECTION;
        update instr;

        res.ok = true;
        res.nouveauStatut   = STATUT_ETUDE_DOC_TERMINEE;
        res.nouvelleEtape   = instr.Etape__c;
        res.expertiseIgnoree = !expertiseRequise; // expertise non activée => grisée
        return res;
    }

    /**
     * @description Vérifie que le bloc « Données devis initial » est complet (CR2).
     * @param instr Instruction chargée
     * @return Boolean
     */
    private static Boolean estDevisInitialRenseigne(Instruction__c instr) {
        Boolean reparateurOk = (instr.Reparateur__c != null)
            || (instr.NouveauReparateurNonConventionne__c == true && String.isNotBlank(instr.NomReparateur__c));
        return instr.MontantDevisInitial__c != null
            && instr.DateReceptionDevisInitial__c != null
            && String.isNotBlank(instr.OrigineDevis__c)
            && String.isNotBlank(instr.NecessiteExpertise__c)
            && reparateurOk;
    }

    /**
     * @description Étape 2 — Expertise. Contrôles CR1 et CR2 sur les missions
     *              d'expertise (prestataire Expert, nature ≠ Appréciation).
     * @param instr Instruction chargée (champs FIELDS_INSTRUCTION)
     * @return EtapeResultWrapper
     */
    private static EtapeResultWrapper controlerExpertise(Instruction__c instr) {
        EtapeResultWrapper res = new EtapeResultWrapper();

        // Missions d'expertise concernées : prestataire Expert, nature ≠ Appréciation
        List<Case> missionsExpertise = [
            SELECT Id, RapportRecu__c, DateReceptionRapport__c
            FROM Case
            WHERE Instruction__c = :instr.Id
              AND RecordType.DeveloperName = :RT_MISSION
              AND TypePrestataire__c = :TYPE_PRESTATAIRE_EXPERT
              AND NatureMission__c != :NATURE_MISSION_APPRECIATION
        ];

        if (!missionsExpertise.isEmpty()) {
            // CR1 : un document de type rapport d'expertise/évaluation/additif est lié à l'instruction
            Integer nbRapports = [
                SELECT COUNT()
                FROM Document_Link__c
                WHERE Instruction__c = :instr.Id
                  AND Document__r.Type_de_document__c IN :TYPES_DOC_RAPPORT_EXPERTISE
            ];
            if (nbRapports == 0) {
                res.erreurs.add('ajouter un rapport d\'expertise à l\'instruction');
            }

            // CR2 : sur chaque mission, rapport reçu = oui ET date de réception renseignée
            Boolean receptionComplete = true;
            for (Case mission : missionsExpertise) {
                if (mission.RapportRecu__c != true || mission.DateReceptionRapport__c == null) {
                    receptionComplete = false;
                    break;
                }
            }
            if (!receptionComplete) {
                res.erreurs.add('renseigner la réception du rapport (rapport reçu et date de réception) sur la ou les missions d\'expertise');
            }
        }

        if (!res.erreurs.isEmpty()) {
            return res; // KO : on bloque l'avancement
        }

        // Tous les contrôles OK : statut + positionnement sur Correction devis
        instr.Statut__c   = STATUT_EXPERTISE_TERMINEE;
        instr.Etape__c = ETAPE_CORRECTION;
        update instr;

        res.ok = true;
        res.nouveauStatut = STATUT_EXPERTISE_TERMINEE;
        res.nouvelleEtape = ETAPE_CORRECTION;
        return res;
    }

    /**
     * @description Étape 3 — Correction devis. Contrôles CR1 et CR2.
     * @param instr Instruction chargée (champs FIELDS_INSTRUCTION)
     * @return EtapeResultWrapper
     */
    private static EtapeResultWrapper controlerCorrectionDevis(Instruction__c instr) {
        EtapeResultWrapper res = new EtapeResultWrapper();

        // CR1 : au moins une ligne de correction au statut « Confirmée »
        Integer nbCorrectionsConfirmees = [
            SELECT COUNT()
            FROM Correction_Devis__c
            WHERE Instruction__c = :instr.Id
              AND StatutCorrection__c = :STATUT_CORRECTION_CONFIRMEE
        ];
        if (nbCorrectionsConfirmees == 0) {
            res.erreurs.add('saisir une correction de devis qui soit confirmée par un réparateur');
        }

        // CR2 : un document de type « Devis définitif » est lié à l'instruction
        Integer nbDevisDefinitif = [
            SELECT COUNT()
            FROM Document_Link__c
            WHERE Instruction__c = :instr.Id
              AND Document__r.Type_de_document__c = :TYPE_DOC_DEVIS_DEFINITIF
        ];
        if (nbDevisDefinitif == 0) {
            res.erreurs.add('ajouter un document de type « Devis définitif » à l\'instruction');
        }

        if (!res.erreurs.isEmpty()) {
            return res; // KO : on bloque l'avancement
        }

        // Tous les contrôles OK : statut + positionnement sur Etablissement PEC
        instr.Statut__c   = STATUT_CORRECTION_TERMINEE;
        instr.Etape__c = ETAPE_ETABLISSEMENT_PEC;
        update instr;

        res.ok = true;
        res.nouveauStatut = STATUT_CORRECTION_TERMINEE;
        res.nouvelleEtape = ETAPE_ETABLISSEMENT_PEC;
        return res;
    }

    /**
     * @description Étape 4 — Etablissement PEC. Contrôles CR1 à CR4.
     * @param instr Instruction chargée (champs FIELDS_INSTRUCTION)
     * @return EtapeResultWrapper
     */
    private static EtapeResultWrapper controlerEtablissementPEC(Instruction__c instr) {
        EtapeResultWrapper res = new EtapeResultWrapper();

        // CR1 : une mission garagiste est enregistrée sur l'instruction
        Integer nbMissionsGaragiste = [
            SELECT COUNT()
            FROM Case
            WHERE Instruction__c = :instr.Id
              AND RecordType.DeveloperName = :RT_MISSION
              AND TypePrestataire__c = :TYPE_PRESTATAIRE_GARAGISTE
        ];
        if (nbMissionsGaragiste == 0) {
            res.erreurs.add('missionner un garagiste');
        }

        // CR2 : un document de type « ACCORD PRISE EN CHARGE MAT » est lié à l'instruction
        Integer nbAccordPEC = [
            SELECT COUNT()
            FROM Document_Link__c
            WHERE Instruction__c = :instr.Id
              AND Document__r.Type_de_document__c = :TYPE_DOC_ACCORD_PEC
        ];
        if (nbAccordPEC == 0) {
            res.erreurs.add('éditer, cacheter et ajouter à la GED le bon de PEC');
        }

        // CR3 : l'envoi de la prise en charge est effectué (date d'envoi renseignée)
        if (instr.DateEnvoiPEC__c == null) {
            res.erreurs.add('avoir envoyé la PEC au garagiste');
        }

        // CR4 : si paiement franchise « A la compagnie », le paiement reçu doit être coché
        if (instr.PaiementFranchise__c == PAIEMENT_FRANCHISE_COMPAGNIE && instr.PaiementFranchiseRecu__c != true) {
            res.erreurs.add('avoir signalé la réception du paiement de la franchise par l\'assuré');
        }

        if (!res.erreurs.isEmpty()) {
            return res; // KO : on bloque l'avancement
        }

        // Tous les contrôles OK : statut + positionnement sur Réparation
        instr.Statut__c   = STATUT_PEC_ACCORDEE;
        instr.Etape__c = ETAPE_REPARATION;
        update instr;

        res.ok = true;
        res.nouveauStatut = STATUT_PEC_ACCORDEE;
        res.nouvelleEtape = ETAPE_REPARATION;
        return res;
    }

    /**
     * @description Étape 5 — Réparation. Contrôles CR1 et CR2. Clôture de
     *              l'instruction (statut « Instruction terminée »).
     * @param instr Instruction chargée (champs FIELDS_INSTRUCTION)
     * @return EtapeResultWrapper
     */
    private static EtapeResultWrapper controlerReparation(Instruction__c instr) {
        EtapeResultWrapper res = new EtapeResultWrapper();

        // CR1 : un document de type « Bon de sortie MAT » est lié à l'instruction
        Integer nbBonSortie = [
            SELECT COUNT()
            FROM Document_Link__c
            WHERE Instruction__c = :instr.Id
              AND Document__r.Type_de_document__c = :TYPE_DOC_BON_SORTIE
        ];
        if (nbBonSortie == 0) {
            res.erreurs.add('réceptionner le bon de sortie et l\'ajouter à la GED');
        }

        // CR2 : si expertise post-travaux requise, un « Rapport post travaux » doit être lié
        if (instr.ObligationRapportExpertise__c == OBLIGATION_RAPPORT_OUI) {
            Integer nbRapportPostTravaux = [
                SELECT COUNT()
                FROM Document_Link__c
                WHERE Instruction__c = :instr.Id
                  AND Document__r.Type_de_document__c = :TYPE_DOC_RAPPORT_POST_TRAVAUX
            ];
            if (nbRapportPostTravaux == 0) {
                res.erreurs.add('réceptionner le rapport d\'expertise post travaux et l\'ajouter à la GED');
            }
        }

        if (!res.erreurs.isEmpty()) {
            return res; // KO : on bloque la clôture
        }

        // Tous les contrôles OK : clôture de l'instruction (terminée)
        instr.Statut__c = STATUT_INSTRUCTION_TERMINEE;
        update instr;

        res.ok = true;
        res.nouveauStatut = STATUT_INSTRUCTION_TERMINEE;
        res.nouvelleEtape = ETAPE_REPARATION; // reste sur la dernière étape
        res.instructionTerminee = true;
        return res;
    }

    @AuraEnabled
    public static String passerEtapeSuivante(Id instructionId) {
        Instruction__c instr = [SELECT Id, Etape__c FROM Instruction__c WHERE Id = :instructionId LIMIT 1];

        String current = String.isBlank(instr.Etape__c) ? ETAPES[0] : instr.Etape__c;
        Integer idx = ETAPES.indexOf(current);
        if (idx < 0) idx = 0;
        if (idx >= ETAPES.size() - 1) {
            throw new AuraHandledException('L\'instruction est déjà à la dernière étape du workflow.');
        }

        instr.Etape__c = ETAPES[idx + 1];
        update instr;
        return instr.Etape__c;
    }

    /**
     * Navigation directe vers une étape via le stepper (avant / arrière).
     */
    @AuraEnabled
    public static String setEtape(Id instructionId, String etape) {
        if (!ETAPES.contains(etape)) {
            throw new AuraHandledException('Étape inconnue : ' + etape);
        }
        update new Instruction__c(Id = instructionId, Etape__c = etape);
        return etape;
    }

    // ── Annulation de l'instruction ──────────────────────────────────────────

    /**
     * @description Résultat d'une demande d'annulation d'instruction renvoyé au LWC.
     */
    public class AnnulationResultWrapper {
        @AuraEnabled public Boolean ok;
        @AuraEnabled public String message; // message d'alerte affiché lorsqu'un contrôle est KO

        public AnnulationResultWrapper() {
            this.ok = false;
        }
    }

    /**
     * @description Annule une instruction PEC. Le bouton « Annuler instruction »
     *              est actif à toutes les étapes du parcours ; les contrôles
     *              appliqués dépendent de l'étape courante (RG1 à RG7). Si un
     *              contrôle est KO, renvoie le message d'alerte adéquat sans
     *              modifier l'instruction. Sinon, positionne le statut de
     *              l'instruction à « Instruction annulée ».
     * @author      D&A Technologies | 29-06-2026
     * @param instructionId Id de l'instruction à annuler
     * @param motif         Motif d'annulation sélectionné (valeur MotifAnnulation__c)
     * @return AnnulationResultWrapper
     */
    @AuraEnabled
    public static AnnulationResultWrapper annulerInstruction(Id instructionId, String motif) {
        if (instructionId == null) {
            throw new AuraHandledException('Instruction introuvable.');
        }
        if (String.isBlank(motif)) {
            throw new AuraHandledException('Veuillez sélectionner un motif d\'annulation.');
        }

        Instruction__c instr = Database.query(
            'SELECT ' + FIELDS_INSTRUCTION + ' FROM Instruction__c WHERE Id = :instructionId LIMIT 1'
        );
        String etape = String.isBlank(instr.Etape__c) ? ETAPES[0] : instr.Etape__c;

        AnnulationResultWrapper res = new AnnulationResultWrapper();

        // Contrôles d'annulation selon l'étape du parcours
        if (etape == ETAPE_ETUDE_DOCUMENT || etape == ETAPE_EXPERTISE) {
            res.message = controlerAnnulationEtudeExpertise(instr.Id);          // RG1
        } else if (etape == ETAPE_CORRECTION || etape == ETAPE_ETABLISSEMENT_PEC) {
            res.message = controlerAnnulationCorrectionPEC(instr.Id);           // RG2 / RG3
        } else if (etape == ETAPE_REPARATION) {
            res.message = controlerAnnulationReparation(instr, motif);          // RG4 à RG7
        }

        if (String.isNotBlank(res.message)) {
            return res; // un contrôle est KO : on arrête l'opération
        }

        // Tous les contrôles OK : l'instruction passe à « Instruction annulée »
        instr.Statut__c          = STATUT_INSTRUCTION_ANNULEE;
        instr.MotifAnnulation__c = motif;
        update instr;

        res.ok = true;
        return res;
    }

    /**
     * @description Étapes Etude de documents / Expertise — RG1 : aucune mission
     *              d'expert ne doit être en cours.
     * @param instructionId Id de l'instruction
     * @return String message d'alerte (null si OK)
     */
    private static String controlerAnnulationEtudeExpertise(Id instructionId) {
        if (missionExpertEnCours(instructionId)) {
            return 'Vous ne pouvez pas annuler cette instruction. Il faut d\'abord annuler, '
                + 'régler ou la solder la mission d\'expert en cours avant d\'annuler l\'instruction';
        }
        return null;
    }

    /**
     * @description Étapes Correction devis / Etablissement PEC — RG2 (mission
     *              expert) et RG3 (mission garagiste) : aucune ne doit être en cours.
     * @param instructionId Id de l'instruction
     * @return String message d'alerte (null si OK)
     */
    private static String controlerAnnulationCorrectionPEC(Id instructionId) {
        if (missionExpertEnCours(instructionId)) {
            return 'Vous ne pouvez pas annuler cette instruction. Il faut d\'abord annuler, '
                + 'régler ou la solder la mission en cours avant d\'annuler l\'instruction';
        }
        if (missionGaragisteEnCours(instructionId)) {
            return 'Vous ne pouvez pas annuler cette instruction. Il faut d\'abord annuler '
                + 'la mission du garagiste en cours avant d\'annuler l\'instruction';
        }
        return null;
    }

    /**
     * @description Étape Réparation — RG4 (mission expert), RG5 (mission
     *              garagiste), RG6 (début des travaux), RG7 (PEC retournée
     *              requise pour le motif « retard dans le démarrage des travaux »).
     * @param instr Instruction chargée (champs FIELDS_INSTRUCTION)
     * @param motif Motif d'annulation sélectionné
     * @return String message d'alerte (null si OK)
     */
    private static String controlerAnnulationReparation(Instruction__c instr, String motif) {
        // RG4 : mission d'expert en cours
        if (missionExpertEnCours(instr.Id)) {
            return 'Vous ne pouvez pas annuler cette instruction. Il faut d\'abord annuler, '
                + 'régler ou la solder la mission en cours avant d\'annuler l\'instruction';
        }
        // RG5 : mission de garagiste en cours
        if (missionGaragisteEnCours(instr.Id)) {
            return 'Vous ne pouvez pas annuler cette instruction. Il faut d\'abord annuler '
                + 'la mission du garagiste en cours avant d\'annuler l\'instruction';
        }
        // RG6 : option « Début des travaux » cochée
        if (instr.DebutTravaux__c == true) {
            return 'Vous ne pouvez pas annuler une instruction dont les travaux sont entamés. '
                + 'Veuillez décocher l\'option si vous voulez poursuivre';
        }
        // RG7 : motif « retard dans le démarrage des travaux » (= Passage à un autre
        // type d'instruction à l'étape Réparation) => un document « PEC retournée »
        // doit être ajouté à l'instruction.
        if (motif == MOTIF_PASSAGE_AUTRE_TYPE) {
            Integer nbPecRetournee = [
                SELECT COUNT()
                FROM Document_Link__c
                WHERE Instruction__c = :instr.Id
                  AND Document__r.Type_de_document__c = :TYPE_DOC_PEC_RETOURNEE
            ];
            if (nbPecRetournee == 0) {
                return 'Vous ne pouvez pas annuler une instruction sans ajouter la PEC '
                    + 'retournée par le client. Veuillez ajouter la PEC retournée à l\'instruction';
            }
        }
        return null;
    }

    /**
     * @description Indique si une mission (Case) de prestataire de type Expert
     *              est en cours sur l'instruction (statut non clôturé).
     * @param instructionId Id de l'instruction
     * @return Boolean
     */
    private static Boolean missionExpertEnCours(Id instructionId) {
        Integer nb = [
            SELECT COUNT()
            FROM Case
            WHERE Instruction__c = :instructionId
              AND RecordType.DeveloperName = :RT_MISSION
              AND TypePrestataire__c = :TYPE_PRESTATAIRE_EXPERT
              AND Status NOT IN :STATUTS_MISSION_CLOTUREE
        ];
        return nb > 0;
    }

    /**
     * @description Indique si une mission (Case) de prestataire de type Garagiste
     *              est en cours sur l'instruction (statut non clôturé).
     * @param instructionId Id de l'instruction
     * @return Boolean
     */
    private static Boolean missionGaragisteEnCours(Id instructionId) {
        Integer nb = [
            SELECT COUNT()
            FROM Case
            WHERE Instruction__c = :instructionId
              AND RecordType.DeveloperName = :RT_MISSION
              AND TypePrestataire__c = :TYPE_PRESTATAIRE_GARAGISTE
              AND Status NOT IN :STATUTS_MISSION_CLOTUREE
        ];
        return nb > 0;
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
