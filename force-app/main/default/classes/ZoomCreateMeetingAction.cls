/**
 * Creates a unique Zoom meeting per consult and returns the join URL.
 *
 * The meeting is created under a real firm user, never under "me". Using "me" makes the
 * integration service account the host, which is why nobody at the firm could start the
 * meeting during the Sept 8 test.
 *
 * Host resolution order:
 *   1. hostUserId passed in by the flow
 *   2. ZoomConfig__mdt.DefaultUserId__c
 * If neither resolves to a Zoom user, the action fails and says so. It never falls back
 * to "me" and never returns a link to a meeting nobody can start.
 *
 * Failures are written to Zoom_Integration_Error__c rather than swallowed in a debug statement.
 */
public with sharing class ZoomCreateMeetingAction {

    private static final String  CLASS_NAME       = 'ZoomCreateMeetingAction';
    private static final Integer DEFAULT_DURATION = 30;
    private static final Integer TIMEOUT_MS       = 120000;

    // Join experience. join_before_host and waiting_room are mutually exclusive in Zoom,
    // so exactly one of these may be true.
    private static final Boolean JOIN_BEFORE_HOST = true;
    private static final Boolean WAITING_ROOM     = false;
    private static final Integer JBH_TIME         = 0;

    @TestVisible private static ZoomConfig__mdt testConfig;
    @TestVisible private static User            testHostUser;
    @TestVisible private static String          testAlternativeHosts;

    // ─────────────────────────────────────────────────────────────────────────
    // INVOCABLE CONTRACT
    // ─────────────────────────────────────────────────────────────────────────

    public class ActionRequest {
        @InvocableVariable(label='Meeting Topic' required=true)
        public String topic;

        @InvocableVariable(label='Meeting Duration' required=false)
        public Integer duration;

        @InvocableVariable(
            label='Host User Id'
            description='Salesforce User Id that should host the meeting. Blank uses the configured default host.'
            required=false)
        public String hostUserId;

        @InvocableVariable(
            label='Host Pool Group Id'
            description='Queue or public group whose members can start this meeting. Members become Zoom alternative hosts. They are not invited and are not notified.'
            required=false)
        public String hostPoolGroupId;
    }

    public class ActionResult {
        @InvocableVariable(label='Zoom Join URL')
        public String joinUrl;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;

        @InvocableVariable(label='Zoom Host Id')
        public String hostId;

        @InvocableVariable(label='Zoom Host Email')
        public String hostEmail;
    }

    @InvocableMethod(
        label='Create Zoom Meeting'
        description='Creates a Zoom meeting hosted by a real firm user and returns the join URL.'
        callout=true
    )
    public static List<ActionResult> createMeeting(List<ActionRequest> requests) {
        List<ActionResult> results = new List<ActionResult>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        ZoomConfig__mdt cfg;
        String accessToken;

        try {
            cfg         = loadConfig();
            accessToken = getAccessToken(cfg);
        } catch (Exception ex) {
            ZoomIntegrationErrorLogger.log(CLASS_NAME, 'createMeeting', null, null, ex);
            for (Integer i = 0; i < requests.size(); i++) {
                results.add(failure('Could not connect to Zoom: ' + ex.getMessage()));
            }
            return results;
        }

        Http http = new Http();

        for (ActionRequest req : requests) {
            try {
                validateRequest(req);

                User hostUser = findHostUser(req.hostUserId, cfg);
                String zoomUserId = resolveZoomUserId(hostUser, cfg, accessToken);
                if (String.isBlank(zoomUserId)) {
                    results.add(failure(
                        'No Zoom host could be resolved for this consult, so no meeting was created.'));
                    continue;
                }

                // Whoever is assigned the consult needs to be able to start the meeting,
                // and we do not know who that is when the room is created. Making every
                // pool member an alternative host covers all of them.
                String alternativeHosts = resolveAlternativeHosts(req.hostPoolGroupId, hostUser);

                Integer meetingDuration =
                    (req.duration != null && req.duration > 0) ? req.duration : DEFAULT_DURATION;

                HttpRequest zoomRequest = new HttpRequest();
                zoomRequest.setEndpoint('callout:Zoom_API/v2/users/'
                    + EncodingUtil.urlEncode(zoomUserId, 'UTF-8') + '/meetings');
                zoomRequest.setMethod('POST');
                // Zoom_API named credential must have "Generate Authorization Header" OFF,
                // or it overwrites this Bearer token with its own Basic header.
                zoomRequest.setHeader('Authorization', 'Bearer ' + accessToken);
                zoomRequest.setHeader('Content-Type', 'application/json');
                zoomRequest.setTimeout(TIMEOUT_MS);
                zoomRequest.setBody(JSON.serialize(
                    buildZoomPayload(req.topic, meetingDuration, alternativeHosts)));

                HttpResponse zoomResponse = http.send(zoomRequest);

                if (zoomResponse.getStatusCode() != 201) {
                    String msg = 'Zoom API error ' + zoomResponse.getStatusCode()
                        + ' creating a meeting for host ' + zoomUserId
                        + ': ' + zoomResponse.getBody();
                    ZoomIntegrationErrorLogger.log(CLASS_NAME, 'createMeeting',
                        zoomUserId, null, new ZoomCalloutException(msg));
                    results.add(failure(msg));
                    continue;
                }

                Map<String, Object> body =
                    (Map<String, Object>) JSON.deserializeUntyped(zoomResponse.getBody());

                String joinUrl   = (String) body.get('join_url');
                String meetingId = String.valueOf(body.get('id'));

                if (String.isBlank(joinUrl)) {
                    String msg = 'Zoom meeting was created, but no join_url was returned.';
                    ZoomIntegrationErrorLogger.log(CLASS_NAME, 'createMeeting',
                        zoomUserId, meetingId, new ZoomCalloutException(msg));
                    results.add(failure(msg));
                    continue;
                }

                ActionResult ok = new ActionResult();
                ok.joinUrl      = joinUrl;
                ok.hostId       = (String) body.get('host_id');
                ok.hostEmail    = (String) body.get('host_email');
                ok.success      = true;
                ok.errorMessage = null;
                results.add(ok);

            } catch (Exception ex) {
                ZoomIntegrationErrorLogger.log(CLASS_NAME, 'createMeeting', null, null, ex);
                results.add(failure(ex.getMessage()));
            }
        }

        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HOST RESOLUTION — never returns "me"
    // ─────────────────────────────────────────────────────────────────────────

    private static String resolveZoomUserId(User hostUser,
                                            ZoomConfig__mdt cfg,
                                            String accessToken) {
        if (hostUser == null) {
            ZoomIntegrationErrorLogger.log(CLASS_NAME, 'resolveZoomUserId', null, null,
                new ZoomCalloutException('No host user could be resolved. Configured default: '
                    + cfg.DefaultUserId__c));
            return null;
        }

        if (String.isNotBlank(hostUser.Zoom_User_Id__c)) {
            return hostUser.Zoom_User_Id__c;
        }

        // Fallback: look the user up in Zoom by email. Covers users whose Zoom Id field
        // was never populated, which is common for recent hires.
        if (String.isBlank(hostUser.Email)) {
            return null;
        }

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Zoom_API/v2/users/'
                + EncodingUtil.urlEncode(hostUser.Email, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setTimeout(TIMEOUT_MS);

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                ZoomIntegrationErrorLogger.log(CLASS_NAME, 'resolveZoomUserId', null, null,
                    new ZoomCalloutException('Zoom user lookup failed for ' + hostUser.Email
                        + ': HTTP ' + res.getStatusCode() + ' ' + res.getBody()));
                return null;
            }
            Map<String, Object> body =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) body.get('id');

        } catch (Exception ex) {
            ZoomIntegrationErrorLogger.log(CLASS_NAME, 'resolveZoomUserId', null, null, ex);
            return null;
        }
    }

    private static User findHostUser(String requestedUserId, ZoomConfig__mdt cfg) {
        if (testHostUser != null) {
            return testHostUser;
        }

        List<String> candidates = new List<String>();
        if (String.isNotBlank(requestedUserId)) candidates.add(requestedUserId);
        if (String.isNotBlank(cfg.DefaultUserId__c)) candidates.add(cfg.DefaultUserId__c);

        for (String candidate : candidates) {
            // A group or queue Id cannot host a Zoom meeting, so skip anything that is not a User.
            if (!candidate.startsWith('005')) continue;

            List<User> found = [
                SELECT Id, Name, Email, Zoom_User_Id__c
                FROM   User WHERE Id = :candidate AND IsActive = true LIMIT 1
            ];
            if (!found.isEmpty()) return found[0];
        }
        return null;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PAYLOAD
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Semicolon delimited emails of everyone in the pool other than the host. Zoom treats
     * these as alternative hosts: they can start and run the meeting, but they are not
     * invitees and receive no notification.
     */
    @TestVisible
    private static String resolveAlternativeHosts(String groupId, User hostUser) {
        if (String.isBlank(groupId) || !groupId.startsWith('00G')) {
            return null;
        }
        if (testAlternativeHosts != null) {
            return testAlternativeHosts;
        }

        Set<Id> memberIds = new Set<Id>();
        for (GroupMember gm : [
            SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :groupId
        ]) {
            if (String.valueOf(gm.UserOrGroupId).startsWith('005')) {
                memberIds.add(gm.UserOrGroupId);
            }
        }
        if (memberIds.isEmpty()) {
            return null;
        }

        List<String> emails = new List<String>();
        for (User u : [
            SELECT Id, Email FROM User WHERE Id IN :memberIds AND IsActive = true
        ]) {
            Boolean isHost = (hostUser != null && u.Id == hostUser.Id);
            if (!isHost && String.isNotBlank(u.Email)) {
                emails.add(u.Email);
            }
        }
        return emails.isEmpty() ? null : String.join(emails, ';');
    }

    @TestVisible
    private static Map<String, Object> buildZoomPayload(String topic,
                                                        Integer duration,
                                                        String alternativeHosts) {
        Map<String, Object> settings = new Map<String, Object>{
            'host_video'        => true,
            'participant_video' => true,
            'join_before_host'  => JOIN_BEFORE_HOST,
            'waiting_room'      => WAITING_ROOM,
            'auto_recording'    => 'none'
        };
        if (JOIN_BEFORE_HOST) {
            settings.put('jbh_time', JBH_TIME);
        }
        if (String.isNotBlank(alternativeHosts)) {
            settings.put('alternative_hosts', alternativeHosts);
            // Nobody in the pool gets emailed about meetings they were not assigned.
            settings.put('alternative_hosts_email_notification', false);
        }

        // type 3 = recurring with no fixed time. Each call still returns its own meeting id,
        // so every consult gets a unique room. Do not change without re-checking that.
        return new Map<String, Object>{
            'topic'    => topic,
            'type'     => 3,
            'duration' => duration,
            'settings' => settings
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PLUMBING
    // ─────────────────────────────────────────────────────────────────────────

    private static ZoomConfig__mdt loadConfig() {
        if (testConfig != null) {
            return testConfig;
        }
        List<ZoomConfig__mdt> cfgs = [
            SELECT AccountId__c, ClientId__c, ClientSecret__c, DefaultUserId__c
            FROM   ZoomConfig__mdt WHERE DeveloperName = 'Default' LIMIT 1
        ];
        if (cfgs.isEmpty()) {
            throw new ZoomCalloutException(
                'ZoomConfig__mdt record "Default" is missing. Zoom integration cannot run.');
        }
        return cfgs[0];
    }

    private static String getAccessToken(ZoomConfig__mdt cfg) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Zoom_OAuth/oauth/token'
            + '?grant_type=account_credentials'
            + '&account_id=' + cfg.AccountId__c);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(
            Blob.valueOf(cfg.ClientId__c + ':' + cfg.ClientSecret__c)));
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setTimeout(TIMEOUT_MS);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new ZoomCalloutException(
                'Token error: ' + res.getStatusCode() + ' ' + res.getBody());
        }
        return (String)((Map<String, Object>)
            JSON.deserializeUntyped(res.getBody())).get('access_token');
    }

    private static void validateRequest(ActionRequest req) {
        if (req == null) {
            throw new IllegalArgumentException('Request cannot be null.');
        }
        if (String.isBlank(req.topic)) {
            throw new IllegalArgumentException('Meeting Topic is required.');
        }
    }

    private static ActionResult failure(String message) {
        ActionResult r = new ActionResult();
        r.success      = false;
        r.errorMessage = message;
        return r;
    }

    public class ZoomCalloutException extends Exception {}
}