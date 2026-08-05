public without sharing class ZoomIntegrationService {
    
    // Credentials from Zoom Server-to-Server OAuth App
    private static final String ZOOM_ACCOUNT_ID    = 'Af5TohNeQKilODcnyFCOyQ';
    private static final String ZOOM_CLIENT_ID     = 'mJZl6WEeQ8yN50AKqRub9Q';
    private static final String ZOOM_CLIENT_SECRET = 'mOUv5Egq62j6Gpy9IWb3zVjOHetsO371';

    /**
     * Retrieves the Access Token from Zoom using Account Credentials
     */
    private static String getAccessToken() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://zoom.us/oauth/token?grant_type=account_credentials&account_id=' + ZOOM_ACCOUNT_ID);
        req.setMethod('POST');
        
        // Encode Client ID and Secret for Basic Authentication
        String authHeader = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(ZOOM_CLIENT_ID + ':' + ZOOM_CLIENT_SECRET));
        req.setHeader('Authorization', authHeader);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) responseMap.get('access_token');
        } else {
            throw new CalloutException('Failed to get Zoom Token. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody());
        }
    }

    /**
     * Creates a scheduled meeting on behalf of the CES and returns the Join URL
     */
    public static String createMeeting(String cesEmail, String topic, DateTime startTime) {
        String token = getAccessToken();
        
        HttpRequest req = new HttpRequest();
        // Endpoint to create a meeting for a specific user via their email
        req.setEndpoint('https://api.zoom.us/v2/users/' + cesEmail + '/meetings');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Content-Type', 'application/json');
        
        // Format the start time to ISO 8601 as required by Zoom API
        String zoomStartTime = startTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        
        // Build the meeting payload
        Map<String, Object> payload = new Map<String, Object>{
            'topic'      => topic,
            'type'       => 2, // 2 = Scheduled Meeting
            'start_time' => zoomStartTime,
            'duration'   => 60, // Duration in minutes
            'timezone'   => 'UTC',
            'settings'   => new Map<String, Object>{
                'host_video'        => true,
                'participant_video' => true,
                'join_before_host'  => false,
                'waiting_room'      => true
            }
        };
        
        req.setBody(JSON.serialize(payload));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 201) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            // Return the unique URL so the client can join
            return (String) responseMap.get('join_url'); 
        } else {
            throw new CalloutException('Failed to create Zoom meeting. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody());
        }
    }
}