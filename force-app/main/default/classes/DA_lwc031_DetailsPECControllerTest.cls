/**
 * @description       : Classe de test de DA_lwc031_DetailsPECController.
 *                      Couvre les contrôles de clôture de l'étape 1 (Etude de
 *                      document) : CR1 (devis), CR2 (données devis initial),
 *                      CR3 (mission expert), CR4 (remise fonds documentaire).
 * @author            : D&A Technologies
 * @group             : Tests
 * @last modified on  : 24-06-2026
 */
@isTest
private class DA_lwc031_DetailsPECControllerTest {

    private static final String ETAPE_ETUDE_DOCUMENT      = 'Étude de documents';
    private static final String ETAPE_EXPERTISE           = 'Expertise';
    private static final String ETAPE_CORRECTION          = 'Correction du devis';
    private static final String ETAPE_ETABLISSEMENT_PEC   = 'Établissement d\'une PEC';
    private static final String ETAPE_REPARATION          = 'Réparation';
    private static final String STATUT_ETUDE_DOC_TERMINEE = 'Etude document terminée';
    private static final String TYPE_PRESTATAIRE_EXPERT   = 'Expert Automobile';
    private static final String STATUT_ANNULEE            = 'Instruction annulée';
    private static final String MOTIF_PASSAGE             = 'Passage à un autre type d\'instruction';
    private static final String MOTIF_DESISTEMENT         = 'Désistement de l\'assuré';

    @testSetup
    static void setupTestData() {
        DA_TestBuilderFactory builder = new DA_TestBuilderFactory();

        builder.withCustomAccounts(1, new Map<String, Object>{
            'TypePersonne__c' => 'Personne physique',
            'Civility__c'     => 'Mr',
            'Nom__c'          => 'Test',
            'Prenom__c'       => 'Assure',
            'Email__c'        => 'assure@test.com'
        });
        builder.withCustomPolicies(1, builder.getAccounts()[0].Id, new Map<String, Object>{
            'PolicyCategory__c'  => 'Individuelle',
            'Status__c'          => 'Active',
            'SituationPolice__c' => 'En cours'
        });
        builder.withCustomVehicles(1, builder.getPolicies()[0].Id, new Map<String, Object>{
            'Brand__c'              => 'Renault',
            'Modele__c'             => 'Clio',
            'RegistrationNumber__c' => 'TEST001'
        });
        builder.withCases(1, builder.getAccounts()[0].Id, builder.getPolicies()[0].Id,
            'Test Sinistre', new Map<String, Object>{
                'Status' => 'En cours',
                'Origin' => 'Web'
            });
        builder.withClaims(1, builder.getCases()[0].Id, new Map<String, Object>{
            'Status__c'        => 'En cours de traitement',
            'CausesOfClaim__c' => 'Accident',
            'Vehicule__c'      => builder.getVehicles()[0].Id
        });
    }

    // ── Helpers ──────────────────────────────────────────────────────────────
    private static Instruction__c createInstruction(String necessiteExpertise, Boolean devisRempli, Boolean remise) {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        Id rtPec = Schema.SObjectType.Instruction__c.getRecordTypeInfosByDeveloperName()
            .get('PEC_Prise_en_charge').getRecordTypeId();
        Instruction__c instr = new Instruction__c(
            RecordTypeId             = rtPec,
            Claim__c                 = claim.Id,
            Etape__c              = ETAPE_ETUDE_DOCUMENT,
            NecessiteExpertise__c    = necessiteExpertise,
            RemiseFondsDocumentaire__c = remise
        );
        if (devisRempli) {
            instr.MontantDevisInitial__c            = 10000;
            instr.DateReceptionDevisInitial__c      = Date.today();
            instr.OrigineDevis__c                   = 'Garage conventionné';
            instr.NouveauReparateurNonConventionne__c = true;
            instr.NomReparateur__c                  = 'Garage Test';
        }
        insert instr;
        return instr;
    }

    private static void ajouterDevis(Id instructionId) {
        Document__c doc = new Document__c(Type_de_document__c = 'Devis');
        insert doc;
        insert new Document_Link__c(Instruction__c = instructionId, Document__c = doc.Id);
    }

    private static void ajouterMissionExpert(Id instructionId) {
        Id rtMission = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('Mission').getRecordTypeId();
        insert new Case(
            RecordTypeId      = rtMission,
            Instruction__c    = instructionId,
            TypePrestataire__c = TYPE_PRESTATAIRE_EXPERT,
            Subject           = 'Mission expertise',
            Status            = 'Initiale',
            Origin            = 'Web'
        );
    }

