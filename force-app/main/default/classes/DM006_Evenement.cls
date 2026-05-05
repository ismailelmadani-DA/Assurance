public with sharing class DM006_Evenement {

    /* ══════════════════════════════════════════════════════════════════════
       CHAMPS PAR DÉFAUT
    ══════════════════════════════════════════════════════════════════════ */
    private static final String DEFAULT_FIELDS =
        'Id, Name, Libelle__c, Categorie__c, Type__c, ' +
        'DateDebut__c, DateFin__c, Pays__c, Ville__c, ' +
        'CreatedById, CreatedBy.Name, CreatedDate';

    /* ══════════════════════════════════════════════════════════════════════
       GET — Liste des événements avec filtres
       @param catFilter   : filtre sur Categorie__c ('' = tous)
       @param periodFilter: 'day' | 'week' | 'month' | 'year' | '' = tous
       @param searchTerm  : recherche LIKE sur libellé, code, type, ville
    ══════════════════════════════════════════════════════════════════════ */
    public static List<Evenement__c> getEvenements(
            String catFilter,
            String periodFilter,
            String searchTerm) {

        String conditions = buildConditions(catFilter, periodFilter, searchTerm);
        return (List<Evenement__c>) DA_Utility.query(
            DEFAULT_FIELDS,
            'Evenement__c',
            conditions,
            'CreatedDate DESC',
            500
        );
    }

    /* ══════════════════════════════════════════════════════════════════════
       GET — Un événement par Id
    ══════════════════════════════════════════════════════════════════════ */
    public static Evenement__c getEvenementById(Id recordId) {
        List<Evenement__c> results = (List<Evenement__c>) DA_Utility.query(
            DEFAULT_FIELDS,
            'Evenement__c',
            'Id = \'' + String.escapeSingleQuotes(String.valueOf(recordId)) + '\'',
            null,
            1
        );
        return results.isEmpty() ? null : results[0];
    }

    /* ══════════════════════════════════════════════════════════════════════
       COUNT — Nombre d'événements par catégorie
    ══════════════════════════════════════════════════════════════════════ */
    public static Integer countEvenementsByCategorie(String categorie) {
        return [
            SELECT COUNT()
            FROM Evenement__c
            WHERE Categorie__c = :categorie
        ];
    }

    /* ══════════════════════════════════════════════════════════════════════
       COUNT — Nombre total d'événements (pour les stats)
    ══════════════════════════════════════════════════════════════════════ */
    public static Integer countAllEvenements() {
        return [SELECT COUNT() FROM Evenement__c];
    }

    /* ══════════════════════════════════════════════════════════════════════
       PRIVATE — Construction dynamique du WHERE
    ══════════════════════════════════════════════════════════════════════ */
    private static String buildConditions(
            String catFilter,
            String periodFilter,
            String searchTerm) {

        List<String> parts = new List<String>();

        // ── Filtre catégorie ──
        if (String.isNotBlank(catFilter)) {
            parts.add('Categorie__c = \'' + String.escapeSingleQuotes(catFilter) + '\'');
        }

        // ── Filtre période (basé sur CreatedDate) ──
         // 2. Filtre période (MODIFIÉ ICI)
        if (String.isNotBlank(periodFilter)) {
            if (periodFilter.startsWith('custom|')) {
                // On découpe la chaîne "custom|2025-01-01|2025-12-31"
                List<String> periodParts = periodFilter.split('\\|');
                if (periodParts.size() == 3) {
                    String dFrom = periodParts[1]; // 2025-01-01
                    String dTo   = periodParts[2]; // 2025-12-31
                    
                    // On ajoute la condition SOQL de plage de dates
                    parts.add('DateDebut__c >= ' + dFrom + ' AND DateDebut__c <= ' + dTo);
                }
            } else {
                // Sinon, on utilise la logique classique (Today, This Week...)
                String dateCondition = buildPeriodCondition(periodFilter);
                if (String.isNotBlank(dateCondition)) {
                    parts.add(dateCondition);
                }
            }
        }

        // ── Filtre recherche LIKE ──
        if (String.isNotBlank(searchTerm)) {
            String safeTerm = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            parts.add(
                '('
                + 'Libelle__c LIKE \'' + safeTerm + '\''
                + ' OR Name LIKE \'' + safeTerm + '\''
                + ' OR Type__c LIKE \'' + safeTerm + '\''
                + ' OR Ville__c LIKE \'' + safeTerm + '\''
                + ' OR CreatedBy.Name LIKE \'' + safeTerm + '\''
                + ')'
            );
        }

        return parts.isEmpty() ? null : String.join(parts, ' AND ');
    }

    private static String buildPeriodCondition(String period) {
        if (period == 'day')   return 'DateDebut__c = TODAY';
        if (period == 'week')  return 'DateDebut__c = THIS_WEEK';
        if (period == 'month') return 'DateDebut__c = THIS_MONTH';
        if (period == 'year')  return 'DateDebut__c = THIS_YEAR';
        return null;
    }

    /* ══════════════════════════════════════════════════════════════════════
   GET — Événements correspondant à un sinistre (pour DA_lwc021)
   Filtre par Pays + Ville en SOQL, puis plage de dates en Apex
   (DateOfOccurrence__c est une Formula → non filtrable en WHERE SOQL)
══════════════════════════════════════════════════════════════════════ */
public static List<Evenement__c> getMatchingEvenementsForClaim(Id claimId) {
    if (claimId == null) return new List<Evenement__c>();

    // 1. Charger le sinistre : date via Case__r + ville + pays
    List<SObject> claims = DA_Utility.query(
        'Id, Case__r.DateOfOccurrence__c, CityOfOccurrence__c, CountryOfOccurrence__c',
        'Claim__c',
        'Id = \'' + String.escapeSingleQuotes(String.valueOf(claimId)) + '\'',
        null, 1
    );
    if (claims.isEmpty()) return new List<Evenement__c>();

    Claim__c claim        = (Claim__c) claims[0];
    DateTime occurrenceDt = claim.Case__r.DateOfOccurrence__c;
    String   city         = claim.CityOfOccurrence__c;
    String   country      = claim.CountryOfOccurrence__c;

    // 2. Données manquantes → rien à comparer
    if (occurrenceDt == null || String.isBlank(city) || String.isBlank(country)) {
        return new List<Evenement__c>();
    }

    Date occurrenceDate = occurrenceDt.date();

    // 3. Candidats filtrés en SOQL sur les champs réels (Pays + Ville)
    List<SObject> candidats = DA_Utility.query(
        DEFAULT_FIELDS,
        'Evenement__c',
        'Pays__c = \'' + String.escapeSingleQuotes(country) + '\''
        + ' AND Ville__c = \'' + String.escapeSingleQuotes(city) + '\'',
        'DateDebut__c DESC', 200
    );

    // 4. Filtre Apex : date de survenance comprise entre DateDebut et DateFin (inclus)
    List<Evenement__c> result = new List<Evenement__c>();
    for (SObject so : candidats) {
        Evenement__c ev = (Evenement__c) so;
        if (ev.DateDebut__c != null
            && ev.DateFin__c  != null
            && occurrenceDate >= ev.DateDebut__c
            && occurrenceDate <= ev.DateFin__c) {
            result.add(ev);
        }
    }
    return result;
}

/* ══════════════════════════════════════════════════════════════════════
   GET — Événement déjà associé à un sinistre (pour DA_lwc021)
══════════════════════════════════════════════════════════════════════ */
public static Evenement__c getEvenementAssocie(Id claimId) {
    if (claimId == null) return null;

    List<SObject> claims = DA_Utility.query(
        'Id, EvenementAssocie__c, '
        + 'EvenementAssocie__r.Id, EvenementAssocie__r.Name, '
        + 'EvenementAssocie__r.Libelle__c, EvenementAssocie__r.Categorie__c, '
        + 'EvenementAssocie__r.DateDebut__c, EvenementAssocie__r.DateFin__c, '
        + 'EvenementAssocie__r.Ville__c, EvenementAssocie__r.Pays__c',
        'Claim__c',
        'Id = \'' + String.escapeSingleQuotes(String.valueOf(claimId)) + '\'',
        null, 1
    );
    if (claims.isEmpty()) return null;

    Claim__c claim = (Claim__c) claims[0];
    return claim.EvenementAssocie__c == null ? null : claim.EvenementAssocie__r;
}
}