public with sharing class GoogleDriveService {
    
    private static final Integer MAX_FILE_SIZE_BYTES = 4194304; 

    /**
     * Méthode générique pour uploader n'importe quel fichier vers Google Drive
     */
    public static String uploadFile(String base64Data, String fileName, String mimeType) {
        Blob fileBlob = EncodingUtil.base64Decode(base64Data);
        
        if (fileBlob.size() > MAX_FILE_SIZE_BYTES) {
            throw new CalloutException('Le fichier dépasse la limite technique de 4 Mo.');
        }
        
        // 1. Upload du flux binaire
        String googleFileId = executeUploadCallout(fileBlob, mimeType);
        
        // 2. Renommage du fichier
        executeRenameCallout(googleFileId, fileName);
        
        return googleFileId;
    }

    private static String executeUploadCallout(Blob fileBlob, String mimeType) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Google_Drive_API/upload/drive/v3/files?uploadType=media'); 
        req.setMethod('POST');
        req.setHeader('Content-Type', mimeType);
        req.setBodyAsBlob(fileBlob);
        req.setTimeout(60000);
        
        HttpResponse res = new Http().send(req);
        
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) responseMap.get('id');
        } else {
            throw new CalloutException('Erreur Google Drive API : ' + res.getBody());
        }
    }
    
    private static void executeRenameCallout(String fileId, String fileName) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Google_Drive_API/drive/v3/files/' + fileId);
        req.setMethod('PATCH');
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{"name": "' + fileName + '"}');
        new Http().send(req);
    }
}