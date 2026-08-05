public with sharing class BoxAiFlowAction {
    //
    // ===== INPUT / OUTPUT CLASSES FOR FLOW =====
    //
    public class AIRequest {
        @InvocableVariable public String fileId;
        @InvocableVariable public String question;
        @InvocableVariable public Boolean includeCitations;
        @InvocableVariable public String mode;
    }

    public class AIResponse {
        @InvocableVariable public String answer;
        @InvocableVariable public String rawJson;
    }

    //
    // ===== FLOW-ENTRY POINT =====
    //
    @InvocableMethod(label='Ask Box AI' description='Query Box AI /2.0/ai/ask endpoint')
    public static List<AIResponse> askBoxAI(List<AIRequest> requests) {
        return runAi(requests);
    }

    //
    // ===== WRAPPER THAT CAN BE CALLED FROM ANONYMOUS APEX =====
    //
    public static List<AIResponse> runAi(List<AIRequest> requests) {
        List<AIResponse> out = new List<AIResponse>();

        for (AIRequest req : requests) {
            out.add(callBoxAi(req));
        }

        return out;
    }

    //
    // ===== CORE CALL TO BOX AI =====
    //
    private static AIResponse callBoxAi(AIRequest req) {
        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint('callout:BoxAI');   // Named Credential
        httpReq.setMethod('POST');
        httpReq.setHeader('Content-Type', 'application/json');

        //
        // BUILD PAYLOAD EXACTLY AS BOX EXPECTS
        //
        Map<String, Object> payload = new Map<String, Object>();

        payload.put('mode', req.mode != null ? req.mode : 'single_item_qa');
        payload.put('prompt', req.question);

        // items
        payload.put('items', new List<Object>{
            new Map<String, Object>{
                'type' => 'file',
                'id'   => req.fileId
            }
        });

        // Optional empty dialogue history (Box allows empty array)
       // payload.put('dialogue_history', new List<Object>());

        // include_citations
        payload.put('include_citations', req.includeCitations == true);

        //
        // ai_agent (matches your cURL example exactly)
        //
        payload.put('ai_agent', new Map<String, Object>{
            'type' => 'ai_agent_ask',
            'long_text' => new Map<String, Object>{
                'model' => 'azure__openai__gpt_4o_mini',
                'prompt_template' => 'It is `{current_date}`, and I have $8000 and want to spend a week in the Azores. What should I see?'
            },
            'basic_text' => new Map<String, Object>{
                'model' => 'azure__openai__gpt_4o_mini'
            }
        });

        httpReq.setBody(JSON.serialize(payload));

        //
        // SEND CALL
        //
        Http http = new Http();
        HttpResponse res = http.send(httpReq);

        //
        // PARSE RESULTS
        //
        Map<String, Object> json = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

        AIResponse resp = new AIResponse();
        resp.rawJson = res.getBody();

        if (json.containsKey('answer')) {
            resp.answer = (String) json.get('answer');
        }

        return resp;
    }
}