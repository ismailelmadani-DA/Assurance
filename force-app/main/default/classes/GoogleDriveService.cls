public with sharing class GoogleDriveService {
    
    private static final Integer MAX_FILE_SIZE_BYTES = 4194304; 


    public static String uploadFile(String base64Data, String fileName, String mimeType) {
        Blob fileBlob = EncodingUtil.base64Decode(base64Data);
        
        if (fileBlob.size() > MAX_FILE_SIZE_BYTES) {
            throw new CalloutException('Le fichier dépasse la limite technique de 4 Mo.');
        }
        
        String googleFileId = executeUploadCallout(fileBlob, mimeType);
        
        executeRenameCallout(googleFileId, fileName);
        
        return googleFileId;
    }

    public static void makeFilePublic(String fileId) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        
        req.setEndpoint('callout:Google_Drive_API/drive/v3/files/' + fileId + '/permissions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        
        String body = '{"role": "reader", "type": "anyone"}';
        req.setBody(body);
        
        try {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                System.debug('✅ Fichier rendu public avec succès.');
            } else {
                System.debug('❌ Erreur lors du changement de permission : ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('❌ Exception Apex lors des permissions : ' + e.getMessage());
        }
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
        String folderId = '1orFY2CEYfuaXt-P5IoJqAeu-NC9XreHp'; 
        
        HttpRequest req = new HttpRequest();
        
        req.setEndpoint('callout:Google_Drive_API/drive/v3/files/' + fileId + '?addParents=' + folderId + '&removeParents=root');
        
        req.setMethod('PATCH');
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{"name": "' + fileName + '"}');
        
        // 3. J'ai ajouté un petit bloc try/catch pour éviter que ça plante en cas de souci
        try {
            new Http().send(req);
        } catch(Exception e) {
            System.debug('Erreur lors du déplacement : ' + e.getMessage());
        }
    }
}