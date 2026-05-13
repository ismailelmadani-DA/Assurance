public with sharing class EM002_VehicleCaseAssignment {

    private static final String VEHICLE_ASSIGNMENT = 'VehicleCaseAssignment__c';

    /**
     * Crée Account + Vehicule__c + VehicleCaseAssignment__c.
     */
    public static Map<String, Object> insertVehiculeAdverse(Map<String, Object> formData, Id claimId) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            Account acc = upsertProprietaire(formData);
            Vehicule__c veh = buildVehicule(formData, null, acc?.Id);
            insert veh;

            VehicleCaseAssignment__c assignment = new VehicleCaseAssignment__c();
            assignment.Claim__c         = claimId;
            assignment.isOpposingCar__c = true;
            populateAssignment(assignment, formData, veh.Id);
            insert assignment;

            response.put('success',      true);
            response.put('message',      'Véhicule adverse ajouté avec succès.');
            response.put('assignmentId', assignment.Id);
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', handleException(e));
            if (isDateError(e)) response.put('fieldError', 'dateMiseEnCirculation');
        }
        return response;
    }

    /**
     * Met à jour Account + Vehicule__c + VehicleCaseAssignment__c existants.
     */
    public static Map<String, Object> updateVehiculeAdverse(Map<String, Object> formData) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            Account acc = upsertProprietaire(formData);
            String vehiculeId = (String) formData.get('vehiculeId');
            Vehicule__c veh = buildVehicule(formData, vehiculeId, acc?.Id);
            upsert veh;

            VehicleCaseAssignment__c assignment =
                new VehicleCaseAssignment__c(Id = (Id) formData.get('assignmentId'));
            populateAssignment(assignment, formData, veh.Id);
            update assignment;

            response.put('success',      true);
            response.put('message',      'Véhicule adverse modifié avec succès.');
            response.put('assignmentId', assignment.Id);
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', handleException(e));
            if (isDateError(e)) response.put('fieldError', 'dateMiseEnCirculation');
        }
        return response;
    }

    /**
     * Supprime un VehicleCaseAssignment__c par son Id.
     */
    public static Map<String, Object> deleteVehiculeAdverse(Id assignmentId) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            String safeId = String.escapeSingleQuotes(String.valueOf(assignmentId));
            List<SObject> toDelete = DA_Utility.query(
                'Id', VEHICLE_ASSIGNMENT,
                'Id = \'' + safeId + '\'', null, 1
            );
            if (!toDelete.isEmpty()) delete toDelete[0];

            response.put('success', true);
            response.put('message', 'Véhicule adverse supprimé avec succès.');
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', handleException(e));
        }
        return response;
    }

    // ── Méthodes privées ────────────────────────────────────────────────────

    private static Account upsertProprietaire(Map<String, Object> formData) {
        String nom = (String) formData.get('nomCompletTiers');
        String cin = (String) formData.get('cniTiers');
        if (String.isBlank(nom) && String.isBlank(cin)) return null;

        Account acc;
        if (String.isNotBlank(cin)) {
            List<Account> existing = [
                SELECT Id, Name, CIN__c, Phone, Email__c,
                       MoyenNotification__c, Adresse__c, Ville__c, Pays__c
                FROM Account WHERE CIN__c = :cin LIMIT 1
            ];
            if (!existing.isEmpty()) acc = existing[0];
        }
        if (acc == null) {
        acc = new Account();
        acc.CIN__c = cin;
        Id passagerRtId = DA_Utility.getRecordTypeId('Account', 'Passager');
        if (passagerRtId != null) acc.RecordTypeId = passagerRtId;
        }

        if (String.isNotBlank(nom))                                   acc.Name            = nom;
        if (String.isNotBlank((String) formData.get('adresse')))      acc.Adresse__c      = (String) formData.get('adresse');
        if (String.isNotBlank((String) formData.get('ville')))        acc.Ville__c        = (String) formData.get('ville');
        if (String.isNotBlank((String) formData.get('pays')))         acc.Pays__c         = (String) formData.get('pays');
        if (String.isNotBlank((String) formData.get('telephone')))    acc.Phone           = (String) formData.get('telephone');
        if (String.isNotBlank((String) formData.get('email')))        acc.Email__c        = (String) formData.get('email');
        if (String.isNotBlank((String) formData.get('typePersonne'))) acc.TypePersonne__c = (String) formData.get('typePersonne');

        // ── Moyen de notification ──────────────────────────────────────────
        // Les valeurs sont chargées directement depuis le picklist Salesforce
        // via getPicklistValues(), donc elles correspondent déjà aux API Names exacts.
        String moyenNotif = (String) formData.get('moyenNotification');
        if (String.isNotBlank(moyenNotif)) {
            acc.MoyenNotification__c = moyenNotif;
        }

        upsert acc;
        return acc;
    }

    private static Vehicule__c buildVehicule(Map<String, Object> formData, String vehiculeId, Id proprietaireId) {
        Vehicule__c veh = String.isNotBlank(vehiculeId)
            ? new Vehicule__c(Id = (Id) vehiculeId)
            : new Vehicule__c();

        veh.RegistrationNumber__c      = (String) formData.get('immatriculation');
        veh.Brand__c                   = (String) formData.get('marque');
        veh.ModelePicklist__c          = (String) formData.get('modele');
        veh.Usage__c                   = (String) formData.get('usage');
        veh.TypeVehicule__c            = (String) formData.get('typeVehicule');
        veh.NbDeContratDAssurance__c   = (String) formData.get('numeroContrat');
        veh.AdversaireAssur__c         = formData.get('adversaireAssure') == 'true';
        veh.CompagnieAdverse__c        = String.isNotBlank((String) formData.get('compagnieAdverseId'))
            ? (Id) formData.get('compagnieAdverseId') : null;
        veh.DateOfFirstRegistration__c = String.isNotBlank((String) formData.get('dateMiseEnCirculation'))
            ? Date.valueOf((String) formData.get('dateMiseEnCirculation')) : null;
        veh.ProprietaireDuVehicule__c  = proprietaireId;
        return veh;
    }

    private static void populateAssignment(VehicleCaseAssignment__c a, Map<String, Object> formData, Id vehiculeId) {
        a.Vehicule__c         = vehiculeId;
        a.EtatVehicule__c     = (String) formData.get('etatVehicule');
        a.AdversaireAssure__c = formData.get('adversaireAssure') == 'true';
        a.TypeVehicule__c     = (String) formData.get('typeVehicule');
        a.CompagnieAdverse__c = String.isNotBlank((String) formData.get('compagnieAdverseId'))
            ? (Id) formData.get('compagnieAdverseId') : null;

        String dateStr = (String) formData.get('dateMiseEnCirculation');
        if (String.isNotBlank(dateStr)) a.DateMiseEnCirculation__c = Date.valueOf(dateStr);

        Object nbPass = formData.get('nbPassagerBlesses');
        if (nbPass != null && String.valueOf(nbPass) != '')
            a.NbDePassagerBlesses__c = Integer.valueOf(String.valueOf(nbPass));
    }

    private static Boolean isDateError(Exception e) {
        String msg = e.getMessage();
        return msg != null && msg.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION') &&
            (msg.contains('Date_MiseEnCirculation_Valide') || msg.contains('date de mise en circulation'));
    }

    private static String handleException(Exception e) {
        if (isDateError(e))
            return 'Date invalide : la date de mise en circulation doit être antérieure à la date du sinistre et à la date du jour.';
        String msg = e.getMessage();
        if (msg == null)                                return 'Une erreur inattendue s\'est produite.';
        if (msg.contains('FIELD_INTEGRITY_EXCEPTION'))  return 'Erreur de données : un champ obligatoire est manquant ou contient une valeur incorrecte.';
        if (msg.contains('DUPLICATE_VALUE'))            return 'Un enregistrement avec ces informations existe déjà.';
        if (msg.contains('INSUFFICIENT_ACCESS'))        return 'Vous n\'avez pas les droits nécessaires pour effectuer cette action.';
        if (msg.contains('REQUIRED_FIELD_MISSING'))     return 'Un ou plusieurs champs obligatoires ne sont pas renseignés.';
        if (msg.contains('STRING_TOO_LONG'))            return 'Un des champs dépasse la longueur maximale autorisée.';
        if (msg.contains('INVALID_CROSS_REFERENCE_KEY') || msg.contains('id value of incorrect type'))
                                                        return 'Référence invalide : vérifiez que le sinistre et le véhicule sont correctement configurés.';
        if (msg.contains('ENTITY_IS_DELETED'))          return 'L\'enregistrement a déjà été supprimé.';
        if (msg.contains('DELETE_FAILED'))              return 'La suppression a échoué. L\'enregistrement est peut-être utilisé par d\'autres éléments.';
        if (msg.contains('No such column'))             return 'Erreur de configuration : un champ est introuvable. Contactez votre administrateur.';
        if (msg.contains('INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST'))
                                                        return 'Valeur invalide pour un champ picklist restreint. Vérifiez les valeurs saisies.';
        return 'Une erreur est survenue lors du traitement. Veuillez réessayer. ' + msg;
    }
}