    private static void ajouterMissionExpertise(Id instructionId, String nature, Boolean rapportRecu, Date dateRapport) {
        Id rtMission = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('Mission').getRecordTypeId();
        insert new Case(
            RecordTypeId            = rtMission,
            Instruction__c          = instructionId,
            TypePrestataire__c      = TYPE_PRESTATAIRE_EXPERT,
            NatureMission__c        = nature,
            RapportRecu__c          = rapportRecu,
            DateReceptionRapport__c = dateRapport,
            Subject                 = 'Mission expertise',
            Status                  = 'Initiale',
            Origin                  = 'Web'
        );
    }

    private static void ajouterRapportExpertise(Id instructionId) {
        Document__c doc = new Document__c(Type_de_document__c = 'Rapport d’expertise');
        insert doc;
        insert new Document_Link__c(Instruction__c = instructionId, Document__c = doc.Id);
    }

    private static Instruction__c createInstructionExpertise() {
        Instruction__c instr = createInstruction('Oui', true, true);
        instr.Etape__c = ETAPE_EXPERTISE;
        update instr;
        return instr;
    }

    private static Instruction__c createInstructionCorrection() {
        Instruction__c instr = createInstruction('Non', true, false);
        instr.Etape__c = ETAPE_CORRECTION;
        update instr;
        return instr;
    }

    private static void ajouterCorrectionConfirmee(Id instructionId) {
        insert new Correction_Devis__c(
            Instruction__c      = instructionId,
            StatutCorrection__c = 'Confirmée',
            MontantDevisCorrige__c = 9000
        );
    }

    private static void ajouterDevisDefinitif(Id instructionId) {
        Document__c doc = new Document__c(Type_de_document__c = 'Devis définitif');
        insert doc;
        insert new Document_Link__c(Instruction__c = instructionId, Document__c = doc.Id);
    }

    private static void ajouterDocument(Id instructionId, String typeDocument) {
        Document__c doc = new Document__c(Type_de_document__c = typeDocument);
        insert doc;
        insert new Document_Link__c(Instruction__c = instructionId, Document__c = doc.Id);
    }

    private static void ajouterMissionGaragiste(Id instructionId) {
        Id rtMission = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('Mission').getRecordTypeId();
        insert new Case(
            RecordTypeId      = rtMission,
            Instruction__c    = instructionId,
            TypePrestataire__c = 'Garagiste',
            Subject           = 'Mission garagiste',
            Status            = 'Initiale',
            Origin            = 'Web'
        );
    }

    private static Instruction__c createInstructionEtablissementPEC(String paiementFranchise, Boolean franchiseRecue, Date dateEnvoiPEC) {
        Instruction__c instr = createInstruction('Non', true, false);
        instr.Etape__c            = ETAPE_ETABLISSEMENT_PEC;
        instr.PaiementFranchise__c   = paiementFranchise;
        instr.PaiementFranchiseRecu__c = franchiseRecue;
        instr.DateEnvoiPEC__c        = dateEnvoiPEC;
        update instr;
        return instr;
    }

    private static Instruction__c createInstructionReparation(String obligationRapport) {
        Instruction__c instr = createInstruction('Non', true, false);
        instr.Etape__c                = ETAPE_REPARATION;
        instr.ObligationRapportExpertise__c = obligationRapport;
        update instr;
        return instr;
    }

    private static Account createGaragiste(Boolean conventionne) {
        Account acc = DA_TestDataFactory.createTestPrestataire('Garagiste',
            new Map<String, Object>{ 'Conventionne__c' => conventionne });
        insert acc;
        return acc;
    }

