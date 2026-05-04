public with sharing class DA_FlagSinistreController {

    private static final Set<String> RESTRICTED_FLAGS = new Set<String>{'Frauduleux', 'Douteux'};
    private static final Set<String> ALL_FLAGS = new Set<String>{'Sensible', 'Majeur', 'Grave', 'Frauduleux', 'Douteux'};

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getClaimFlagData(Id claimId) {
        if (claimId == null) {
            throw new AuraHandledException('L\'identifiant du sinistre est requis.');
        }
        try {
            Map<String, Object> result = new Map<String, Object>();

            Claim__c claim = DM006_Claim.getById('Id, Name, Flags__c', claimId);
            List<String> currentFlags = new List<String>();
            if (claim != null && String.isNotBlank(claim.Flags__c)) {
                for (String f : claim.Flags__c.split(';')) {
                    currentFlags.add(f.trim());
                }
            }
            result.put('currentFlags', currentFlags);
            result.put('claimName', claim != null ? claim.Name : '');

            List<RequestApproval__c> pending = DM_RequestApproval.getPendingByClaimId(claimId);
            List<Map<String, String>> pendingList = new List<Map<String, String>>();
            for (RequestApproval__c req : pending) {
                pendingList.add(new Map<String, String>{
                    'id' => req.Id,
                    'flag' => req.Flag__c,
                    'status' => req.Status__c
                });
            }
            result.put('pendingRequests', pendingList);

            result.put('isPrivileged', false);

            return result;
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lors du chargement des flags : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> saveFlags(Id claimId, List<String> selectedFlags, String commentaire) {
        Map<String, Object> response = new Map<String, Object>();

        if (claimId == null) {
            response.put('success', false);
            response.put('message', 'L\'identifiant du sinistre est requis.');
            return response;
        }
        if (String.isBlank(commentaire)) {
            response.put('success', false);
            response.put('message', 'Le commentaire est obligatoire.');
            return response;
        }

        if (selectedFlags.contains('Frauduleux') && selectedFlags.contains('Douteux')) {
            response.put('success', false);
            response.put('message', 'Les flags "Frauduleux" et "Douteux" ne peuvent pas être sélectionnés en même temps.');
            return response;
        }

        try {
            User currentUser = [SELECT Id, ManagerId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

            Claim__c claim = DM006_Claim.getById('Id, Name, Flags__c', claimId);
            if (claim == null) {
                response.put('success', false);
                response.put('message', 'Sinistre introuvable.');
                return response;
            }

            Set<String> existingFlags = new Set<String>();
            if (String.isNotBlank(claim.Flags__c)) {
                for (String f : claim.Flags__c.split(';')) {
                    existingFlags.add(f.trim());
                }
            }

            Set<String> newFlags = new Set<String>(selectedFlags);
            List<String> flagsNeedingApproval = new List<String>();
            List<String> flagsToRemoveNeedingApproval = new List<String>();

            for (String flag : ALL_FLAGS) {
                Boolean wasSelected = existingFlags.contains(flag);
                Boolean isSelected = newFlags.contains(flag);

                if (RESTRICTED_FLAGS.contains(flag) ) {
                    if (isSelected && !wasSelected) {
                        flagsNeedingApproval.add(flag);
                    } else if (!isSelected && wasSelected) {
                        flagsToRemoveNeedingApproval.add(flag);
                    }
                }
            }

            // Cannot deselect one and select the other at the same time
            if (!flagsNeedingApproval.isEmpty() && !flagsToRemoveNeedingApproval.isEmpty()) {
                response.put('success', false);
                response.put('message', 'Vous ne pouvez pas désélectionner et sélectionner un flag restreint en même temps. Attendez la validation.');
                return response;
            }

            if (!flagsNeedingApproval.isEmpty() || !flagsToRemoveNeedingApproval.isEmpty()) {
                if (currentUser.ManagerId == null) {
                    response.put('success', false);
                    response.put('message', 'Aucun supérieur hiérarchique défini. Impossible de créer la demande de validation.');
                    return response;
                }

                cancelExistingPendingRequests(claimId);

                for (String flag : flagsNeedingApproval) {
                    EM_RequestApproval.createRequest(
                        claimId, flag, commentaire, currentUser.Id, currentUser.ManagerId
                    );
                }
                for (String flag : flagsToRemoveNeedingApproval) {
                    EM_RequestApproval.createRequest(
                        claimId, flag, commentaire, currentUser.Id, currentUser.ManagerId
                    );
                }
            }

            // Build final flags: restricted flags keep current state (non-privileged can't directly change)
            Set<String> finalFlags = new Set<String>();
            for (String flag : newFlags) {
                if (RESTRICTED_FLAGS.contains(flag) ) {
                    if (existingFlags.contains(flag)) {
                        finalFlags.add(flag);
                    }
                } else {
                    finalFlags.add(flag);
                }
            }
            for (String flag : existingFlags) {
                if (RESTRICTED_FLAGS.contains(flag)  && !newFlags.contains(flag)) {
                    finalFlags.add(flag);
                }
            }

            claim.Flags__c = finalFlags.isEmpty() ? null : String.join(new List<String>(finalFlags), ';');
            update claim;

            Boolean hasPendingRequests = !flagsNeedingApproval.isEmpty() || !flagsToRemoveNeedingApproval.isEmpty();
            response.put('success', true);
            if (hasPendingRequests) {
                response.put('message', 'Flags mis à jour. Une demande de validation a été envoyée à votre supérieur pour les flags nécessitant approbation.');
            } else {
                response.put('message', 'Flags mis à jour avec succès.');
            }
            return response;

        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Erreur : ' + e.getMessage());
            return response;
        }
    }

    private static void cancelExistingPendingRequests(Id claimId) {
        List<RequestApproval__c> pending = DM_RequestApproval.getPendingByClaimId(claimId);
        for (RequestApproval__c req : pending) {
            req.Status__c = 'Annulée';
        }
        if (!pending.isEmpty()) {
            update pending;
        }
    }

}