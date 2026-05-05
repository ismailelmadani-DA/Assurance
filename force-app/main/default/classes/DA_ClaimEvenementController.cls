/**
 * DA_ClaimEvenementController
 * Gère la logique de correspondance et d'association d'un événement à un sinistre.
 *
 * Mapping confirmé :
 *   Sinistre          : Claim__c
 *   Date survenance   : Case__r.DateOfOccurrence__c  (Formula → on lit via le Case)
 *   Ville survenance  : CityOfOccurrence__c           (Picklist)
 *   Pays survenance   : CountryOfOccurrence__c        (Picklist)
 *   Champ liaison     : EvenementAssocie__c            (Lookup → Evenement__c)
 *
 *   Événement         : Evenement__c
 *   Code              : Name                           (Auto Number)
 *   Libellé           : Libelle__c                    (Text 255)
 *   Date début        : DateDebut__c                  (Date)
 *   Date fin          : DateFin__c                    (Date)
 *   Ville             : Ville__c                      (Picklist)
 *   Pays              : Pays__c                       (Picklist)
 *   Catégorie         : Categorie__c                  (Picklist)
 *   Type              : Type__c                       (Picklist)
 */
public with sharing class DA_ClaimEvenementController {

    /* ─────────────────────────────────────────────────────────────
     * getMatchingEvenements
     *
     * Pourquoi on ne filtre pas en SOQL sur la date ?
     * DateOfOccurrence__c est une Formula → Salesforce n'autorise pas
     * les formula fields dans les clauses WHERE.
     * On charge le sinistre pour récupérer la date via Case__r,
     * puis on filtre les événements en Apex.
     * ───────────────────────────────────────────────────────────── */
    @AuraEnabled(cacheable=true)
    public static List<Evenement__c> getMatchingEvenements(Id claimId) {

        if (claimId == null) return new List<Evenement__c>();

        // 1. Charger le sinistre : date via Case + ville + pays
        List<Claim__c> claims = [
            SELECT  Id,
                    Case__r.DateOfOccurrence__c,
                    CityOfOccurrence__c,
                    CountryOfOccurrence__c
            FROM    Claim__c
            WHERE   Id = :claimId
            LIMIT   1
        ];

        if (claims.isEmpty()) return new List<Evenement__c>();

        Claim__c claim         = claims[0];
        DateTime occurrenceDt  = claim.Case__r.DateOfOccurrence__c;
        String   city          = claim.CityOfOccurrence__c;
        String   country       = claim.CountryOfOccurrence__c;

        // 2. Si données manquantes → rien à comparer
        if (occurrenceDt == null || String.isBlank(city) || String.isBlank(country)) {
            return new List<Evenement__c>();
        }

        // Convertir DateTime → Date pour comparer avec DateDebut__c / DateFin__c
        Date occurrenceDate = occurrenceDt.date();

        // 3. Charger les événements filtrés par pays + ville (champs réels → filtrables en SOQL)
        List<Evenement__c> candidats = [
            SELECT  Id,
                    Name,
                    Libelle__c,
                    Categorie__c,
                    Type__c,
                    DateDebut__c,
                    DateFin__c,
                    Ville__c,
                    Pays__c
            FROM    Evenement__c
            WHERE   Pays__c  = :country
              AND   Ville__c = :city
            ORDER BY DateDebut__c DESC
            LIMIT   200
        ];

        // 4. Filtrer en Apex : date de survenance entre DateDebut et DateFin (inclus)
        List<Evenement__c> result = new List<Evenement__c>();
        for (Evenement__c ev : candidats) {
            if (ev.DateDebut__c != null
                && ev.DateFin__c != null
                && occurrenceDate >= ev.DateDebut__c
                && occurrenceDate <= ev.DateFin__c) {
                result.add(ev);
            }
        }

        return result;
    }

    /* ─────────────────────────────────────────────────────────────
     * getEvenementAssocie
     * Retourne l'événement déjà associé au sinistre (null si aucun).
     * ───────────────────────────────────────────────────────────── */
    @AuraEnabled(cacheable=false)
    public static Evenement__c getEvenementAssocie(Id claimId) {

        if (claimId == null) return null;

        List<Claim__c> claims = [
            SELECT  EvenementAssocie__c,
                    EvenementAssocie__r.Id,
                    EvenementAssocie__r.Name,
                    EvenementAssocie__r.Libelle__c,
                    EvenementAssocie__r.Categorie__c,
                    EvenementAssocie__r.DateDebut__c,
                    EvenementAssocie__r.DateFin__c,
                    EvenementAssocie__r.Ville__c,
                    EvenementAssocie__r.Pays__c
            FROM    Claim__c
            WHERE   Id = :claimId
            LIMIT   1
        ];

        if (claims.isEmpty() || claims[0].EvenementAssocie__c == null) return null;

        return claims[0].EvenementAssocie__r;
    }

    /* ─────────────────────────────────────────────────────────────
     * associerEvenement
     * Met à jour le sinistre en associant l'événement sélectionné.
     * ───────────────────────────────────────────────────────────── */
    @AuraEnabled
    public static void associerEvenement(Id claimId, Id evenementId) {

        if (claimId == null || evenementId == null) {
            throw new AuraHandledException('Paramètres invalides.');
        }

        if (!Schema.sObjectType.Claim__c.isUpdateable()) {
            throw new AuraHandledException(
                'Vous n\'avez pas les droits pour modifier ce sinistre.'
            );
        }

        update new Claim__c(
            Id                  = claimId,
            EvenementAssocie__c = evenementId
        );
    }
}