    // ── CR1/CR2 KO (sans expertise) ──────────────────────────────────────────
    @isTest
    static void testEtape1_ControlesKO_SansExpertise() {
        Instruction__c instr = createInstruction('Non', false, false);

        Test.startTest();
        DA_lwc031_DetailsPECController.EtapeResultWrapper res =
            DA_lwc031_DetailsPECController.marquerEtapeTerminee(instr.Id);
        Test.stopTest();

        Assert.isFalse(res.ok, 'Les contrôles doivent être KO');
        Assert.areEqual(2, res.erreurs.size(), 'CR1 et CR2 doivent être KO');
        Instruction__c apres = [SELECT Etape__c, Statut__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual(ETAPE_ETUDE_DOCUMENT, apres.Etape__c, 'L\'étape ne doit pas avancer');
    }

    // ── OK sans expertise => Correction devis + expertise grisée ─────────────
    @isTest
    static void testEtape1_OK_SansExpertise() {
        Instruction__c instr = createInstruction('Non', true, false);
        ajouterDevis(instr.Id);

        Test.startTest();
        DA_lwc031_DetailsPECController.EtapeResultWrapper res =
            DA_lwc031_DetailsPECController.marquerEtapeTerminee(instr.Id);
        Test.stopTest();

        Assert.isTrue(res.ok, 'Tous les contrôles doivent être OK');
        Assert.areEqual(ETAPE_CORRECTION, res.nouvelleEtape, 'Doit se positionner sur Correction devis');
        Assert.isTrue(res.expertiseIgnoree, 'L\'étape Expertise doit être grisée');
        Instruction__c apres = [SELECT Etape__c, Statut__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual(STATUT_ETUDE_DOC_TERMINEE, apres.Statut__c, 'Statut mis à jour');
        Assert.areEqual(ETAPE_CORRECTION, apres.Etape__c, 'Étape mise à jour');
    }

    // ── CR3/CR4 KO (avec expertise) ──────────────────────────────────────────
    @isTest
    static void testEtape1_ControlesKO_AvecExpertise() {
        Instruction__c instr = createInstruction('Oui', true, false);
        ajouterDevis(instr.Id);

        Test.startTest();
        DA_lwc031_DetailsPECController.EtapeResultWrapper res =
            DA_lwc031_DetailsPECController.marquerEtapeTerminee(instr.Id);
        Test.stopTest();

        Assert.isFalse(res.ok, 'Les contrôles doivent être KO');
        Assert.areEqual(2, res.erreurs.size(), 'CR3 (mission expert) et CR4 (remise) doivent être KO');
    }

    // ── OK avec expertise => Expertise ───────────────────────────────────────
    @isTest
    static void testEtape1_OK_AvecExpertise() {
        Instruction__c instr = createInstruction('Oui', true, true);
        ajouterDevis(instr.Id);
        ajouterMissionExpert(instr.Id);

        Test.startTest();
        DA_lwc031_DetailsPECController.EtapeResultWrapper res =
            DA_lwc031_DetailsPECController.marquerEtapeTerminee(instr.Id);
        Test.stopTest();

        Assert.isTrue(res.ok, 'Tous les contrôles doivent être OK');
        Assert.areEqual(ETAPE_EXPERTISE, res.nouvelleEtape, 'Doit se positionner sur Expertise');
        Assert.isFalse(res.expertiseIgnoree, 'L\'étape Expertise est activée');
        Instruction__c apres = [SELECT Etape__c, Statut__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual(STATUT_ETUDE_DOC_TERMINEE, apres.Statut__c, 'Statut mis à jour');
        Assert.areEqual(ETAPE_EXPERTISE, apres.Etape__c, 'Étape mise à jour');
    }

    // ── Étape 2 : CR1/CR2 KO (mission expertise sans rapport ni réception) ───
    @isTest
    static void testEtape2_ControlesKO() {
        Instruction__c instr = createInstructionExpertise();
        ajouterMissionExpertise(instr.Id, 'Expertise Automobile', false, null);

        Test.startTest();
        DA_lwc031_DetailsPECController.EtapeResultWrapper res =
            DA_lwc031_DetailsPECController.marquerEtapeTerminee(instr.Id);
        Test.stopTest();

        Assert.isFalse(res.ok, 'Les contrôles doivent être KO');
        Assert.areEqual(2, res.erreurs.size(), 'CR1 (rapport) et CR2 (réception) doivent être KO');
        Instruction__c apres = [SELECT Etape__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual(ETAPE_EXPERTISE, apres.Etape__c, 'L\'étape ne doit pas avancer');
    }

    // ── Étape 2 : OK (rapport ajouté + réception renseignée) ─────────────────
    @isTest
    static void testEtape2_OK() {
        Instruction__c instr = createInstructionExpertise();
        ajouterMissionExpertise(instr.Id, 'Expertise Automobile', true, Date.today());
        ajouterRapportExpertise(instr.Id);

        Test.startTest();
        DA_lwc031_DetailsPECController.EtapeResultWrapper res =
            DA_lwc031_DetailsPECController.marquerEtapeTerminee(instr.Id);
        Test.stopTest();

        Assert.isTrue(res.ok, 'Tous les contrôles doivent être OK');
        Assert.areEqual(ETAPE_CORRECTION, res.nouvelleEtape, 'Doit se positionner sur Correction devis');
        Instruction__c apres = [SELECT Etape__c, Statut__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual('Expertise terminée', apres.Statut__c, 'Statut mis à jour');
        Assert.areEqual(ETAPE_CORRECTION, apres.Etape__c, 'Étape mise à jour');
    }

    // ── Étape 2 : OK quand seule une mission « Appréciation » existe ─────────
    @isTest
    static void testEtape2_OK_AppreciationSeule() {
        Instruction__c instr = createInstructionExpertise();
        ajouterMissionExpertise(instr.Id, 'Appréciation', false, null);

        Test.startTest();
        DA_lwc031_DetailsPECController.EtapeResultWrapper res =
            DA_lwc031_DetailsPECController.marquerEtapeTerminee(instr.Id);
        Test.stopTest();

        Assert.isTrue(res.ok, 'Aucun contrôle ne s\'applique aux missions Appréciation');
        Assert.areEqual(ETAPE_CORRECTION, res.nouvelleEtape, 'Doit avancer sur Correction devis');
    }

    // ── Étape 3 : CR1/CR2 KO ─────────────────────────────────────────────────
    @isTest
    static void testEtape3_ControlesKO() {
        Instruction__c instr = createInstructionCorrection();

        Test.startTest();
        DA_lwc031_DetailsPECController.EtapeResultWrapper res =
            DA_lwc031_DetailsPECController.marquerEtapeTerminee(instr.Id);
        Test.stopTest();

        Assert.isFalse(res.ok, 'Les contrôles doivent être KO');
        Assert.areEqual(2, res.erreurs.size(), 'CR1 (correction confirmée) et CR2 (devis définitif) doivent être KO');
        Instruction__c apres = [SELECT Etape__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual(ETAPE_CORRECTION, apres.Etape__c, 'L\'étape ne doit pas avancer');
    }

    // ── Étape 3 : OK (correction confirmée + devis définitif) ────────────────
    @isTest
    static void testEtape3_OK() {
        Instruction__c instr = createInstructionCorrection();
        ajouterCorrectionConfirmee(instr.Id);
        ajouterDevisDefinitif(instr.Id);

        Test.startTest();
        DA_lwc031_DetailsPECController.EtapeResultWrapper res =
            DA_lwc031_DetailsPECController.marquerEtapeTerminee(instr.Id);
        Test.stopTest();

        Assert.isTrue(res.ok, 'Tous les contrôles doivent être OK');
        Assert.areEqual(ETAPE_ETABLISSEMENT_PEC, res.nouvelleEtape, 'Doit se positionner sur Etablissement PEC');
        Instruction__c apres = [SELECT Etape__c, Statut__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual('Correction devis terminée', apres.Statut__c, 'Statut mis à jour');
        Assert.areEqual(ETAPE_ETABLISSEMENT_PEC, apres.Etape__c, 'Étape mise à jour');
    }

    // ── Étape 4 : CR1..CR4 KO (rien de renseigné, franchise à la compagnie) ──
    @isTest
    static void testEtape4_ControlesKO() {
        Instruction__c instr = createInstructionEtablissementPEC('A la compagnie', false, null);

        Test.startTest();
        DA_lwc031_DetailsPECController.EtapeResultWrapper res =
            DA_lwc031_DetailsPECController.marquerEtapeTerminee(instr.Id);
        Test.stopTest();

        Assert.isFalse(res.ok, 'Les contrôles doivent être KO');
        Assert.areEqual(4, res.erreurs.size(), 'CR1, CR2, CR3 et CR4 doivent être KO');
        Instruction__c apres = [SELECT Etape__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual(ETAPE_ETABLISSEMENT_PEC, apres.Etape__c, 'L\'étape ne doit pas avancer');
    }

    // ── Étape 4 : OK (garagiste + accord PEC + envoi + franchise reçue) ──────
    @isTest
    static void testEtape4_OK() {
        Instruction__c instr = createInstructionEtablissementPEC('A la compagnie', true, Date.today());
        ajouterMissionGaragiste(instr.Id);
        ajouterDocument(instr.Id, 'ACCORD PRISE EN CHARGE MAT');

        Test.startTest();
        DA_lwc031_DetailsPECController.EtapeResultWrapper res =
            DA_lwc031_DetailsPECController.marquerEtapeTerminee(instr.Id);
        Test.stopTest();

        Assert.isTrue(res.ok, 'Tous les contrôles doivent être OK');
        Assert.areEqual(ETAPE_REPARATION, res.nouvelleEtape, 'Doit se positionner sur Réparation');
        Instruction__c apres = [SELECT Etape__c, Statut__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual('Prise en charge accordée', apres.Statut__c, 'Statut mis à jour');
        Assert.areEqual(ETAPE_REPARATION, apres.Etape__c, 'Étape mise à jour');
    }

    // ── Étape 4 : OK sans franchise « A la compagnie » (CR4 non applicable) ──
    @isTest
    static void testEtape4_OK_FranchiseAuGaragiste() {
        Instruction__c instr = createInstructionEtablissementPEC('Au garagiste', false, Date.today());
        ajouterMissionGaragiste(instr.Id);
        ajouterDocument(instr.Id, 'ACCORD PRISE EN CHARGE MAT');

        Test.startTest();
        DA_lwc031_DetailsPECController.EtapeResultWrapper res =
            DA_lwc031_DetailsPECController.marquerEtapeTerminee(instr.Id);
        Test.stopTest();

        Assert.isTrue(res.ok, 'CR4 ne s\'applique pas si la franchise n\'est pas « A la compagnie »');
        Assert.areEqual(ETAPE_REPARATION, res.nouvelleEtape, 'Doit avancer sur Réparation');
    }

    // ── Étape 5 : CR1 KO (pas de bon de sortie) ─────────────────────────────
    @isTest
    static void testEtape5_ControlesKO() {
        Instruction__c instr = createInstructionReparation('Oui');

        Test.startTest();
        DA_lwc031_DetailsPECController.EtapeResultWrapper res =
            DA_lwc031_DetailsPECController.marquerEtapeTerminee(instr.Id);
        Test.stopTest();

        Assert.isFalse(res.ok, 'Les contrôles doivent être KO');
        Assert.areEqual(2, res.erreurs.size(), 'CR1 (bon de sortie) et CR2 (rapport post travaux) doivent être KO');
    }

    // ── Étape 5 : OK (bon de sortie + rapport post travaux requis) ──────────
    @isTest
    static void testEtape5_OK() {
        Instruction__c instr = createInstructionReparation('Oui');
        ajouterDocument(instr.Id, 'Bon de sortie MAT');
        ajouterDocument(instr.Id, 'Rapport post travaux');

        Test.startTest();
        DA_lwc031_DetailsPECController.EtapeResultWrapper res =
            DA_lwc031_DetailsPECController.marquerEtapeTerminee(instr.Id);
        Test.stopTest();

        Assert.isTrue(res.ok, 'Tous les contrôles doivent être OK');
        Assert.isTrue(res.instructionTerminee, 'L\'instruction doit être marquée terminée');
        Instruction__c apres = [SELECT Statut__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual('Instruction terminée', apres.Statut__c, 'Statut mis à jour');
    }

    // ── Étape 5 : OK sans obligation rapport post travaux (CR2 non applicable) ─
    @isTest
    static void testEtape5_OK_SansRapportPostTravaux() {
        Instruction__c instr = createInstructionReparation('Non');
        ajouterDocument(instr.Id, 'Bon de sortie MAT');

        Test.startTest();
        DA_lwc031_DetailsPECController.EtapeResultWrapper res =
            DA_lwc031_DetailsPECController.marquerEtapeTerminee(instr.Id);
        Test.stopTest();

        Assert.isTrue(res.ok, 'CR2 ne s\'applique pas si pas d\'obligation de rapport post travaux');
        Assert.isTrue(res.instructionTerminee, 'L\'instruction doit être marquée terminée');
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Couverture des méthodes de chargement / sauvegarde / navigation
    // ════════════════════════════════════════════════════════════════════════

    @isTest
    static void testGetDetailsPEC() {
        Instruction__c instr = createInstruction('Non', true, false);
        // Renseigner les dates de référence sur le Case (la date sinistre du
        // Claim est une formule alimentée par le Case) pour couvrir les branches RG1
        Claim__c claim = [SELECT Id, Case__c FROM Claim__c LIMIT 1];
        update new Case(
            Id = claim.Case__c,
            DateOfOccurrence__c = DateTime.now().addDays(-10),
            DateOfDeclarationCreation__c = Date.today().addDays(-8)
        );

        Test.startTest();
        DA_lwc031_DetailsPECController.DetailsPECWrapper w =
            DA_lwc031_DetailsPECController.getDetailsPEC(instr.Id);
        DA_lwc031_DetailsPECController.DetailsPECWrapper wNull =
            DA_lwc031_DetailsPECController.getDetailsPEC(null);
        Test.stopTest();

        Assert.areEqual(instr.Id, w.instruction.Id, 'L\'instruction doit être chargée');
        Assert.isNotNull(w.dateSinistre, 'La date sinistre doit être renseignée');
        Assert.isNull(wNull, 'Un id null renvoie null (wire avant recordId)');
    }

    @isTest
    static void testGetGaragistes() {
        createGaragiste(true);
        createGaragiste(false);

        Test.startTest();
        List<Account> conv    = DA_lwc031_DetailsPECController.getGaragistes(true);
        List<Account> nonConv = DA_lwc031_DetailsPECController.getGaragistes(false);
        Test.stopTest();

        Assert.isNotNull(conv, 'La liste conventionnés ne doit pas être nulle');
        Assert.isNotNull(nonConv, 'La liste non conventionnés ne doit pas être nulle');
    }

    @isTest
    static void testSaveDevisInitial_OK() {
        Instruction__c instr = createInstruction('Non', false, false);
        Map<String, Object> payload = new Map<String, Object>{
            'montantDevisInitial'       => 12000,
            'dateReceptionDevisInitial' => '2026-01-15',
            'origineDevis'              => 'Garage conventionné',
            'nouveauReparateur'         => true,
            'nomReparateur'             => 'Garage Test',
            'necessiteExpertise'        => 'Non',
            'commentaire'               => 'RAS'
        };

        Test.startTest();
        DA_lwc031_DetailsPECController.saveDevisInitial(instr.Id, JSON.serialize(payload));
        Test.stopTest();

        Instruction__c apres = [SELECT MontantDevisInitial__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual(12000, apres.MontantDevisInitial__c, 'Le montant doit être enregistré');
    }

    @isTest
    static void testSaveDevisInitial_Erreur() {
        Instruction__c instr = createInstruction('Non', false, false);
        Boolean erreur = false;
        Test.startTest();
        try {
            DA_lwc031_DetailsPECController.saveDevisInitial(instr.Id,
                JSON.serialize(new Map<String, Object>{ 'origineDevis' => 'Garage conventionné' }));
        } catch (Exception e) {
            erreur = true;
        }
        Test.stopTest();
        Assert.isTrue(erreur, 'Une erreur doit être levée si le montant est manquant');
    }

    @isTest
    static void testSaveExpertise() {
        Instruction__c instr = createInstruction('Oui', true, true);
        Test.startTest();
        DA_lwc031_DetailsPECController.saveExpertise(instr.Id,
            JSON.serialize(new Map<String, Object>{ 'montantApprecie' => 8500, 'commentaire' => 'Expertise OK' }));
        Test.stopTest();
        Instruction__c apres = [SELECT MontantApprecie__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual(8500, apres.MontantApprecie__c, 'Le montant apprécié doit être enregistré');
    }

    @isTest
    static void testSaveCorrection_NouvelleEtMaj() {
        Instruction__c instr = createInstructionCorrection();
        Account garagiste = createGaragiste(true);

        Test.startTest();
        // Création d'une nouvelle ligne
        DA_lwc031_DetailsPECController.saveCorrection(instr.Id, JSON.serialize(new Map<String, Object>{
            'montantDevisCorrige' => 9500,
            'origineCorrection'   => 'Contre-proposition garagiste',
            'reparateurId'        => garagiste.Id,
            'statutCorrection'    => 'Soumise'
        }));
        Correction_Devis__c c = [SELECT Id FROM Correction_Devis__c WHERE Instruction__c = :instr.Id LIMIT 1];
        // Mise à jour du statut
        DA_lwc031_DetailsPECController.saveCorrection(instr.Id, JSON.serialize(new Map<String, Object>{
            'id'               => c.Id,
            'statutCorrection' => 'Confirmée'
        }));
        Test.stopTest();

        Correction_Devis__c apres = [SELECT StatutCorrection__c FROM Correction_Devis__c WHERE Id = :c.Id];
        Assert.areEqual('Confirmée', apres.StatutCorrection__c, 'Le statut doit être mis à jour');
    }

    @isTest
    static void testSavePriseEnCharge_OKEtErreur() {
        Instruction__c instr = createInstruction('Non', true, false);
        instr.Etape__c = ETAPE_ETABLISSEMENT_PEC;
        update instr;

        Map<String, Object> payload = new Map<String, Object>{
            'montantAccordePEC'          => 15000,
            'franchisePourcentage'       => 10,
            'franchiseMin'               => 500,
            'franchiseMax'               => 3000,
            'paiementFranchise'          => 'A la compagnie',
            'paiementFranchiseRecu'      => true,
            'obligationRapportExpertise' => 'Non',
            'commentaire'                => 'PEC',
            'dateEnvoiPEC'               => '2026-02-01'
        };

        Boolean erreur = false;
        Test.startTest();
        DA_lwc031_DetailsPECController.savePriseEnCharge(instr.Id, JSON.serialize(payload));
        try {
            DA_lwc031_DetailsPECController.savePriseEnCharge(instr.Id,
                JSON.serialize(new Map<String, Object>{ 'franchisePourcentage' => 10 }));
        } catch (Exception e) {
            erreur = true;
        }
        Test.stopTest();

        Instruction__c apres = [SELECT MontantAccordePEC__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual(15000, apres.MontantAccordePEC__c, 'Le montant PEC doit être enregistré');
        Assert.isTrue(erreur, 'Une erreur doit être levée si le montant PEC est manquant');
    }

    @isTest
    static void testCreerRequetePrestataire() {
        Instruction__c instr = createInstruction('Non', true, false);

        Test.startTest();
        Id requeteId = DA_lwc031_DetailsPECController.creerRequetePrestataire(instr.Id, 'Garage Inconnu', 'IF12345');
        Test.stopTest();

        Assert.isNotNull(requeteId, 'Une requête doit être créée');
        Case requete = [SELECT TypeRequete__c FROM Case WHERE Id = :requeteId];
        Assert.areEqual('Création prestataire', requete.TypeRequete__c, 'La requête doit être de type Création prestataire');
    }

    @isTest
    static void testCreerRequetePrestataire_Erreur() {
        Instruction__c instr = createInstruction('Non', true, false);
        Boolean erreur = false;
        Test.startTest();
        try {
            DA_lwc031_DetailsPECController.creerRequetePrestataire(instr.Id, '', null);
        } catch (Exception e) {
            erreur = true;
        }
        Test.stopTest();
        Assert.isTrue(erreur, 'Une erreur doit être levée si le nom réparateur est vide');
    }

    @isTest
    static void testPasserEtapeSuivanteEtSetEtape() {
        Instruction__c instr = createInstruction('Non', true, false);

        Test.startTest();
        String suivante = DA_lwc031_DetailsPECController.passerEtapeSuivante(instr.Id);
        String etapeSet = DA_lwc031_DetailsPECController.setEtape(instr.Id, ETAPE_CORRECTION);
        Boolean erreurSet = false;
        try {
            DA_lwc031_DetailsPECController.setEtape(instr.Id, 'Étape inexistante');
        } catch (Exception e) {
            erreurSet = true;
        }
        Test.stopTest();

        Assert.areEqual(ETAPE_EXPERTISE, suivante, 'L\'étape suivante d\'Etude de document est Expertise');
        Assert.areEqual(ETAPE_CORRECTION, etapeSet, 'setEtape doit positionner l\'étape demandée');
        Assert.isTrue(erreurSet, 'Une erreur doit être levée pour une étape inconnue');
    }

    @isTest
    static void testPasserEtapeSuivante_DerniereEtape() {
        Instruction__c instr = createInstructionReparation('Non');
        Boolean erreur = false;
        Test.startTest();
        try {
            DA_lwc031_DetailsPECController.passerEtapeSuivante(instr.Id);
        } catch (Exception e) {
            erreur = true;
        }
        Test.stopTest();
        Assert.isTrue(erreur, 'Une erreur doit être levée à la dernière étape');
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Annulation d'instruction (RG1 à RG7)
    // ════════════════════════════════════════════════════════════════════════

    private static void ajouterMissionExpertCloturee(Id instructionId) {
        Id rtMission = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('Mission').getRecordTypeId();
        insert new Case(
            RecordTypeId       = rtMission,
            Instruction__c     = instructionId,
            TypePrestataire__c = TYPE_PRESTATAIRE_EXPERT,
            Subject            = 'Mission expertise clôturée',
            Status             = 'Clôturé',
            Origin             = 'Web'
        );
    }

    // ── RG1 KO : mission d'expert en cours à l'étape Etude de document ───────
    @isTest
    static void testAnnuler_Etape1_RG1_MissionExpertEnCours_KO() {
        Instruction__c instr = createInstruction('Oui', true, true);
        ajouterMissionExpert(instr.Id); // statut « Initiale » => en cours

        Test.startTest();
        DA_lwc031_DetailsPECController.AnnulationResultWrapper res =
            DA_lwc031_DetailsPECController.annulerInstruction(instr.Id, MOTIF_DESISTEMENT);
        Test.stopTest();

        Assert.isFalse(res.ok, 'L\'annulation doit être bloquée (RG1)');
        Assert.isTrue(res.message.contains('mission d\'expert en cours'), 'Message RG1 attendu');
        Instruction__c apres = [SELECT Statut__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areNotEqual(STATUT_ANNULEE, apres.Statut__c, 'Le statut ne doit pas changer');
    }

    // ── OK : étape Etude, aucune mission expert en cours (mission clôturée) ──
    @isTest
    static void testAnnuler_Etape1_OK() {
        Instruction__c instr = createInstruction('Non', true, false);
        ajouterMissionExpertCloturee(instr.Id); // clôturée => filtrée

        Test.startTest();
        DA_lwc031_DetailsPECController.AnnulationResultWrapper res =
            DA_lwc031_DetailsPECController.annulerInstruction(instr.Id, MOTIF_DESISTEMENT);
        Test.stopTest();

        Assert.isTrue(res.ok, 'L\'annulation doit être possible');
        Instruction__c apres = [SELECT Statut__c, MotifAnnulation__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual(STATUT_ANNULEE, apres.Statut__c, 'Le statut doit passer à Instruction annulée');
        Assert.areEqual(MOTIF_DESISTEMENT, apres.MotifAnnulation__c, 'Le motif doit être enregistré');
    }

    // ── RG2 KO : mission d'expert en cours à l'étape Etablissement PEC ───────
    @isTest
    static void testAnnuler_Etape4_RG2_MissionExpertEnCours_KO() {
        Instruction__c instr = createInstructionEtablissementPEC('Au garagiste', false, null);
        ajouterMissionExpert(instr.Id);

        Test.startTest();
        DA_lwc031_DetailsPECController.AnnulationResultWrapper res =
            DA_lwc031_DetailsPECController.annulerInstruction(instr.Id, MOTIF_DESISTEMENT);
        Test.stopTest();

        Assert.isFalse(res.ok, 'L\'annulation doit être bloquée (RG2)');
        Assert.isTrue(res.message.contains('la mission en cours'), 'Message RG2 attendu');
    }

    // ── RG3 KO : mission de garagiste en cours à l'étape Etablissement PEC ───
    @isTest
    static void testAnnuler_Etape4_RG3_MissionGaragisteEnCours_KO() {
        Instruction__c instr = createInstructionEtablissementPEC('Au garagiste', false, null);
        ajouterMissionGaragiste(instr.Id);

        Test.startTest();
        DA_lwc031_DetailsPECController.AnnulationResultWrapper res =
            DA_lwc031_DetailsPECController.annulerInstruction(instr.Id, MOTIF_DESISTEMENT);
        Test.stopTest();

        Assert.isFalse(res.ok, 'L\'annulation doit être bloquée (RG3)');
        Assert.isTrue(res.message.contains('garagiste en cours'), 'Message RG3 attendu');
    }

    // ── RG6 KO : option « Début des travaux » cochée à l'étape Réparation ───
    @isTest
    static void testAnnuler_Reparation_RG6_DebutTravaux_KO() {
        Instruction__c instr = createInstructionReparation('Non');
        instr.DebutTravaux__c = true;
        update instr;

        Test.startTest();
        DA_lwc031_DetailsPECController.AnnulationResultWrapper res =
            DA_lwc031_DetailsPECController.annulerInstruction(instr.Id, MOTIF_DESISTEMENT);
        Test.stopTest();

        Assert.isFalse(res.ok, 'L\'annulation doit être bloquée (RG6)');
        Assert.isTrue(res.message.contains('travaux sont entamés'), 'Message RG6 attendu');
    }

    // ── RG7 KO : motif « retard » sans PEC retournée à l'étape Réparation ────
    @isTest
    static void testAnnuler_Reparation_RG7_SansPecRetournee_KO() {
        Instruction__c instr = createInstructionReparation('Non');

        Test.startTest();
        DA_lwc031_DetailsPECController.AnnulationResultWrapper res =
            DA_lwc031_DetailsPECController.annulerInstruction(instr.Id, MOTIF_PASSAGE);
        Test.stopTest();

        Assert.isFalse(res.ok, 'L\'annulation doit être bloquée (RG7)');
        Assert.isTrue(res.message.contains('PEC retournée'), 'Message RG7 attendu');
    }

    // ── RG7 OK : motif « retard » avec PEC retournée ajoutée ────────────────
    @isTest
    static void testAnnuler_Reparation_RG7_AvecPecRetournee_OK() {
        Instruction__c instr = createInstructionReparation('Non');
        ajouterDocument(instr.Id, 'PEC retournée');

        Test.startTest();
        DA_lwc031_DetailsPECController.AnnulationResultWrapper res =
            DA_lwc031_DetailsPECController.annulerInstruction(instr.Id, MOTIF_PASSAGE);
        Test.stopTest();

        Assert.isTrue(res.ok, 'L\'annulation doit être possible (PEC retournée présente)');
        Instruction__c apres = [SELECT Statut__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual(STATUT_ANNULEE, apres.Statut__c, 'Le statut doit passer à Instruction annulée');
    }

    // ── OK : étape Réparation, motif Désistement (RG7 non applicable) ────────
    @isTest
    static void testAnnuler_Reparation_Desistement_OK() {
        Instruction__c instr = createInstructionReparation('Non');

        Test.startTest();
        DA_lwc031_DetailsPECController.AnnulationResultWrapper res =
            DA_lwc031_DetailsPECController.annulerInstruction(instr.Id, MOTIF_DESISTEMENT);
        Test.stopTest();

        Assert.isTrue(res.ok, 'Le désistement ne déclenche pas le contrôle PEC retournée');
        Instruction__c apres = [SELECT Statut__c FROM Instruction__c WHERE Id = :instr.Id];
        Assert.areEqual(STATUT_ANNULEE, apres.Statut__c, 'Le statut doit passer à Instruction annulée');
    }

    // ── Erreur : motif manquant ─────────────────────────────────────────────
    @isTest
    static void testAnnuler_MotifManquant_Erreur() {
        Instruction__c instr = createInstruction('Non', true, false);
        Boolean erreur = false;
        Test.startTest();
        try {
            DA_lwc031_DetailsPECController.annulerInstruction(instr.Id, '');
        } catch (Exception e) {
            erreur = true;
        }
        Test.stopTest();
        Assert.isTrue(erreur, 'Une erreur doit être levée si le motif est vide');
    }
}
