public with sharing class FlagSinistreNotifier {

    public static void sendForRequest(RequestApproval__c ra) {
        if (ra.NextApprover__c == null || ra.Sinistre__c == null) return;

        List<CustomNotificationType> notifTypes = [
            SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Flag_Sinistre_Notification' LIMIT 1
        ];
        if (notifTypes.isEmpty()) return;

        Claim__c claim = DM006_Claim.getById('Id, Name, Flags__c', ra.Sinistre__c);
        if (claim == null) return;

        Set<String> currentFlags = new Set<String>();
        if (String.isNotBlank(claim.Flags__c)) {
            for (String f : claim.Flags__c.split(';')) {
                currentFlags.add(f.trim());
            }
        }

        Boolean isDeselect = currentFlags.contains(ra.Flag__c);

        try {
            Messaging.CustomNotification notif = new Messaging.CustomNotification();
            notif.setNotificationTypeId(notifTypes[0].Id);

            if (isDeselect) {
                notif.setTitle('Sinistre ' + claim.Name + ' - Supprimer le flag "' + ra.Flag__c + '"');
                notif.setBody('Vous avez reçu une demande de validation pour retirer le flag "' + ra.Flag__c + '" du sinistre ' + claim.Name);
            } else {
                notif.setTitle('Sinistre ' + claim.Name + ' - Flagger comme "' + ra.Flag__c + '"');
                notif.setBody('Vous avez reçu une demande de validation pour flagger le sinistre ' + claim.Name + ' comme "' + ra.Flag__c + '"');
            }

            notif.setTargetId(ra.Id);
            notif.send(new Set<String>{ ra.NextApprover__c });
        } catch (Exception e) {
            System.debug('Erreur envoi notification: ' + e.getMessage());
        }
    }

    public static void sendDecisionNotification(RequestApproval__c ra) {
        if (ra.Submitter__c == null || ra.Sinistre__c == null) return;

        List<CustomNotificationType> notifTypes = [
            SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Flag_Sinistre_Notification' LIMIT 1
        ];
        if (notifTypes.isEmpty()) return;

        Claim__c claim = DM006_Claim.getById('Id, Name', ra.Sinistre__c);
        if (claim == null) return;

        Boolean isApproved = ra.Status__c == 'Approuvée';
        String decision = isApproved ? 'approuvée' : 'rejetée';

        try {
            Messaging.CustomNotification notif = new Messaging.CustomNotification();
            notif.setNotificationTypeId(notifTypes[0].Id);

            notif.setTitle('Sinistre ' + claim.Name + ' - Demande ' + decision);
            notif.setBody('Votre demande concernant le flag "' + ra.Flag__c + '" sur le sinistre ' + claim.Name + ' a été ' + decision + '.');

            notif.setTargetId(ra.Sinistre__c);
            notif.send(new Set<String>{ ra.Submitter__c });
        } catch (Exception e) {
            System.debug('Erreur envoi notification décision: ' + e.getMessage());
        }
    }
}