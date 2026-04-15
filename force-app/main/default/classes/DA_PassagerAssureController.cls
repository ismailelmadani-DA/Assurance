public with sharing class DA_PassagerAssureController {

    private static final String CLASS_NAME = DA_PassagerAssureController.class.getName();
    private static final String CLAIM_PARTICIPANT = 'ClaimParticipant__c';
    private static final String ACCOUNT = 'Account';

    private static final String PARTICIPANT_LIST_FIELDS =
        'Id, ParticipantCNI__c, Roles__c, isDriver__c, ' +
        'StateOfPerson__c, Pays__c, Ville__c, Sexe__c, ' +
        'ParticipantAccount__c, ParticipantAccount__r.Name, ' +
        'ParticipantAccount__r.Civility__c';

    private static final String PARTICIPANT_DETAIL_FIELDS =
        'Id, Roles__c, Sexe__c, ParticipantCNI__c, ' +
        'BirthDay__c, MaritalStatus__c, ' +
        'Pays__c, Ville__c, Adresse__c, TypeContact__c, ' +
        'StateOfPerson__c, CompagnieAdverse__c, ' +
        'ITT__c, IPP__c, DateDeces__c, RevenuAnnuel__c, ' +
        'isDriver__c, ParticipantAccount__c, ' +
        'ParticipantAccount__r.Name, ParticipantAccount__r.Nom__c, ' +
        'ParticipantAccount__r.Prenom__c, ParticipantAccount__r.Civility__c, ' +
        'ParticipantAccount__r.Email__c, ParticipantAccount__r.MoyenNotification__c';

    @AuraEnabled(cacheable=false)
    public static List<SObject> getParticipants(Id claimId) {
        if (claimId == null) {
            throw new AuraHandledException('L\'identifiant du sinistre est requis.');
        }
        try {
            String conditions = 'Claim__c = \'' + String.escapeSingleQuotes(String.valueOf(claimId)) + '\'';
            return DM_DataManager.query(PARTICIPANT_LIST_FIELDS, CLAIM_PARTICIPANT, conditions, 'CreatedDate DESC', null);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> getParticipantById(Id participantId) {
        if (participantId == null) {
            throw new AuraHandledException('L\'identifiant du participant est requis.');
        }
        try {
            ClaimParticipant__c p = (ClaimParticipant__c) DM_DataManager.getById(PARTICIPANT_DETAIL_FIELDS, CLAIM_PARTICIPANT, participantId);
            if (p == null) {
                throw new AuraHandledException('Participant introuvable.');
            }

            Map<String, Object> result = new Map<String, Object>();
            result.put('participantId', p.Id);
            result.put('accountId', p.ParticipantAccount__c);
            result.put('roles', p.Roles__c);
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
            result.put('telephone', '');
            result.put('email', p.ParticipantAccount__r.Email__c);
            result.put('etatPassager', p.StateOfPerson__c);
            result.put('compagnieAdverse', p.CompagnieAdverse__c);
            result.put('itt', p.ITT__c);
            result.put('ipp', p.IPP__c);
            result.put('dateDeces', p.DateDeces__c != null ? String.valueOf(p.DateDeces__c) : '');
            result.put('revenuAnnuel', p.RevenuAnnuel__c);
            result.put('conducteur', p.isDriver__c);
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean checkDuplicate(String nom, String prenom, Id claimId, Id excludeId) {
        if (String.isBlank(nom) || String.isBlank(prenom) || claimId == null) {
            return false;
        }
        try {
            String fullName = String.escapeSingleQuotes(nom.trim() + ' ' + prenom.trim());
            String safeClaimId = String.escapeSingleQuotes(String.valueOf(claimId));
            String conditions = 'Claim__c = \'' + safeClaimId + '\' AND ParticipantAccount__r.Name = \'' + fullName + '\'';
            if (excludeId != null) {
                conditions += ' AND Id != \'' + String.escapeSingleQuotes(String.valueOf(excludeId)) + '\'';
            }
            List<SObject> existing = DM_DataManager.query('Id', CLAIM_PARTICIPANT, conditions, null, 1);
            return !existing.isEmpty();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> upsertPassager(Map<String, Object> formData, Id claimId, Id vehiculeId, Boolean isUpdateMode) {
        Map<String, Object> response = new Map<String, Object>();

        if (claimId == null) {
            response.put('success', false);
            response.put('message', 'L\'identifiant du sinistre est requis.');
            return response;
        }

        try {
            String cni = (String) formData.get('cni');
            String nom = (String) formData.get('nom');
            String prenom = (String) formData.get('prenom');
            String civility = (String) formData.get('civility');

            if (String.isBlank(cni)) {
                response.put('success', false);
                response.put('message', 'Le CNI est obligatoire pour identifier le compte.');
                return response;
            }

            Id accountId = resolveAccount(formData);

            ClaimParticipant__c participant;

            if (isUpdateMode && formData.get('participantId') != null) {
                participant = new ClaimParticipant__c(
                    Id = (Id) formData.get('participantId')
                );
            } else {
                participant = new ClaimParticipant__c();
                participant.Claim__c = claimId;
                if (vehiculeId != null) {
                    participant.Vehicule__c = vehiculeId;
                }
            }

            participant.ParticipantAccount__c = accountId;
            participant.Roles__c = (String) formData.get('roles');
            participant.Sexe__c = (String) formData.get('sexe');
            participant.MaritalStatus__c = (String) formData.get('situationFamiliale');
            participant.Pays__c = (String) formData.get('pays');
            participant.Ville__c = (String) formData.get('ville');
            participant.Adresse__c = (String) formData.get('adresse');
            participant.TypeContact__c = (String) formData.get('typeContact');
            participant.StateOfPerson__c = (String) formData.get('etatPassager');
            participant.isDriver__c = formData.get('conducteur') == true;

            String compagnieAdverseId = (String) formData.get('compagnieAdverse');
            if (String.isNotBlank(compagnieAdverseId)) {
                participant.CompagnieAdverse__c = (Id) compagnieAdverseId;
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

            upsert participant;

            response.put('success', true);
            response.put('message', isUpdateMode ? 'Passager modifié avec succès.' : 'Passager ajouté avec succès.');
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
            response.put('message', 'Passager supprimé avec succès.');
            return response;
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', e.getMessage());
            return response;
        }
    }

    private static Id resolveAccount(Map<String, Object> formData) {
        String cni = (String) formData.get('cni');
        String nom = (String) formData.get('nom');
        String prenom = (String) formData.get('prenom');

        String safeCni = String.escapeSingleQuotes(cni);
        List<SObject> existing = DM_DataManager.query('Id', ACCOUNT, 'CIN__c = \'' + safeCni + '\'', null, 1);

        if (!existing.isEmpty()) {
            return existing[0].Id;
        }

        Account newAcc = new Account();
        newAcc.Name = (nom != null ? nom.trim() : '') + ' ' + (prenom != null ? prenom.trim() : '');
        newAcc.Nom__c = nom != null ? nom.trim() : '';
        newAcc.Prenom__c = prenom != null ? prenom.trim() : '';
        newAcc.CIN__c = cni;

        String civility = (String) formData.get('civility');
        if (String.isNotBlank(civility)) {
            newAcc.Civility__c = civility;
        }

        String sexe = (String) formData.get('sexe');
        if (String.isNotBlank(sexe)) {
            newAcc.Sexe__c = sexe;
        }

        String pays = (String) formData.get('pays');
        if (String.isNotBlank(pays)) {
            newAcc.Pays__c = pays;
        }

        String ville = (String) formData.get('ville');
        if (String.isNotBlank(ville)) {
            newAcc.Ville__c = ville;
        }

        String adresse = (String) formData.get('adresse');
        if (String.isNotBlank(adresse)) {
            newAcc.Adresse__c = adresse;
        }

        String email = (String) formData.get('email');
        if (String.isNotBlank(email)) {
            newAcc.Email__c = email;
        }

        String situationFamiliale = (String) formData.get('situationFamiliale');
        if (String.isNotBlank(situationFamiliale)) {
            newAcc.MaritalStatus__c = situationFamiliale;
        }

        String typeContact = (String) formData.get('typeContact');
        if (String.isNotBlank(typeContact)) {
            newAcc.MoyenNotification__c = typeContact;
        }

        String dateNaissStr = (String) formData.get('dateNaissance');
        if (String.isNotBlank(dateNaissStr)) {
            newAcc.DateDeNaissance__c = Date.valueOf(dateNaissStr);
        }

        insert newAcc;
        return newAcc.Id;
    }
}