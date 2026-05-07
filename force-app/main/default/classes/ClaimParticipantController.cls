/**
 * @description  : Controller LWC — Passagers assurés d'un sinistre
 * @author       : D&A Technologies
 * @date         : 2026-04-23
 */
public with sharing class ClaimParticipantController {

    private static final String ROLE_ASSURE = 'Passager assuré';

    // ══════════════════════════════════════════════════════════════════════
    // HELPER PRIVÉ
    // ══════════════════════════════════════════════════════════════════════

    private static String friendlyError(Exception e) {
        String msg = e.getMessage();
        if (msg == null)                               return 'Une erreur inattendue s\'est produite.';
        // CORRECTION : on laisse passer le préfixe CIN_DUPLICATE tel quel
        // pour que le LWC puisse identifier l'erreur et l'afficher sur le bon champ.
        if (msg.startsWith('CIN_DUPLICATE:'))          return msg;
        if (msg.contains('FIELD_INTEGRITY_EXCEPTION')) return 'Erreur de données : un champ obligatoire est manquant ou incorrect.';
        if (msg.contains('DUPLICATE_VALUE'))           return 'Un enregistrement avec ces informations existe déjà.';
        if (msg.contains('INSUFFICIENT_ACCESS'))       return 'Vous n\'avez pas les droits nécessaires pour effectuer cette action.';
        if (msg.contains('REQUIRED_FIELD_MISSING'))    return 'Un ou plusieurs champs obligatoires ne sont pas renseignés.';
        if (msg.contains('STRING_TOO_LONG'))           return 'Un champ dépasse la longueur maximale autorisée.';
        if (msg.contains('ENTITY_IS_DELETED'))         return 'L\'enregistrement a déjà été supprimé.';
        if (msg.contains('DELETE_FAILED'))             return 'La suppression a échoué. L\'enregistrement est peut-être utilisé ailleurs.';
        return 'Une erreur est survenue lors du traitement. Veuillez réessayer.';
    }

    // ══════════════════════════════════════════════════════════════════════
    // MÉTHODES @AuraEnabled
    // ══════════════════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=false)
    public static List<SObject> getClaimParticipants(Id claimId) {
        if (claimId == null) {
            throw new AuraHandledException('L\'identifiant du sinistre est requis.');
        }
        try {
            return DMClaimParticipant.getByClaimAndRole(claimId, ROLE_ASSURE);
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
            ClaimParticipant__c p = DMClaimParticipant.getDetailById(participantId);
            if (p == null) throw new AuraHandledException('Participant introuvable.');

            return new Map<String, Object>{
                'participantId'   => p.Id,
                'accountId'       => p.ParticipantAccount__c,
                'participantName' => p.ParticipantAccount__r?.Name,
                'civility'        => p.ParticipantAccount__r?.Civility__c,
                'email'           => p.ParticipantAccount__r?.Email__c,
                'phone'           => p.ParticipantAccount__r?.Phone,
                'cni'             => p.ParticipantCNI__c,
                'sexe'            => p.Sexe__c,
                'maritalStatus'   => p.MaritalStatus__c,
                'birthDate'       => p.BirthDay__c  != null ? String.valueOf(p.BirthDay__c)  : '',
                'address'         => p.Adresse__c,
                'city'            => p.Ville__c,
                'country'         => p.Pays__c,
                'stateOfPerson'   => p.StateOfPerson__c,
                'isDriver'        => p.isDriver__c,
                'ipp'             => p.IPP__c,
                'itt'             => p.ITT__c,
                'dateDeces'       => p.DateDeces__c != null ? String.valueOf(p.DateDeces__c) : '',
                'revenuAnnuel'    => p.RevenuAnnuel__c
            };
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException(friendlyError(e));
        }
    }

    /**
     * Vérifie si un CIN est déjà utilisé sur le sinistre courant.
     *
     * Appelé en debounce depuis le LWC (600 ms après la saisie).
     * Retourne true si un autre passager du même sinistre possède déjà ce CIN.
     *
     * Note : un même CIN sur un sinistre DIFFÉRENT est autorisé.
     */
    @AuraEnabled
    public static Boolean isCinAlreadyUsed(String cin, Id claimId, Id excludeParticipantId) {
        try {
            return DMClaimParticipant.isCinDuplicateInClaim(cin, claimId, ROLE_ASSURE, excludeParticipantId);
        } catch (Exception e) {
            throw new AuraHandledException(friendlyError(e));
        }
    }

    /**
     * Crée un nouveau passager assuré.
     * Appelé depuis le LWC en mode création.
     * Retourne { success, message, participantId }.
     */
    @AuraEnabled
    public static Map<String, Object> createPassager(
            Map<String, Object> formData,
            Id claimId) {

        Map<String, Object> response = new Map<String, Object>();

        if (claimId == null) {
            response.put('success', false);
            response.put('message', 'L\'identifiant du sinistre est requis.');
            return response;
        }

        try {
            Id resolvedAccountId = EMClaimParticipant.resolveAccount(
                formData, null, claimId, ROLE_ASSURE, null
            );

            ClaimParticipant__c saved = EMClaimParticipant.createParticipant(
                formData, claimId, resolvedAccountId, ROLE_ASSURE
            );

            response.put('success',       true);
            response.put('participantId', saved.Id);
            response.put('message',       'Passager assuré ajouté avec succès.');
            return response;

        } catch (AuraHandledException ae) {
            response.put('success', false);
            response.put('message', ae.getMessage());
            return response;
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', friendlyError(e));
            return response;
        }
    }

    /**
     * Modifie un passager assuré existant.
     * Appelé depuis le LWC en mode édition.
     * Retourne { success, message, participantId }.
     */
    @AuraEnabled
    public static Map<String, Object> updatePassager(
            Map<String, Object> formData,
            Id participantId,
            Id accountId) {

        Map<String, Object> response = new Map<String, Object>();

        if (participantId == null) {
            response.put('success', false);
            response.put('message', 'L\'identifiant du participant est requis.');
            return response;
        }

        try {
            ClaimParticipant__c current = DMClaimParticipant.getDetailById(participantId);
            Id claimId = current != null ? current.Claim__c : null;

            Id resolvedAccountId = EMClaimParticipant.resolveAccount(
                formData, accountId, claimId, ROLE_ASSURE, participantId
            );

            ClaimParticipant__c saved = EMClaimParticipant.updateParticipant(
                formData, participantId, resolvedAccountId
            );

            response.put('success',       true);
            response.put('participantId', saved.Id);
            response.put('message',       'Passager assuré modifié avec succès.');
            return response;

        } catch (AuraHandledException ae) {
            response.put('success', false);
            response.put('message', ae.getMessage());
            return response;
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', friendlyError(e));
            return response;
        }
    }

    /**
     * Supprime un passager assuré.
     * Retourne { success, message }.
     */
    @AuraEnabled
    public static Map<String, Object> deletePassager(Id participantId) {
        Map<String, Object> response = new Map<String, Object>();
        if (participantId == null) {
            response.put('success', false);
            response.put('message', 'L\'identifiant du participant est requis.');
            return response;
        }
        try {
            EMClaimParticipant.deleteParticipant(participantId);
            response.put('success', true);
            response.put('message', 'Passager assuré supprimé avec succès.');
            return response;
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', friendlyError(e));
            return response;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getPicklistValues(
            String objectApiName, List<String> fields) {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
            if (objType == null) throw new AuraHandledException('Objet introuvable : ' + objectApiName);

            Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
            for (String fieldName : fields) {
                List<Map<String, String>> options = new List<Map<String, String>>();
                if (!fieldMap.containsKey(fieldName)) { result.put(fieldName, options); continue; }

                Schema.DescribeFieldResult fd = fieldMap.get(fieldName).getDescribe();
                if (fd.getType() == Schema.DisplayType.Picklist) {
                    for (Schema.PicklistEntry entry : fd.getPicklistValues()) {
                        if (entry.isActive()) {
                            options.add(new Map<String, String>{
                                'label' => entry.getLabel(),
                                'value' => entry.getValue()
                            });
                        }
                    }
                }
                result.put(fieldName, options);
            }
            return result;
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException(friendlyError(e));
        }
    }

    /**
     * @deprecated Conservé pour rétro-compatibilité uniquement.
     * Utiliser createPassager() ou updatePassager() à la place.
     */
    @AuraEnabled
    public static Map<String, Object> upsertPassager(
            Map<String, Object> formData,
            Id claimId,
            Boolean isUpdateMode,
            Id accountId) {

        if (isUpdateMode == true) {
            Id participantId = (Id) formData.get('participantId');
            return updatePassager(formData, participantId, accountId);
        } else {
            return createPassager(formData, claimId);
        }
    }
}