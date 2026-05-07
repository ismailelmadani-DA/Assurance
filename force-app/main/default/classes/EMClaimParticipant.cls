public with sharing class EMClaimParticipant {

    // ══════════════════════════════════════════════════════════════════════
    // ACCOUNTS
    // ══════════════════════════════════════════════════════════════════════

    public static Id resolveAccount(Map<String, Object> formData, Id existingAccountId) {
        return resolveAccount(formData, existingAccountId, null, null, null);
    }

    public static Id resolveAccount(Map<String, Object> formData, Id existingAccountId,
                                    Id claimId, String role, Id excludeParticipantId) {
        String cni      = (String) formData.get('cni');
        String email    = (String) formData.get('email');
        String phone    = (String) formData.get('phone');
        String fullName = (String) formData.get('participantName');
        String civility = (String) formData.get('civility');
        String address  = (String) formData.get('address');
        String city     = (String) formData.get('city');
        String country  = (String) formData.get('country');
        String sexe     = (String) formData.get('sexe');
        String marital  = (String) formData.get('maritalStatus');
        String birthStr = (String) formData.get('birthDate');

        // Blocage CIN dupliqué sur le MÊME sinistre uniquement
        if (DM005_ClaimParticipant.isCinDuplicateInClaim(cni, claimId, role, excludeParticipantId)) {
            throw new AuraHandledException(
                'CIN_DUPLICATE:Un passager avec le CIN « ' + cni + ' » existe déjà sur ce sinistre.'
            );
        }

        Account acc;

        if (existingAccountId != null) {
            acc = new Account(Id = existingAccountId);
        } else {
            Account found = DM005_ClaimParticipant.findAccountByEmailOrName(email, fullName);
            acc = found != null ? found : new Account();
        }

        acc.Name = fullName;
        if (String.isNotBlank(cni))      acc.CIN__c             = cni;
        if (String.isNotBlank(email))    acc.Email__c           = email;
        if (String.isNotBlank(phone))    acc.Phone              = phone;
        if (String.isNotBlank(civility)) acc.Civility__c        = civility;
        if (String.isNotBlank(address))  acc.Adresse__c         = address;
        if (String.isNotBlank(city))     acc.Ville__c           = city;
        if (String.isNotBlank(country))  acc.Pays__c            = country;
        if (String.isNotBlank(sexe))     acc.Sexe__c            = sexe;
        if (String.isNotBlank(marital))  acc.MaritalStatus__c   = marital;
        if (String.isNotBlank(birthStr)) acc.DateDeNaissance__c = Date.valueOf(birthStr);

        if (acc.Id != null) {
            update acc;
        } else {
            Id passagerRtId = DA_Utility.getRecordTypeId('Account', 'Passager');
            if (passagerRtId != null) {
                acc.RecordTypeId = passagerRtId;
            }
            insert acc;
        }
        return acc.Id;
    }

    // ══════════════════════════════════════════════════════════════════════
    // PARTICIPANTS
    // ══════════════════════════════════════════════════════════════════════

    public static ClaimParticipant__c createParticipant(
            Map<String, Object> formData, Id claimId, Id accountId, String role) {

        ClaimParticipant__c p   = buildParticipant(formData, null);
        p.Claim__c              = claimId;
        p.ParticipantAccount__c = accountId;
        p.Roles__c              = role;

        Id claimVehicleId = DM005_ClaimParticipant.getClaimVehicleId(claimId);
        if (claimVehicleId != null) {
            p.Vehicule__c = claimVehicleId;
        }

        insert p;
        return p;
    }

    public static ClaimParticipant__c updateParticipant(
            Map<String, Object> formData, Id participantId, Id accountId) {
        ClaimParticipant__c p   = buildParticipant(formData, participantId);
        p.ParticipantAccount__c = accountId;
        update p;
        return p;
    }

    public static void deleteParticipant(Id participantId) {
        delete new ClaimParticipant__c(Id = participantId);
    }

    // ══════════════════════════════════════════════════════════════════════
    // HELPER PRIVÉ
    // ══════════════════════════════════════════════════════════════════════

    private static ClaimParticipant__c buildParticipant(Map<String, Object> formData, Id participantId) {
        String participantName = (String) formData.get('participantName');
        if (String.isBlank(participantName)) {
            throw new AuraHandledException('Le nom du participant est obligatoire.');
        }

        ClaimParticipant__c p = participantId != null
            ? new ClaimParticipant__c(Id = participantId)
            : new ClaimParticipant__c();

        p.Name             = participantName;
        p.StateOfPerson__c = (String) formData.get('stateOfPerson');
        p.isDriver__c      = formData.get('isDriver') == true;

        if (formData.get('maritalStatus') != null) p.MaritalStatus__c = (String) formData.get('maritalStatus');
        if (formData.get('sexe')          != null) p.Sexe__c          = (String) formData.get('sexe');
        if (formData.get('address')       != null) p.Adresse__c       = (String) formData.get('address');
        if (formData.get('city')          != null) p.Ville__c         = (String) formData.get('city');
        if (formData.get('country')       != null) p.Pays__c          = (String) formData.get('country');

        if (formData.get('ipp')          != null) p.IPP__c          = Decimal.valueOf(String.valueOf(formData.get('ipp')));
        if (formData.get('itt')          != null) p.ITT__c          = Decimal.valueOf(String.valueOf(formData.get('itt')));
        if (formData.get('revenuAnnuel') != null) p.RevenuAnnuel__c = Decimal.valueOf(String.valueOf(formData.get('revenuAnnuel')));

        String birthDate = (String) formData.get('birthDate');
        String dateDeces = (String) formData.get('dateDeces');
        if (String.isNotBlank(birthDate)) p.BirthDay__c  = Date.valueOf(birthDate);
        if (String.isNotBlank(dateDeces)) p.DateDeces__c = Date.valueOf(dateDeces);

        return p;
    }
}