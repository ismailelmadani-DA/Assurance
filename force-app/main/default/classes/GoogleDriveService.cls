public class GoogleDriveService {

    @AuraEnabled
    public static String uploadFileToDrive(Id contentVersionId) {
        // 1. Récupérer le fichier depuis Salesforce
        ContentVersion cv = [SELECT Title, VersionData, FileExtension, FileType 
                             FROM ContentVersion 
                             WHERE Id = :contentVersionId LIMIT 1];

        // 2. Déterminer le Content-Type (MIME Type)
        String contentType = 'application/octet-stream'; // Par défaut
        if (cv.FileType == 'PDF') contentType = 'application/pdf';
        else if (cv.FileType == 'JPG' || cv.FileType == 'JPEG') contentType = 'image/jpeg';
        else if (cv.FileType == 'PNG') contentType = 'image/png';

        // 3. Préparer la requête
        HttpRequest req = new HttpRequest();
        
        // Utilisation du Named Credential + le chemin d'upload
        // Note : On ajoute /upload devant le chemin standard
        req.setEndpoint('callout:Google_Drive_API/upload/drive/v3/files?uploadType=media');
        req.setMethod('POST');
        
        req.setHeader('Content-Type', contentType);
        req.setBodyAsBlob(cv.VersionData);
        req.setTimeout(60000);

        // 4. Envoyer la requête
        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String googleFileId = (String) responseBody.get('id');
            System.debug('Succès ! ID Google Drive : ' + googleFileId);
            return googleFileId;
        } else {
            System.debug('Erreur Google : ' + res.getBody());
            throw new AuraHandledException('Erreur Google Drive : ' + res.getStatus());
        }
    }
}