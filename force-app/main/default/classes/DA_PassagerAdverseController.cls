public with sharing class DA_PassagerAdverseController {

    private static final String CLAIM_PARTICIPANT = 'ClaimParticipant__c';
    private static final String ACCOUNT = 'Account';
    private static final String VEHICLE_ASSIGNMENT = 'VehicleCaseAssignment__c';
    private static final String ROLE_ADVERSE = 'Passager adverse';

    private static final String PARTICIPANT_LIST_FIELDS =
        'Id, ParticipantCNI__c, Roles__c, isDriver__c, ' +
        'StateOfPerson__c, Pays__c, Ville__c, Sexe__c, ' +
        'Vehicule__c, Vehicule__r.RegistrationNumber__c, ' +
        'ParticipantAccount__c, ParticipantAccount__r.Name, ' +
        'ParticipantAccount__r.Civility__c';

    private static final String PARTICIPANT_DETAIL_FIELDS =
        'Id, Roles__c, Sexe__c, ParticipantCNI__c, ' +
        'BirthDay__c, MaritalStatus__c, ' +
        'Pays__c, Ville__c, Adresse__c, TypeContact__c, ' +
        'StateOfPerson__c, CompagnieAdverse__c, ' +
        'ITT__c, IPP__c, DateDeces__c, RevenuAnnuel__c, ' +
        'isDriver__c, Vehicule__c, ParticipantAccount__c, ' +
        'ParticipantAccount__r.Name, ParticipantAccount__r.Nom__c, ' +
        'ParticipantAccount__r.Prenom__c, ParticipantAccount__r.Civility__c, ' +
        'ParticipantAccount__r.Email__c, ParticipantAccount__r.Phone, ParticipantAccount__r.MoyenNotification__c';

    private static Id resolveClaimId(Id recordId) {
        if (recordId == null) {
            return null;
        }
        String prefix = String.valueOf(recordId).substring(0, 3);
        Schema.SObjectType claimType = Claim__c.SObjectType;
        String claimPrefix = claimType.getDescribe().getKeyPrefix();
        if (prefix == claimPrefix) {
            return recordId;
        }
        List<SObject> claims = DM_DataManager.query(
            'Id', 'Claim__c',
            'Case__c = \'' + String.escapeSingleQuotes(String.valueOf(recordId)) + '\'',
            'CreatedDate DESC', 1
        );
        if (!claims.isEmpty()) {
            return claims[0].Id;
        }
        return null;
    }

    private static String friendlyError(Exception e) {
        String msg = e.getMessage();
        if (msg == null) {
            return 'Une erreur inattendue s\'est produite.';
        }
        if (msg.contains('FIELD_INTEGRITY_EXCEPTION')) {
            return 'Erreur de données : un champ obligatoire est manquant ou contient une valeur incorrecte.';
        }
        if (msg.contains('DUPLICATE_VALUE')) {
            return 'Un enregistrement avec ces informations existe déjà.';
        }
        if (msg.contains('INSUFFICIENT_ACCESS')) {
            return 'Vous n\'avez pas les droits nécessaires pour effectuer cette action.';
        }
        if (msg.contains('REQUIRED_FIELD_MISSING')) {
            return 'Un ou plusieurs champs obligatoires ne sont pas renseignés.';
        }
        if (msg.contains('STRING_TOO_LONG')) {
            return 'Un des champs dépasse la longueur maximale autorisée.';
        }
        if (msg.contains('INVALID_CROSS_REFERENCE_KEY') || msg.contains('id value of incorrect type')) {
            return 'Référence invalide : vérifiez que le sinistre et le véhicule sont correctement configurés.';
        }
        if (msg.contains('ENTITY_IS_DELETED')) {
            return 'L\'enregistrement a déjà été supprimé.';
        }
        if (msg.contains('DELETE_FAILED')) {
            return 'La suppression a échoué. L\'enregistrement est peut-être utilisé par d\'autres éléments.';
        }
        return 'Une erreur est survenue lors du traitement. Veuillez réessayer.';
    }

    @AuraEnabled(cacheable=false)
    public static List<SObject> getAdverseVehicles(Id claimId) {
        if (claimId == null) {
            throw new AuraHandledException('L\'identifiant du sinistre est requis.');
        }
        try {
            Id resolvedId = resolveClaimId(claimId);
            if (resolvedId == null) {
                throw new AuraHandledException('Aucun sinistre trouvé pour cet enregistrement.');
            }
            String safeId = String.escapeSingleQuotes(String.valueOf(resolvedId));
            return DM_DataManager.query(
                'Id, Vehicule__c, Vehicule__r.RegistrationNumber__c, Vehicule__r.Brand__c, RegistrationNumber__c, Marque__c',
                VEHICLE_ASSIGNMENT,
                'Claim__c = \'' + safeId + '\' AND isOpposingCar__c = true',
                'CreatedDate DESC', null
            );
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException(friendlyError(e));
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<SObject> getParticipants(Id claimId) {
        if (claimId == null) {
            throw new AuraHandledException('L\'identifiant du sinistre est requis.');
        }
        try {
            Id resolvedId = resolveClaimId(claimId);
            if (resolvedId == null) {
                throw new AuraHandledException('Aucun sinistre trouvé pour cet enregistrement.');
            }
            String safeId = String.escapeSingleQuotes(String.valueOf(resolvedId));
            return DM_DataManager.query(
                PARTICIPANT_LIST_FIELDS, CLAIM_PARTICIPANT,
                'Claim__c = \'' + safeId + '\' AND Roles__c = \'' + ROLE_ADVERSE + '\'',
                'CreatedDate DESC', null
            );
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException(friendlyError(e));
        }
    }

    @AuraEnabled
    public static Map<String, Object> getParticipantById(Id participantId) {
        if (participantId == null) {
            throw new AuraHandledException('L\'identifiant du participant est requis.');
        }
        try {
            ClaimParticipant__c p = (ClaimParticipant__c) DM_DataManager.getById(
                PARTICIPANT_DETAIL_FIELDS, CLAIM_PARTICIPANT, participantId
            );
            if (p == null) {
                throw new AuraHandledException('Participant introuvable.');
            }

            Map<String, Object> result = new Map<String, Object>();
            result.put('participantId', p.Id);
            result.put('accountId', p.ParticipantAccount__c);
            result.put('vehiculeId', p.Vehicule__c);
            result.put('roles', p.Roles__c);
            result.put('nomComplet', p.ParticipantAccount__r.Name);
            result.put('civility', p.ParticipantAccount__r.Civility__c);
            result.put('sexe', p.Sexe__c);
            result.put('nom', p.ParticipantAccount__r.Nom__c);
            result.put('prenom', p.ParticipantAccount__r.Prenom__c);
            result.put('dateNaissance', p.BirthDay__c != null ? String.valueOf(p.BirthDay__c) : '');
            result.put('cni', p.ParticipantCNI__c);
            result.put('situationFamiliale', p.MaritalStatus__c);
            result.put('pays', p.Pays__c);
            result.put('ville', p.Ville__c);
            result.put('adresse', p.Adresse__c);
            result.put('typeContact', p.TypeContact__c);
            result.put('email', p.ParticipantAccount__r.Email__c);
            result.put('telephone', p.ParticipantAccount__r.Phone);
            result.put('etatPassager', p.StateOfPerson__c);
            result.put('itt', p.ITT__c);
            result.put('ipp', p.IPP__c);
            result.put('dateDeces', p.DateDeces__c != null ? String.valueOf(p.DateDeces__c) : '');
            result.put('revenuAnnuel', p.RevenuAnnuel__c);
            result.put('conducteur', p.isDriver__c);
            return result;
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException(friendlyError(e));
        }
    }

    @AuraEnabled
    public static Boolean checkDuplicate(String nomComplet, Id claimId, Id excludeId) {
        if (String.isBlank(nomComplet) || claimId == null) {
            return false;
        }
        try {
            Id resolvedId = resolveClaimId(claimId);
            if (resolvedId == null) {
                return false;
            }
            String fullName = String.escapeSingleQuotes(nomComplet.trim());
            String safeClaimId = String.escapeSingleQuotes(String.valueOf(resolvedId));
            String conditions = 'Claim__c = \'' + safeClaimId + '\' AND Roles__c = \'' + ROLE_ADVERSE +
                '\' AND ParticipantAccount__r.Name = \'' + fullName + '\'';
            if (excludeId != null) {
                conditions += ' AND Id != \'' + String.escapeSingleQuotes(String.valueOf(excludeId)) + '\'';
            }
            List<SObject> existing = DM_DataManager.query('Id', CLAIM_PARTICIPANT, conditions, null, 1);
            return !existing.isEmpty();
        } catch (Exception e) {
            return false;
        }
    }

    @AuraEnabled
    public static Map<String, Object> upsertPassager(Map<String, Object> formData, Id claimId, Boolean isUpdateMode, Id accountId) {
        Map<String, Object> response = new Map<String, Object>();

        if (claimId == null) {
            response.put('success', false);
            response.put('message', 'L\'identifiant du sinistre est requis.');
            return response;
        }

        if (accountId == null) {
            response.put('success', false);
            response.put('message', 'Le compte du participant est obligatoire.');
            return response;
        }

        try {
            Id resolvedClaimId = resolveClaimId(claimId);
            if (resolvedClaimId == null) {
                response.put('success', false);
                response.put('message', 'Aucun sinistre trouvé pour cet enregistrement.');
                return response;
            }

            ClaimParticipant__c participant;
            if (isUpdateMode && formData.get('participantId') != null) {
                participant = new ClaimParticipant__c(Id = (Id) formData.get('participantId'));
            } else {
                participant = new ClaimParticipant__c();
                participant.Claim__c = resolvedClaimId;
                participant.Roles__c = ROLE_ADVERSE;
            }

            String vehiculeId = (String) formData.get('vehiculeId');
            if (String.isNotBlank(vehiculeId)) {
                participant.Vehicule__c = (Id) vehiculeId;
            }

            participant.ParticipantAccount__c = accountId;
            participant.Sexe__c = (String) formData.get('sexe');
            participant.MaritalStatus__c = (String) formData.get('situationFamiliale');
            participant.Pays__c = (String) formData.get('pays');
            participant.Ville__c = (String) formData.get('ville');
            participant.Adresse__c = (String) formData.get('adresse');
            participant.TypeContact__c = (String) formData.get('typeContact');
            participant.StateOfPerson__c = (String) formData.get('etatPassager');
            participant.isDriver__c = formData.get('conducteur') == true;

            String dateNaissStr = (String) formData.get('dateNaissance');
            if (String.isNotBlank(dateNaissStr)) {
                participant.BirthDay__c = Date.valueOf(dateNaissStr);
            }

            String dateDecesStr = (String) formData.get('dateDeces');
            if (String.isNotBlank(dateDecesStr)) {
                participant.DateDeces__c = Date.valueOf(dateDecesStr);
            }

            if (formData.get('itt') != null) {
                participant.ITT__c = Decimal.valueOf(String.valueOf(formData.get('itt')));
            }
            if (formData.get('ipp') != null) {
                participant.IPP__c = Decimal.valueOf(String.valueOf(formData.get('ipp')));
            }
            if (formData.get('revenuAnnuel') != null) {
                participant.RevenuAnnuel__c = Decimal.valueOf(String.valueOf(formData.get('revenuAnnuel')));
            }

            Boolean isOwner = formData.get('isOwner') == true;
            upsert participant;

            // Update Account with civility, email, phone
            Account acc = new Account(Id = accountId);
            String civility = (String) formData.get('civility');
            if (String.isNotBlank(civility)) {
                acc.Civility__c = civility;
            }
            String email = (String) formData.get('email');
            if (String.isNotBlank(email)) {
                acc.Email__c = email;
            }
            String phone = (String) formData.get('telephone');
            if (String.isNotBlank(phone)) {
                acc.Phone = phone;
            }
            update acc;

            if (isOwner && String.isNotBlank(vehiculeId)) {
                Vehicule__c veh = new Vehicule__c(Id = (Id) vehiculeId);
                veh.ProprietaireDuVehicule__c = accountId;
                update veh;
            }

            response.put('success', true);
            response.put('message', isUpdateMode ? 'Passager adverse modifié avec succès.' : 'Passager adverse ajouté avec succès.');
            response.put('participantId', participant.Id);
            return response;

        } catch (Exception e) {
            response.put('success', false);
            response.put('message', e.getMessage());
            return response;
        }
    }

    @AuraEnabled
    public static Map<String, Object> deletePassager(Id participantId) {
        Map<String, Object> response = new Map<String, Object>();
        if (participantId == null) {
            response.put('success', false);
            response.put('message', 'L\'identifiant du participant est requis.');
            return response;
        }
        try {
            DM_DataManager.deleteById(CLAIM_PARTICIPANT, participantId);
            response.put('success', true);
            response.put('message', 'Passager adverse supprimé avec succès.');
            return response;
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', friendlyError(e));
            return response;
        }
    }

}
