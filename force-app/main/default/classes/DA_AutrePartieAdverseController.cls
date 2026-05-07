public with sharing class DA_AutrePartieAdverseController {

    private static final String ROLE_AUTRE_PARTIE = 'Autres partie';

    private static final String PARTICIPANT_LIST_FIELDS =
        'Id, ParticipantCNI__c, Roles__c, TypePartieAdverse__c, ' +
        'StateOfPerson__c, Pays__c, Ville__c, ' +
        'CompagnieAdverse__c, CompagnieAdverse__r.Name, ' +
        'PaysCompagnieAdverse__c, NumeroContratAssurance__c, ' +
        'ParticipantAccount__c, ParticipantAccount__r.Name, ' +
        'ParticipantAccount__r.Nom__c, ParticipantAccount__r.Prenom__c, ' +
        'ParticipantAccount__r.Civility__c';

    private static final String PARTICIPANT_DETAIL_FIELDS =
        'Id, Roles__c, Sexe__c, ParticipantCNI__c, ' +
        'BirthDay__c, MaritalStatus__c, TypePartieAdverse__c, ' +
        'Pays__c, Ville__c, Adresse__c, TypeContact__c, ' +
        'StateOfPerson__c, CompagnieAdverse__c, ' +
        'PaysCompagnieAdverse__c, NumeroContratAssurance__c, ' +
        'ITT__c, IPP__c, DateDeces__c, RevenuAnnuel__c, Description__c, ' +
        'ParticipantAccount__c, ' +
        'ParticipantAccount__r.Name, ParticipantAccount__r.Nom__c, ' +
        'ParticipantAccount__r.Prenom__c, ParticipantAccount__r.Civility__c, ' +
        'ParticipantAccount__r.Email__c, ParticipantAccount__r.Phone, ParticipantAccount__r.MoyenNotification__c';

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
            return 'Référence invalide : vérifiez que le sinistre est correctement configuré.';
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
    public static List<SObject> getParticipants(Id claimId) {
        if (claimId == null) {
            throw new AuraHandledException('L\'identifiant du sinistre est requis.');
        }
        try {
            return DM005_ClaimParticipant.getByClaimAndRole(PARTICIPANT_LIST_FIELDS, claimId, ROLE_AUTRE_PARTIE);
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
            ClaimParticipant__c p = DM005_ClaimParticipant.getById(PARTICIPANT_DETAIL_FIELDS, participantId);
            if (p == null) {
                throw new AuraHandledException('Participant introuvable.');
            }

            Map<String, Object> result = new Map<String, Object>();
            result.put('participantId', p.Id);
            result.put('accountId', p.ParticipantAccount__c);
            result.put('typePartieAdverse', p.TypePartieAdverse__c);
            result.put('nomComplet', p.ParticipantAccount__r.Name);
            result.put('civility', p.ParticipantAccount__r.Civility__c);
            result.put('sexe', p.Sexe__c);
            result.put('dateNaissance', p.BirthDay__c != null ? String.valueOf(p.BirthDay__c) : '');
            result.put('cin', p.ParticipantCNI__c);
            result.put('situationFamiliale', p.MaritalStatus__c);
            result.put('pays', p.Pays__c);
            result.put('ville', p.Ville__c);
            result.put('adresse', p.Adresse__c);
            result.put('etatPassager', p.StateOfPerson__c);
            result.put('compagnieAdverseId', p.CompagnieAdverse__c);
            result.put('paysCompagnieAdverse', p.PaysCompagnieAdverse__c);
            result.put('numeroContrat', p.NumeroContratAssurance__c);
            result.put('typeContact', p.TypeContact__c);
            result.put('email', p.ParticipantAccount__r.Email__c);
            result.put('telephone', p.ParticipantAccount__r.Phone);
            result.put('itt', p.ITT__c);
            result.put('ipp', p.IPP__c);
            result.put('dateDeces', p.DateDeces__c != null ? String.valueOf(p.DateDeces__c) : '');
            result.put('revenuAnnuel', p.RevenuAnnuel__c);
            result.put('description', p.Description__c);
            return result;
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException(friendlyError(e));
        }
    }

    @AuraEnabled
    public static List<Map<String, String>> searchCompagnies(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return new List<Map<String, String>>();
        }
        try {
            List<SObject> results = DA_Utility.search('Id, Name', 'Account', 'Name', searchTerm, null, 10);
            List<Map<String, String>> options = new List<Map<String, String>>();
            for (SObject acc : results) {
                options.add(new Map<String, String>{
                    'value' => (String) acc.get('Id'),
                    'label' => (String) acc.get('Name')
                });
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean checkDuplicate(String cin, Id claimId, Id excludeId) {
        if (String.isBlank(cin) || claimId == null) {
            return false;
        }
        try {
            return DM005_ClaimParticipant.existsByClaimRoleAndCIN(claimId, ROLE_AUTRE_PARTIE, cin, excludeId);
        } catch (Exception e) {
            return false;
        }
    }

    @AuraEnabled
    public static Map<String, Object> upsertPartie(Map<String, Object> formData, Id claimId, Boolean isUpdateMode, Id accountId) {
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
            // Validate state transition on update
            if (isUpdateMode && formData.get('participantId') != null) {
                String newEtat = (String) formData.get('etatPassager');
                ClaimParticipant__c existing = DM005_ClaimParticipant.getById(
                    'Id, StateOfPerson__c', (Id) formData.get('participantId')
                );
                if (existing != null && String.isNotBlank(existing.StateOfPerson__c) && String.isNotBlank(newEtat)) {
                    String oldEtat = existing.StateOfPerson__c;
                    Boolean invalid = false;
                    if (oldEtat == 'Décédé' && newEtat != 'Décédé') {
                        invalid = true;
                    } else if (oldEtat == 'Blessé' && newEtat != 'Blessé' && newEtat != 'Décédé') {
                        invalid = true;
                    }
                    if (invalid) {
                        response.put('success', false);
                        response.put('message', 'Transition d\'état invalide : ' + oldEtat + ' → ' + newEtat + ' n\'est pas autorisée.');
                        return response;
                    }
                }
            }

            // Validate dates
            Claim__c claim = DM006_Claim.getById('Id, CreatedDate', claimId);
            if (claim != null) {
                Date sinistreDate = claim.CreatedDate != null
                    ? claim.CreatedDate.date()
                    : Date.today();

                String dateNaissStr = (String) formData.get('dateNaissance');
                if (String.isNotBlank(dateNaissStr)) {
                    Date dateNaissance = Date.valueOf(dateNaissStr);
                    if (dateNaissance > sinistreDate) {
                        response.put('success', false);
                        response.put('message', 'La date de naissance ne peut pas être postérieure à la date du sinistre.');
                        return response;
                    }
                }

                String dateDecesStr = (String) formData.get('dateDeces');
                if (String.isNotBlank(dateDecesStr)) {
                    Date dateDeces = Date.valueOf(dateDecesStr);
                    if (dateDeces > sinistreDate) {
                        response.put('success', false);
                        response.put('message', 'La date de décès ne peut pas être postérieure à la date du sinistre.');
                        return response;
                    }
                }
            }

            ClaimParticipant__c participant;
            if (isUpdateMode && formData.get('participantId') != null) {
                participant = new ClaimParticipant__c(Id = (Id) formData.get('participantId'));
            } else {
                participant = new ClaimParticipant__c();
                participant.Claim__c = claimId;
                participant.Roles__c = ROLE_AUTRE_PARTIE;
            }

            participant.ParticipantAccount__c = accountId;
            participant.TypePartieAdverse__c = (String) formData.get('typePartieAdverse');
            participant.Sexe__c = (String) formData.get('sexe');
            participant.MaritalStatus__c = (String) formData.get('situationFamiliale');
            participant.Pays__c = (String) formData.get('pays');
            participant.Ville__c = (String) formData.get('ville');
            participant.Adresse__c = (String) formData.get('adresse');
            participant.TypeContact__c = (String) formData.get('typeContact');
            participant.StateOfPerson__c = (String) formData.get('etatPassager');
            participant.PaysCompagnieAdverse__c = (String) formData.get('paysCompagnieAdverse');
            participant.NumeroContratAssurance__c = (String) formData.get('numeroContrat');

            String compagnieId = (String) formData.get('compagnieAdverseId');
            if (String.isNotBlank(compagnieId)) {
                participant.CompagnieAdverse__c = (Id) compagnieId;
            } else {
                participant.CompagnieAdverse__c = null;
            }

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

            participant.Description__c = (String) formData.get('description');

            upsert participant;

            // Update Account with all synced fields + RecordType Passager
            Map<String, Object> accFields = new Map<String, Object>();
            String civility = (String) formData.get('civility');
            if (String.isNotBlank(civility)) { accFields.put('Civility__c', civility); }
            String nomComplet = (String) formData.get('nomComplet');
            if (String.isNotBlank(nomComplet)) { accFields.put('Nom__c', nomComplet.trim()); }
            String email = (String) formData.get('email');
            if (String.isNotBlank(email)) { accFields.put('Email__c', email); }
            String phone = (String) formData.get('telephone');
            if (String.isNotBlank(phone)) { accFields.put('Phone', phone); }
            String sexe = (String) formData.get('sexe');
            if (String.isNotBlank(sexe)) { accFields.put('Sexe__c', sexe); }
            String cin = (String) formData.get('cin');
            if (String.isNotBlank(cin)) { accFields.put('CIN__c', cin.trim()); }
            String situationFamiliale = (String) formData.get('situationFamiliale');
            if (String.isNotBlank(situationFamiliale)) { accFields.put('MaritalStatus__c', situationFamiliale); }
            String pays = (String) formData.get('pays');
            if (String.isNotBlank(pays)) { accFields.put('Pays__c', pays); }
            String ville = (String) formData.get('ville');
            if (String.isNotBlank(ville)) { accFields.put('Ville__c', ville); }
            String adresse = (String) formData.get('adresse');
            if (String.isNotBlank(adresse)) { accFields.put('Adresse__c', adresse); }
            if (String.isNotBlank(dateNaissStr)) { accFields.put('DateDeNaissance__c', Date.valueOf(dateNaissStr)); }
            DA_Utility.updateByRecordType('Account', 'Passager', accountId, accFields);

            response.put('success', true);
            response.put('message', isUpdateMode ? 'Autre partie adverse modifiée avec succès.' : 'Autre partie adverse ajoutée avec succès.');
            response.put('participantId', participant.Id);
            return response;

        } catch (Exception e) {
            response.put('success', false);
            response.put('message', e.getMessage());
            return response;
        }
    }

    @AuraEnabled
    public static Map<String, Object> deletePartie(Id participantId) {
        Map<String, Object> response = new Map<String, Object>();
        if (participantId == null) {
            response.put('success', false);
            response.put('message', 'L\'identifiant du participant est requis.');
            return response;
        }
        try {
            DM005_ClaimParticipant.deleteById(participantId);
            response.put('success', true);
            response.put('message', 'Autre partie adverse supprimée avec succès.');
            return response;
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', friendlyError(e));
            return response;
        }
    }

}