public with sharing class ZoomCreateMeetingAction {

    // ─────────────────────────────────────────────────────────────────────────
    // TEST INJECTABLE CONFIG
    // ─────────────────────────────────────────────────────────────────────────

    @TestVisible
    private static ZoomConfig__mdt testConfig;

    // ─────────────────────────────────────────────────────────────────────────
    // INPUT CLASS
    // ─────────────────────────────────────────────────────────────────────────

    public class ActionRequest {
        @InvocableVariable(label='Meeting Topic' required=true)
        public String topic;

        @InvocableVariable(label='Meeting Duration' required=false)
        public Integer duration;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // OUTPUT CLASS
    // ─────────────────────────────────────────────────────────────────────────

    public class ActionResult {
        @InvocableVariable(label='Zoom Join URL')
        public String joinUrl;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // INVOCABLE METHOD
    // ─────────────────────────────────────────────────────────────────────────

    @InvocableMethod(
        label='Create Zoom Meeting'
        description='Creates a Zoom meeting and returns the Zoom join URL.'
        callout=true
    )
    public static List<ActionResult> createMeeting(List<ActionRequest> requests) {
        List<ActionResult> results = new List<ActionResult>();

        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Http http = new Http();
        String accessToken;

        // Token fetched once for the entire transaction.
        // Zoom_API Named Credential must be type "No Authentication"
        // so the Bearer header below is injected manually without conflict.
        try {
            accessToken = getAccessToken();
        } catch (Exception ex) {
            for (ActionRequest req : requests) {
                ActionResult errorResult = new ActionResult();
                errorResult.success      = false;
                errorResult.errorMessage = 'Failed to obtain Zoom access token: ' + ex.getMessage(); // FIX 3
                results.add(errorResult);
            }
            return results;
        }

        for (ActionRequest req : requests) {
            ActionResult result = new ActionResult();
            result.success = false;

            try {
                validateRequest(req);

                Integer meetingDuration = req.duration != null && req.duration > 0
                    ? req.duration
                    : 30;

                HttpRequest zoomRequest = new HttpRequest();
                zoomRequest.setEndpoint('callout:Zoom_API/v2/users/me/meetings');
                zoomRequest.setMethod('POST');
                // FIX 1: Bearer injected manually — requires Zoom_API NC to be "No Authentication"
                zoomRequest.setHeader('Authorization', 'Bearer ' + accessToken);
                zoomRequest.setHeader('Content-Type', 'application/json');
                zoomRequest.setTimeout(120000);
                zoomRequest.setBody(JSON.serialize(buildZoomPayload(req.topic, meetingDuration)));

                HttpResponse zoomResponse = http.send(zoomRequest);

                if (zoomResponse.getStatusCode() != 201) {
                    result.errorMessage = 'Zoom API error ' + zoomResponse.getStatusCode() + ': ' + zoomResponse.getBody();
                    results.add(result);
                    continue;
                }

                Map<String, Object> responseBody =
                    (Map<String, Object>) JSON.deserializeUntyped(zoomResponse.getBody());

                String joinUrl = (String) responseBody.get('join_url');

                if (String.isBlank(joinUrl)) {
                    result.errorMessage = 'Zoom meeting was created, but no join_url was returned.';
                    results.add(result);
                    continue;
                }

                result.joinUrl      = joinUrl;
                result.success      = true;
                result.errorMessage = null;
                results.add(result);

            } catch (Exception ex) {
                result.success      = false;
                result.errorMessage = ex.getMessage();
                results.add(result);
            }
        }

        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    private static String getAccessToken() {
        ZoomConfig__mdt cfg = testConfig != null ? testConfig : [
            SELECT AccountId__c, ClientId__c, ClientSecret__c
            FROM   ZoomConfig__mdt
            WHERE  DeveloperName = 'Default'
            LIMIT  1
        ];

        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            'callout:Zoom_OAuth/oauth/token'
            + '?grant_type=account_credentials'
            + '&account_id=' + cfg.AccountId__c
        );
        req.setMethod('POST');
        req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(
            Blob.valueOf(cfg.ClientId__c + ':' + cfg.ClientSecret__c)
        ));
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('Token error: ' + res.getStatusCode() + ' ' + res.getBody());
        }

        return (String)((Map<String, Object>) JSON.deserializeUntyped(res.getBody())).get('access_token');
    }

    private static void validateRequest(ActionRequest req) {
        if (req == null) {
            throw new IllegalArgumentException('Request cannot be null.');
        }
        if (String.isBlank(req.topic)) {
            throw new IllegalArgumentException('Meeting Topic is required.');
        }
    }

    private static Map<String, Object> buildZoomPayload(String topic, Integer duration) {
        return new Map<String, Object>{
            'topic'    => topic,
            'type'     => 3,
            'duration' => duration,
            'settings' => new Map<String, Object>{
                'host_video'        => true,
                'participant_video' => true,
                'join_before_host'  => false,
                'waiting_room'      => true,
                'auto_recording'    => 'none'
            }
        };
    }
}