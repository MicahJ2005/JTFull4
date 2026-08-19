// Manually fire PopulateEventWhatIdQueueable for a specific set of Event Ids.
//
// HOW TO USE:
//   1. Fill in EVENT_IDS below with the 18-char Event Ids you want to process.
//   2. Run this file via "SFDx: Execute Anonymous Apex with Editor Contents".
//   3. Check the debug log for the enqueued job Id, then check the
//      Event/EventRelation records once the queueable finishes.

Set<Id> EVENT_IDS = new Set<Id>{
    '00U000000000000AAA' // <-- EDIT: replace with real Event Id(s)
};

System.debug('=== Enqueuing PopulateEventWhatIdQueueable for ' + EVENT_IDS.size() + ' event(s) ===');

Id jobId = System.enqueueJob(new PopulateEventWhatIdQueueable(EVENT_IDS));

System.debug('Queueable job enqueued with Id: ' + jobId);
