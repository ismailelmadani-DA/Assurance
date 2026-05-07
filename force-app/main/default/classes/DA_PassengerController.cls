public with sharing class DA_PassengerController {

    private static final String CLASS_NAME = DA_PassengerController.class.getName();
    private static final String ROLE_PASSAGER_ASSURE = 'Passager assuré';

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
                    return DM005_ClaimParticipant.getByClaimId(PARTICIPANT_LIST_FIELDS, claimId);
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
                    ClaimParticipant__c p = DM005_ClaimParticipant.getById(PARTICIPANT_DETAIL_FIELDS, participantId);
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
            public static Boolean checkDuplicate(String cin, Id claimId, Id excludeId) {
                if (String.isBlank(cin) || claimId == null) {
                    return false;
                }
                try {
                    return DM005_ClaimParticipant.existsByClaimRoleAndCIN(claimId, ROLE_PASSAGER_ASSURE, cin, excludeId);
                } catch (Exception e) {
                    throw new AuraHandledException(e.getMessage());
                }
            }

        @AuraEnabled
        public static Map<String, Object> upsertPassager(Map<String, Object> formData, Id claimId, Id vehiculeId, Boolean isUpdateMode, Id accountId) {
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
                ClaimParticipant__c participant;

                if (isUpdateMode && formData.get('participantId') != null) {
                    participant = new ClaimParticipant__c(
                        Id = (Id) formData.get('participantId')
                    );
                } else {
                    participant = new ClaimParticipant__c();
                    participant.Claim__c = claimId;
                    participant.Roles__c = ROLE_PASSAGER_ASSURE;
                    if (vehiculeId != null) {
                        participant.Vehicule__c = vehiculeId;
                    }
                }

                participant.ParticipantAccount__c = accountId;

                // N'écrase le rôle que s'il est explicitement fourni
                String roles = (String) formData.get('roles');
                if (String.isNotBlank(roles)) {
                    participant.Roles__c = roles;
                }

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
                    DM005_ClaimParticipant.deleteById(participantId);
                    response.put('success', true);
                    response.put('message', 'Passager supprimé avec succès.');
                    return response;
                } catch (Exception e) {
                    response.put('success', false);
                    response.put('message', e.getMessage());
                    return response;
                }
            }

        }