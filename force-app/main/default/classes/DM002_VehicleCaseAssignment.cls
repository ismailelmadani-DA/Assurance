public with sharing class DM002_VehicleCaseAssignment{

    private static final String VEHICLE_ASSIGNMENT = 'VehicleCaseAssignment__c';

    private static final String LIST_FIELDS =
        'Id, EtatVehicule__c, NbDePassagerBlesses__c, ' +
        'AdversaireAssure__c, isOpposingCar__c, ' +
        'CompagnieAdverse__c, CompagnieAdverse__r.Name, ' +
        'Vehicule__c, Vehicule__r.RegistrationNumber__c, ' +
        'Vehicule__r.Brand__c, TypeVehicule__c, ' +
        'DateMiseEnCirculation__c, ' +
        'Vehicule__r.ProprietaireDuVehicule__c, ' +
        'Vehicule__r.ProprietaireDuVehicule__r.Name, ' +
        'Claim__c';

    private static final String DETAIL_FIELDS =
        'Id, EtatVehicule__c, NbDePassagerBlesses__c, ' +
        'AdversaireAssure__c, isOpposingCar__c, ' +
        'CompagnieAdverse__c, CompagnieAdverse__r.Name, ' +
        'Vehicule__c, Vehicule__r.RegistrationNumber__c, ' +
        'Vehicule__r.Brand__c, Vehicule__r.Usage__c, ' +
        'Vehicule__r.ModelePicklist__c, ' +
        'Vehicule__r.NbDeContratDAssurance__c, ' +
        'Vehicule__r.ProprietaireDuVehicule__c, ' +
        'Vehicule__r.ProprietaireDuVehicule__r.Name, ' +
        'Vehicule__r.ProprietaireDuVehicule__r.TypePersonne__c, ' +
        'Vehicule__r.ProprietaireDuVehicule__r.CIN__c, ' +
        'Vehicule__r.ProprietaireDuVehicule__r.Phone, ' +
        'Vehicule__r.ProprietaireDuVehicule__r.Email__c, ' +
        'Vehicule__r.ProprietaireDuVehicule__r.MoyenNotification__c, ' +
        'Vehicule__r.ProprietaireDuVehicule__r.Adresse__c, ' +
        'Vehicule__r.ProprietaireDuVehicule__r.Ville__c, ' +
        'Vehicule__r.ProprietaireDuVehicule__r.Pays__c, ' +
        'TypeVehicule__c, DateMiseEnCirculation__c, Pays__c, Claim__c';

    /**
     * Retourne la liste des véhicules adverses pour un sinistre donné.
     */
    public static List<SObject> getVehiclesAdverses(Id claimId) {
        String safeId = String.escapeSingleQuotes(String.valueOf(claimId));
        return DA_Utility.query(
            LIST_FIELDS, VEHICLE_ASSIGNMENT,
            'Claim__c = \'' + safeId + '\' AND isOpposingCar__c = true',
            'CreatedDate DESC', null
        );
    }

    /**
     * Retourne le détail d'un véhicule adverse par son assignmentId,
     * mappé dans une Map pour le contrôleur.
     */
    public static Map<String, Object> getVehicleAdverseById(Id assignmentId) {
        String safeId = String.escapeSingleQuotes(String.valueOf(assignmentId));
        List<SObject> results = DA_Utility.query(
            DETAIL_FIELDS, VEHICLE_ASSIGNMENT,
            'Id = \'' + safeId + '\'', null, 1
        );
        VehicleCaseAssignment__c a = results.isEmpty() ? null : (VehicleCaseAssignment__c) results[0];

        if (a == null) return null;

        Map<String, Object> result = new Map<String, Object>();
        result.put('assignmentId',          a.Id);
        result.put('vehiculeId',            a.Vehicule__c);
        result.put('etatVehicule',          a.EtatVehicule__c);
        result.put('nbPassagerBlesses',     a.NbDePassagerBlesses__c);
        result.put('adversaireAssure',      a.AdversaireAssure__c == true ? 'true' : 'false');
        result.put('compagnieAdverseId',    a.CompagnieAdverse__c);
        result.put('compagnieAdverse',      a.CompagnieAdverse__r?.Name);
        result.put('typeVehicule',          a.TypeVehicule__c);
        result.put('dateMiseEnCirculation', a.DateMiseEnCirculation__c != null
            ? String.valueOf(a.DateMiseEnCirculation__c) : '');

        if (a.Vehicule__c != null) {
            result.put('immatriculation',   a.Vehicule__r?.RegistrationNumber__c);
            result.put('marque',            a.Vehicule__r?.Brand__c);
            result.put('modele',            a.Vehicule__r?.ModelePicklist__c);
            result.put('usage',             a.Vehicule__r?.Usage__c);
            result.put('numeroContrat',     a.Vehicule__r?.NbDeContratDAssurance__c);
            result.put('typePersonne',      a.Vehicule__r?.ProprietaireDuVehicule__r?.TypePersonne__c);
            result.put('nomCompletTiers',   a.Vehicule__r?.ProprietaireDuVehicule__r?.Name);
            result.put('cniTiers',          a.Vehicule__r?.ProprietaireDuVehicule__r?.CIN__c);
            result.put('adresse',           a.Vehicule__r?.ProprietaireDuVehicule__r?.Adresse__c);
            result.put('ville',             a.Vehicule__r?.ProprietaireDuVehicule__r?.Ville__c);
            result.put('pays',             a.Vehicule__r?.ProprietaireDuVehicule__r?.Pays__c);
            result.put('moyenNotification', a.Vehicule__r?.ProprietaireDuVehicule__r?.MoyenNotification__c);
            result.put('telephone',         a.Vehicule__r?.ProprietaireDuVehicule__r?.Phone);
            result.put('email',             a.Vehicule__r?.ProprietaireDuVehicule__r?.Email__c);
        }
        return result;
    }
}