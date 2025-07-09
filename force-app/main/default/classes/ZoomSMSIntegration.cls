public with sharing class ZoomSMSIntegration implements Schedulable{
    private static final String BASE_URL = 'https://api.zoom.us/v2/';

    public void execute(SchedulableContext ctx) {
        sendZoomDataToSalesforce();
    }

    @future(callout=true)
    public static void sendZoomDataToSalesforce() {
        String clientId = 'OlTvfeKSCuXyENCswlexQ';
        String clientSecret = 'mJQ2SXpsBABlord50hHQVj7l40tLg3n9';
        String accountId = 'Af5TohNeQKiIODcnyFCOyQ';
        String accessToken = ZoomPhoneIntegration.getZoomToken(clientId, clientSecret, accountId);
        Datetime now = Datetime.now(); // Current datetime
        String toDateTime = now.addHours(-24).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''); //current time
        String fromDateTime = now.addHours(-48).addMinutes(-0).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''); // Grab the last 24hrs


        System.debug('accessToken: ' + accessToken);
        if (accessToken == null) {
            System.debug('Failed to obtain access token');
            return;
        }
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + 'phone/sms/sessions?from=' + fromDateTime + '&to=' + toDateTime);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            ZoomSMSWrapper responseList = (ZoomSMSWrapper) JSON.deserialize(res.getBody(), ZoomSMSWrapper.class);
            getSMSSessionMessages(responseList, accessToken);
        } else {
            System.debug('Error fetching SMS messages: ' + res.getBody());
        }
    }

    public static void getSMSSessionMessages(ZoomSMSWrapper responseList, string accessToken) {
        System.debug('responseList: ' + responseList);
        Map<string, List<SMSHistoryWrapper>> sessionIdToMessageMap = new Map<string, List<SMSHistoryWrapper>>();
        if (responseList.sms_sessions != null) {
            System.debug('responseList IN If: ' + responseList);
            for (SMS_Session session : responseList.sms_sessions) {
                System.debug('Session ID: ' + session.session_id);
                
                SMSHistoryWrapper messages = getSMSMessagesBasedOnSession(session.session_id, accessToken); //getSMSMessagesBasedOnSession(sessionId);)
                if(sessionIdToMessageMap.containsKey(session.session_id)) {
                    sessionIdToMessageMap.get(session.session_id).add(messages);
                }
                else{

                    sessionIdToMessageMap.put(session.session_id, new List<SMSHistoryWrapper>());
                    sessionIdToMessageMap.get(session.session_id).add(messages);
                }
            }
        }
        System.debug('sessionIds'+sessionIdToMessageMap.keySet());
        mapSessionAnMessageObjects(sessionIdToMessageMap);
        
    }

    public static SMSHistoryWrapper getSMSMessagesBasedOnSession(String sessionId, string accessToken) {
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + 'phone/sms/sessions/'+sessionId);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        Http http = new Http();
        HttpResponse res = http.send(req);

        SMSHistoryWrapper messageList = (SMSHistoryWrapper) JSON.deserialize(res.getBody(), SMSHistoryWrapper.class);
        // system.debug('message: '+messageList.sms_histories[0].message);
        system.debug('message: '+messageList);
        System.debug('messageList'+messageList);
        return messageList;
    }

    public static void mapSessionAnMessageObjects(Map<string, List<SMSHistoryWrapper>> sessionIdToMessageMap){
        // list<SMS_Session__c> smsSessions = new list<SMS_Session__c>();
        // list<SMS_Message__c> smsMessages = new list<SMS_Message__c>();
        String zoomDisplayName;
        Id zoomMemberPhone;
        Set<String> allPhoneNumbers = new Set<String>(); 
        Set<String> allNames = new Set<String>(); 
        Map<String, Account> phoneToAccountIdMap = new Map<String, Account>();
        Map<String, Lead> phoneToLeadIdMap = new Map<String, Lead>();
        Map<String, User> phoneToUserIdMap = new Map<String, User>();
        Map<String, User> phoneToUserNameMap = new Map<String, User>();

        ///Loop Throuh All Session Ids and collect all phone numbers and all formats of the phone number
        for(String sessionId: sessionIdToMessageMap.keySet()){
            SMS_Session__c newSMSession = new SMS_Session__c();
            newSMSession.Zoom_Session_Id__c = sessionId;
            
            for(SMSHistoryWrapper history: sessionIdToMessageMap.get(sessionId)){
                for(SMSHistory h: history.sms_histories){
                    System.debug('h.sender.phone_number'+ h.sender.phone_number);
                    allPhoneNumbers.addAll(generatePhoneFormats(h.sender.phone_number));
                    for(ToMember toMember: h.to_members){
                        if(toMember.phone_number != null){
                            System.debug('toMember.phone_number'+ toMember.phone_number);
                            allPhoneNumbers.addAll(generatePhoneFormats(toMember.phone_number));
                            if(toMember.display_name != null){
                                allNames.add(toMember.display_name);
                            }
                        }
                    }
                }
            }
            system.debug('allPhoneNumbers'+ allPhoneNumbers);
        }

        ///take all the phone numbers collected and query for matching Accounts
        List<Account> returnedAccount = getRelatedPersonAccountByPhoneNumber(allPhoneNumbers) != null 
            ? getRelatedPersonAccountByPhoneNumber(allPhoneNumbers) 
            : new List<Account>();
            system.debug('returnedAccount'+ returnedAccount);
        for(Account a: returnedAccount){
            phoneToAccountIdMap.put(ZoomSMSIntegration.removePhoneNumberFormat(a.phone), a);
        }
        List<Lead> returnedLead = getRelatedLeadByPhoneNumber(allPhoneNumbers) != null 
            ? getRelatedLeadByPhoneNumber(allPhoneNumbers) 
            : new List<Lead>();
            system.debug('returnedLead'+ returnedLead);
        for(Lead l: returnedLead){
            phoneToLeadIdMap.put(ZoomSMSIntegration.removePhoneNumberFormat(l.phone), l);
        }
        List<User> returnedUser = getRelatedUsersByPhoneNumber(allPhoneNumbers) != null 
            ? getRelatedUsersByPhoneNumber(allPhoneNumbers) 
            : new List<User>();
            system.debug('phoneToUserIdMap'+ phoneToUserIdMap);

        List<User> returnedUserByName = getRelatedUsersByName(allNames) != null 
            ? getRelatedUsersByName(allNames) 
            : new List<User>();
            system.debug('returnedUserByName'+ returnedUserByName);
        for(User u: returnedUserByName){
            phoneToUserNameMap.put(u.name, u);
        }

        ////Create New Sessions///
        List<SMS_Session__c> listSessionsToInsert = new List<SMS_Session__c>();
        for(string sessionId: sessionIdToMessageMap.keySet()){
            SMS_Session__c newSMSession = new SMS_Session__c();
            newSMSession.Zoom_Session_Id__c = sessionId;
            listSessionsToInsert.add(newSMSession);
        }
        insert listSessionsToInsert;

        ///create map of new Sessions
        Map<String, SMS_Session__c> sessionZoomIdToSMSessionMap = new Map<String, SMS_Session__c>();
        for(SMS_Session__c session: listSessionsToInsert){
            sessionZoomIdToSMSessionMap.put(session.Zoom_Session_Id__c, session);
        }


        //build the SMS message, reference the related sessions, and save it
        for(string sessionId: sessionIdToMessageMap.keySet()){
            for(SMSHistoryWrapper session: sessionIdToMessageMap.get(sessionId)){
                String fullMessageDetails = '';
                set<string> fullToMemberSet = new set<string>();
                set<string> fullToMemberNameSet = new set<string>();
                string fullToMembers = '';
                string senderName = '';
                for(SMSHistory message: session.sms_histories){
                    System.debug('message'+message.message);
                    System.debug('message sender.phone_number'+message.sender.phone_number);
                    System.debug('message sender.phone_number'+message.to_members);
                    
                    if(phoneToAccountIdMap.containsKey(message.sender.phone_number)){
                        senderName += phoneToAccountIdMap.get(message.sender.phone_number).Name+', ';
                    }
                    else if(phoneToLeadIdMap.containsKey(message.sender.phone_number)){
                        senderName += phoneToLeadIdMap.get(message.sender.phone_number).Name+', ';
                    }else if(phoneToUserIdMap.containsKey(message.sender.phone_number)){
                        senderName += phoneToUserIdMap.get(message.sender.phone_number).Name+', ';
                    }
                    else if(phoneToUserNameMap.containsKey(message.sender.display_name)){
                        senderName += phoneToUserNameMap.get(message.sender.display_name).Name+', ';
                    }
                    else{
                        senderName += message.sender.phone_number+', ';
                    }
                    system.debug('Session Id: '+ sessionId);
                    system.debug('Session message: '+ message);
                    for(ToMember toMember: message.to_members){
                        if(toMember.phone_number != null){
                            fullToMemberSet.add(toMember.phone_number);
                            if(toMember.display_name != null){
                                fullToMemberNameSet.add(toMember.display_name);
                            }
                        }
                    }

                    for(string toMember: fullToMemberSet){
                        if(toMember != message.sender.phone_number){
                            if(phoneToAccountIdMap.containsKey(toMember)){
                                fullToMembers += phoneToAccountIdMap.get(toMember).Name+', ';
                            }
                            else if(phoneToLeadIdMap.containsKey(toMember)){
                                fullToMembers += phoneToLeadIdMap.get(toMember).Name+', ';
                            }else if(phoneToUserIdMap.containsKey(toMember)){
                                fullToMembers += phoneToUserIdMap.get(toMember).Name+', ';
                            }
                            else{
                                fullToMembers += toMember+', ';
                            }
                        }
                    }
                    for(string toMemberName: fullToMemberNameSet){
                        if(toMemberName != message.sender.display_name){
                            if(phoneToUserNameMap.containsKey(toMemberName)){
                                fullToMembers += phoneToUserNameMap.get(toMemberName).Name+', ';
                            }
                        }
                    }
                    fullMessageDetails += 'Date/Time: '+ message.date_time +'\n' +'Sender: '+senderName +'\n' + 'To: '+ fullToMembers + '\n'+ 'Message: '+message.message+'\n\n';
                    sessionZoomIdToSMSessionMap.get(sessionId).SMS_Session_Text__c = fullMessageDetails;
                    sessionZoomIdToSMSessionMap.get(sessionId).SMS_Session_Date__c = Date.today();
                    senderName = '';
                    fullToMembers = '';
                }
                System.debug('fullMessageDetails: '+fullMessageDetails);
            }
        }
        upsert sessionZoomIdToSMSessionMap.values();


        ///build and save the SMS Session Group
        Set<SMS_Session_Individual__c> newSMSessionIndividuals = new Set<SMS_Session_Individual__c>();
        List<SMS_Session__c> ListSessionsToUpdate = new List<SMS_Session__c>();
        for(String sessionId: sessionIdToMessageMap.keySet()){
            
            SMS_Session__c updateSession = new SMS_Session__c();
            updateSession.Id = sessionZoomIdToSMSessionMap.get(sessionId).Id;

            for(SMSHistoryWrapper history: sessionIdToMessageMap.get(sessionId)){ 
                for(SMSHistory h: history.sms_histories){
                    if(phoneToAccountIdMap.containsKey(h.sender.phone_number)){
                        SMS_Session_Individual__c newSMSessionIndividual = new SMS_Session_Individual__c();
                        newSMSessionIndividual.Zoom_Session_Id__c = sessionId;
                        newSMSessionIndividual.SMS_Session__c = sessionZoomIdToSMSessionMap.get(sessionId).Id;
                        newSMSessionIndividual.Account__c = phoneToAccountIdMap.get(h.sender.phone_number).Id;
                        updateSession.Account__c = phoneToAccountIdMap.get(h.sender.phone_number).Id;
                        newSMSessionIndividual.type__c = 'Account';
                        newSMSessionIndividuals.add(newSMSessionIndividual);
                    }
                    else if(phoneToLeadIdMap.containsKey(h.sender.phone_number)){
                        SMS_Session_Individual__c newSMSessionIndividual = new SMS_Session_Individual__c();
                        newSMSessionIndividual.Zoom_Session_Id__c = sessionId;
                        newSMSessionIndividual.SMS_Session__c = sessionZoomIdToSMSessionMap.get(sessionId).Id;
                        newSMSessionIndividual.Lead__c = phoneToLeadIdMap.get(h.sender.phone_number).Id;
                        updateSession.Prospect__c = phoneToLeadIdMap.get(h.sender.phone_number).Id;
                        newSMSessionIndividual.type__c = 'Lead';
                        newSMSessionIndividuals.add(newSMSessionIndividual);
                    }
                    else if(phoneToUserIdMap.containsKey(h.sender.phone_number)){
                        SMS_Session_Individual__c newSMSessionIndividual = new SMS_Session_Individual__c();
                        newSMSessionIndividual.Zoom_Session_Id__c = sessionId;
                        newSMSessionIndividual.SMS_Session__c = sessionZoomIdToSMSessionMap.get(sessionId).Id;
                        newSMSessionIndividual.JT_User__c = phoneToUserIdMap.get(h.sender.phone_number).Id;
                        updateSession.Johnson_Turner_User__c = phoneToUserIdMap.get(h.sender.phone_number).Id;
                        newSMSessionIndividual.type__c = 'User';
                        newSMSessionIndividuals.add(newSMSessionIndividual);
                    }
                    else if(phoneToUserNameMap.containsKey(h.sender.display_name)){
                        SMS_Session_Individual__c newSMSessionIndividual = new SMS_Session_Individual__c();
                        newSMSessionIndividual.Zoom_Session_Id__c = sessionId;
                        newSMSessionIndividual.SMS_Session__c = sessionZoomIdToSMSessionMap.get(sessionId).Id;
                        newSMSessionIndividual.JT_User__c = phoneToUserNameMap.get(h.sender.display_name).Id;
                        updateSession.Johnson_Turner_User__c = phoneToUserNameMap.get(h.sender.display_name).Id;
                        newSMSessionIndividual.type__c = 'User';
                        newSMSessionIndividuals.add(newSMSessionIndividual);
                    }
                    
                    for(ToMember toMember: h.to_members){
                        if(toMember.phone_number != null){
                            if(phoneToAccountIdMap.containsKey(toMember.phone_number)){
                                SMS_Session_Individual__c newSMSessionIndividual = new SMS_Session_Individual__c();
                                newSMSessionIndividual.Zoom_Session_Id__c = sessionId;
                                newSMSessionIndividual.SMS_Session__c = sessionZoomIdToSMSessionMap.get(sessionId).Id;
                                newSMSessionIndividual.Account__c = phoneToAccountIdMap.get(toMember.phone_number).Id;
                                updateSession.Account__c = phoneToAccountIdMap.get(toMember.phone_number).Id;
                                newSMSessionIndividual.type__c = 'Account';
                                newSMSessionIndividuals.add(newSMSessionIndividual);
                            }
                            else if(phoneToLeadIdMap.containsKey(toMember.phone_number)){
                                SMS_Session_Individual__c newSMSessionIndividual = new SMS_Session_Individual__c();
                                newSMSessionIndividual.Zoom_Session_Id__c = sessionId;
                                newSMSessionIndividual.SMS_Session__c = sessionZoomIdToSMSessionMap.get(sessionId).Id;
                                newSMSessionIndividual.Lead__c = phoneToLeadIdMap.get(toMember.phone_number).Id;
                                updateSession.Prospect__c = phoneToLeadIdMap.get(toMember.phone_number).Id;
                                newSMSessionIndividual.type__c = 'Lead';
                                newSMSessionIndividuals.add(newSMSessionIndividual);
                            }
                            else if(phoneToUserIdMap.containsKey(toMember.phone_number)){
                                SMS_Session_Individual__c newSMSessionIndividual = new SMS_Session_Individual__c();
                                newSMSessionIndividual.Zoom_Session_Id__c = sessionId;
                                newSMSessionIndividual.SMS_Session__c = sessionZoomIdToSMSessionMap.get(sessionId).Id;
                                newSMSessionIndividual.JT_User__c = phoneToUserIdMap.get(toMember.phone_number).Id;
                                updateSession.Johnson_Turner_User__c = phoneToUserIdMap.get(toMember.phone_number).Id;
                                newSMSessionIndividual.type__c = 'User';
                                newSMSessionIndividuals.add(newSMSessionIndividual);
                            }
                            else if(phoneToUserNameMap.containsKey(h.sender.display_name)){
                                SMS_Session_Individual__c newSMSessionIndividual = new SMS_Session_Individual__c();
                                newSMSessionIndividual.Zoom_Session_Id__c = sessionId;
                                newSMSessionIndividual.SMS_Session__c = sessionZoomIdToSMSessionMap.get(sessionId).Id;
                                newSMSessionIndividual.JT_User__c = phoneToUserNameMap.get(h.sender.display_name).Id;
                                updateSession.Johnson_Turner_User__c = phoneToUserNameMap.get(h.sender.display_name).Id;
                                newSMSessionIndividual.type__c = 'User';
                                newSMSessionIndividuals.add(newSMSessionIndividual);
                            }
                        }
                    }
                }
                ListSessionsToUpdate.add(updateSession);
            }
            system.debug('newSMSessionIndividuals'+ newSMSessionIndividuals);
        }
        List<SMS_Session_Individual__c> newSMSessionIndividualsToReset = new List<SMS_Session_Individual__c>(newSMSessionIndividuals);
        set<SMS_Session_Individual__c> reset = new set<SMS_Session_Individual__c>();
        for(SMS_Session_Individual__c ind: newSMSessionIndividualsToReset){
            system.debug('ind: '+ind);
            reset.add(ind);
        }
        system.debug('reset'+ reset);
        List<SMS_Session_Individual__c> newSMSessionIndividualsToInsert = new List<SMS_Session_Individual__c>(reset);
        insert newSMSessionIndividualsToInsert;

        update ListSessionsToUpdate;
    }



    public static User getSMSInternalUser(String userName){
        system.debug('userName'+ userName);
        return [SELECT Id, Name, Username FROM User WHERE Name =: userName];
    }

    public static List<Account> getRelatedPersonAccountByPhoneNumber(Set<String> phoneFormats){
        List<Account> accounts = [SELECT Id, Name, Phone FROM Account WHERE Phone IN: phoneFormats];
        return (accounts.isEmpty()) ? null : accounts; // Returns first matching accounts or null
    }

    public static List<Lead> getRelatedLeadByPhoneNumber(Set<String> phoneFormats){
        List<Lead> leads = [SELECT Id, Name, Phone FROM lead WHERE Phone IN: phoneFormats];
        return (leads.isEmpty()) ? null : leads; // Returns first matching leads or null
    }

    public static List<User> getRelatedUsersByPhoneNumber(Set<String> phoneFormats){
        List<User> Users = [SELECT Id, Name, Phone FROM User WHERE Phone IN: phoneFormats];
        return (Users.isEmpty()) ? null : Users; // Returns first matching users or null
    }

    public static List<User> getRelatedUsersByName(Set<String> names){
        List<User> Users = [SELECT Id, Name, Phone FROM User WHERE Name IN: names];
        return (Users.isEmpty()) ? null : Users; // Returns first matching users or null
    }

    public static string formatPhoneNumber(String phone){
        if (phone == null) {
            return null;
        }
    
        // Remove all non-digit characters
        String digits = phone.replaceAll('[^0-9]', '');
    
        // Ensure we have exactly 10 digits (standard US phone number)
        if (digits.length() == 10) {
            return '(' + digits.substring(0, 3) + ') ' + digits.substring(3, 6) + '-' + digits.substring(6);
        } else {
            // Return the original input if it doesn't match expected format
            return phone;
        }
    }

    public static string removePhoneNumberFormat(String phone){
        if (phone == null) {
            return null;
        }
    
        // Remove all non-digit characters
        String digits = phone.replaceAll('[^0-9]', '');
        system.debug('digits: '+ digits);
        return '1'+digits;
    }

    public static List<String> generatePhoneFormats(String phone) {
        List<String> formats = new List<String>();
        String digits = phone;
        // system.debug('length: '+ digits.length());
        // Ensure we have 9 or 10 digits
        if (digits.length() == 10) {
            digits = digits; 
        }
        if (digits.length() == 11) {
            digits = digits.substring(1, 11); 
        }
        system.debug('phone entering: '+ phone);
        system.debug('phone transformed: '+ digits);
        // Create different formats
        formats.add(digits.substring(0, 3) + '' + digits.substring(3, 6) + '-' + digits.substring(6));
        formats.add('(' + digits.substring(0, 3) + ') ' + digits.substring(3, 6) + '-' + digits.substring(6));
        formats.add(digits.substring(0, 3) + '-' + digits.substring(3, 6) + '-' + digits.substring(6));
        formats.add('1-' +digits.substring(0, 3) + '-' + digits.substring(3, 6) + '-' + digits.substring(6));
        formats.add(digits.substring(0, 3) + '.' + digits.substring(3, 6) + '.' + digits.substring(6));
        formats.add(digits.substring(0, 3) + ' ' + digits.substring(3, 6) + ' ' + digits.substring(6));
        formats.add('+1-' + digits.substring(0, 3) + '-' + digits.substring(3, 6) + '-' + digits.substring(6));
        formats.add('+1' + digits.substring(0, 3) + '' + digits.substring(3, 6) + '' + digits.substring(6));
        formats.add('1-' + digits.substring(0, 3) + '' + digits.substring(3, 6) + '' + digits.substring(6));
        // formats.add(digits.substring(0, 3) + '' + digits.substring(3, 6) + '-' + digits.substring(6));
        formats.add('001-' + digits.substring(0, 3) + '-' + digits.substring(3, 6) + '-' + digits.substring(6));
        formats.add('1'+digits);
        formats.add(digits); // Just the raw number

        return formats;
    }

    public class ZoomSMSWrapper {
        public String next_page_token;
        public Integer page_size;
        public List<SMS_Session> sms_sessions;
    }

    public class SMS_Session {
        public String last_access_time;
        public List<Participant> participants;
        public String session_id;
        public String session_type;
    }
    
    public  class Participant {
        public String display_name;
        public Owner owner;
        public String phone_number;
        public Boolean is_session_owner;
        public String extension_status;
        public String extension_deleted_time;
    }
    
    public class SMSHistoryWrapper {
        public List<SMSHistory> sms_histories;
        public String sync_token;
    }
    public class SMSHistory {
        public List<Attachment> attachments;
        public String date_time;
        public String direction;
        public String message;
        public String message_id;
        public Integer message_type;
        public Sender sender;
        public List<ToMember> to_members;
    }

    public class Attachment {
        public String download_url;
        public String id;
        public String name;
        public Integer size;
        public String type;
    }

    public class Sender {
        public String display_name;
        public Owner owner;
        public String phone_number;
    }

    public class ToMember {
        public String display_name;
        public Owner owner;
        public String phone_number;
    }

    public class Owner {
        public String id;
        public String type;
    }
    
    public static SMSHistoryWrapper parse(String jsonString) {
        return (SMSHistoryWrapper) JSON.deserialize(jsonString, SMSHistoryWrapper.class);
    }

}