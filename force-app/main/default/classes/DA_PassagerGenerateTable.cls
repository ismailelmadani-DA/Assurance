public with sharing class DA_PassagerGenerateTable {

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
            'isDriver__c, ParticipantAccount__c, Vehicule__c, ' +
            'ParticipantAccount__r.Name, ParticipantAccount__r.Nom__c, ' +
            'ParticipantAccount__r.Prenom__c, ParticipantAccount__r.Civility__c, ' +
            'ParticipantAccount__r.Email__c, ParticipantAccount__r.Phone';

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

        @AuraEnabled(cacheable=false)
        public static Map<String, Object> getParticipantById(Id participantId) {
            if (participantId == null) {
                throw new AuraHandledException('L\'identifiant du participant est requis.');
            }
            try {
                System.debug('🔍 Tentative de récupération du participant: ' + participantId);
                System.debug('🔍 Champs demandés: ' + PARTICIPANT_DETAIL_FIELDS);
                
                ClaimParticipant__c p = (ClaimParticipant__c) DM_DataManager.getById(PARTICIPANT_DETAIL_FIELDS, CLAIM_PARTICIPANT, participantId);
                if (p == null) {
                    throw new AuraHandledException('Participant introuvable.');
                }

                System.debug('✅ Participant trouvé: ' + p.Id);
                
                Map<String, Object> result = new Map<String, Object>();
                result.put('participantId', p.Id);
                result.put('accountId', p.ParticipantAccount__c);
                result.put('roles', p.Roles__c);
                result.put('civility', p.ParticipantAccount__r?.Civility__c);
                result.put('sexe', p.Sexe__c);
                result.put('nom', p.ParticipantAccount__r?.Nom__c);
                result.put('prenom', p.ParticipantAccount__r?.Prenom__c);
                result.put('dateNaissance', p.BirthDay__c != null ? String.valueOf(p.BirthDay__c) : '');
                result.put('cni', p.ParticipantCNI__c);
                result.put('situationFamiliale', p.MaritalStatus__c);
                result.put('pays', p.Pays__c);
                result.put('ville', p.Ville__c);
                result.put('adresse', p.Adresse__c);
                result.put('typeContact', p.TypeContact__c);
                result.put('telephone', p.ParticipantAccount__r?.Phone);
                result.put('email', p.ParticipantAccount__r?.Email__c);
                result.put('etatPassager', p.StateOfPerson__c);
                result.put('compagnieAdverse', p.CompagnieAdverse__c);
                result.put('itt', p.ITT__c);
                result.put('ipp', p.IPP__c);
                result.put('dateDeces', p.DateDeces__c != null ? String.valueOf(p.DateDeces__c) : '');
                result.put('revenuAnnuel', p.RevenuAnnuel__c);
                result.put('conducteur', p.isDriver__c);
                result.put('vehiculeId', p.Vehicule__c != null ? String.valueOf(p.Vehicule__c) : '');
                
                System.debug('✅ Map construite avec succès');
                return result;
            } catch (Exception e) {
                System.debug('❌ Erreur: ' + e.getMessage());
                System.debug('❌ Stack trace: ' + e.getStackTraceString());
                throw new AuraHandledException('Erreur lors du chargement du participant: ' + e.getMessage());
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
            // ✅ METTRE À JOUR L'ACCOUNT AVEC LES DONNÉES DU FORMULAIRE
            Account account = new Account(Id = accountId);
            
            // Récupérer les données du formulaire
            String civility = (String) formData.get('civility');
            String nom = (String) formData.get('nom');
            String prenom = (String) formData.get('prenom');
            String email = (String) formData.get('email');
            String telephone = (String) formData.get('telephone');
            
            // Mettre à jour les champs du compte
            if (String.isNotBlank(civility)) {
                account.Civility__c = civility;
            }
            if (String.isNotBlank(nom)) {
                account.Nom__c = nom;
            }
            if (String.isNotBlank(prenom)) {
                account.Prenom__c = prenom;
            }
            if (String.isNotBlank(email)) {
                account.Email__c = email;
            }
            if (String.isNotBlank(telephone)) {
                account.Phone = telephone;
            }
            
            // Mettre à jour le Name si pas de Nom__c/Prenom__c
            if (String.isNotBlank(nom) || String.isNotBlank(prenom)) {
                account.Name = ((nom != null ? nom : '') + ' ' + (prenom != null ? prenom : '')).trim();
            }
            
            update account;

            // ✅ METTRE À JOUR / CRÉER LE CLAIM PARTICIPANT
            ClaimParticipant__c participant;

            if (isUpdateMode && formData.get('participantId') != null) {
                participant = new ClaimParticipant__c(
                    Id = (Id) formData.get('participantId')
                );
            } else {
                participant = new ClaimParticipant__c();
                participant.Claim__c = claimId;
                participant.Roles__c = 'Passager assuré'; // ✅ Valeur par défaut à la création
            }

            // Assigner le véhicule (pour création et mise à jour si passager adverse)
            if (vehiculeId != null) {
                participant.Vehicule__c = vehiculeId;
            } else if (formData.get('vehiculeId') != null) {
                String vehId = (String) formData.get('vehiculeId');
                if (String.isNotBlank(vehId)) {
                    participant.Vehicule__c = (Id) vehId;
                }
            }

            participant.ParticipantAccount__c = accountId;

            // ✅ N'écrase le rôle que s'il est explicitement fourni
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

        /**
         * Récupère les véhicules associés à un sinistre
         * pour les passagers adverses
         */
        @AuraEnabled(cacheable=false)
        public static List<Map<String, Object>> getVehiclesForClaim(Id claimId) {
            if (claimId == null) {
                throw new AuraHandledException('L\'identifiant du sinistre est requis.');
            }
            try {
                String conditions = 'Claim__c = \'' + String.escapeSingleQuotes(String.valueOf(claimId)) + '\'';
                List<SObject> vehicles = DM_DataManager.query(
                    'Id, RegistrationNumber__c',
                    'VehicleCaseAssignment__c',
                    conditions,
                    null,
                    null
                );

                List<Map<String, Object>> result = new List<Map<String, Object>>();
                for (SObject vehicle : vehicles) {
                    Map<String, Object> item = new Map<String, Object>();
                    item.put('label', (String) vehicle.get('RegistrationNumber__c'));
                    item.put('value', (String) vehicle.get('Id'));
                    result.add(item);
                }
                return result;
            } catch (Exception e) {
                throw new AuraHandledException('Erreur lors de la récupération des véhicules: ' + e.getMessage());
            }
        }

        /**
         * @description      : Récupère la liste des compagnies adverses avec filtre de recherche
         * @method Name      : searchCompagniesAdverses
         * @author           : D&A Technologies
         * @date             : 2026-04-21
         * @param searchTerm : Terme de recherche (filtré par Name)
         * @return           : List<Map<String, Object>> - Liste des compagnies adverses filtrées
         */
        @AuraEnabled(cacheable=false)
        public static List<Map<String, Object>> searchCompagniesAdverses(String searchTerm) {
            List<Map<String, Object>> compagnies = new List<Map<String, Object>>();
            try {
                String searchPattern = String.isBlank(searchTerm) ? '' : searchTerm.trim();
                String query = 'SELECT Id, Name FROM Account WHERE RecordType.DeveloperName = \'CompagnieAdverse__c\'';
                
                if (String.isNotBlank(searchPattern)) {
                    query += ' AND Name LIKE \'%' + String.escapeSingleQuotes(searchPattern) + '%\'';
                }
                
                query += ' ORDER BY Name ASC LIMIT 20';
                
                List<Account> accounts = Database.query(query);

                for (Account acc : accounts) {
                    Map<String, Object> item = new Map<String, Object>();
                    item.put('label', acc.Name);
                    item.put('value', acc.Id);
                    item.put('id', acc.Id);
                    item.put('name', acc.Name);
                    compagnies.add(item);
                }

                return compagnies;
            } catch (Exception e) {
                throw new AuraHandledException('Erreur lors de la recherche des compagnies adverses: ' + e.getMessage());
            }
        }

        /**
         * @description      : Récupère la liste des compagnies adverses
         * @method Name      : getCompagniesAdverses
         * @author           : D&A Technologies
         * @date             : 2026-04-21
         * @return           : List<Map<String, Object>> - Liste des compagnies adverses avec Id et Name
         */
        @AuraEnabled(cacheable=true)
        public static List<Map<String, Object>> getCompagniesAdverses() {
            List<Map<String, Object>> compagnies = new List<Map<String, Object>>();
            try {
                List<Account> accounts = [
                    SELECT Id, Name 
                    FROM Account 
                    WHERE RecordType.DeveloperName = 'CompagnieAdverse__c'
                    ORDER BY Name ASC
                    LIMIT 20
                ];

                for (Account acc : accounts) {
                    Map<String, Object> item = new Map<String, Object>();
                    item.put('label', acc.Name);
                    item.put('value', acc.Id);
                    item.put('id', acc.Id);
                    item.put('name', acc.Name);
                    compagnies.add(item);
                }

                return compagnies;
            } catch (Exception e) {
                throw new AuraHandledException('Erreur lors du chargement des compagnies adverses: ' + e.getMessage());
            }
        }

    }