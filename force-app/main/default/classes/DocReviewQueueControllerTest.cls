@isTest
private class DocReviewQueueControllerTest {
    @isTest
    static void getReviewQueue_returnsScaffoldRows() {
        Test.startTest();
        List<DocReviewQueueController.ReviewDoc> rows = DocReviewQueueController.getReviewQueue();
        Test.stopTest();
        System.assertNotEquals(null, rows, 'queue should not be null');
        System.assert(rows.size() >= 1, 'scaffold returns mock rows');
        DocReviewQueueController.ReviewDoc first = rows[0];
        System.assertNotEquals(null, first.documentId, 'documentId populated');
        System.assertNotEquals(null, first.fileName, 'fileName populated');
        System.assertNotEquals(null, first.cssName, 'cssName populated (grouping key)');
    }

    @isTest
    static void approveAndFile_scaffoldNoThrow() {
        Test.startTest();
        DocReviewQueueController.approveAndFile('doc-x', 'Bank Statement', 'Documents/Bank Accounts');
        Test.stopTest();
        // scaffold is a no-op debug; assert it completes without exception
        System.assert(true, 'approveAndFile scaffold completed');
    }

    @isTest
    static void reject_scaffoldNoThrow() {
        Test.startTest();
        DocReviewQueueController.reject('doc-x', 'unreadable scan');
        Test.stopTest();
        System.assert(true, 'reject scaffold completed');
    }

    @isTest
    static void getReviewDoc_returnsMatchOrFirst() {
        Test.startTest();
        DocReviewQueueController.ReviewDoc match = DocReviewQueueController.getReviewDoc('doc-2');
        DocReviewQueueController.ReviewDoc fallback = DocReviewQueueController.getReviewDoc('nonexistent');
        Test.stopTest();
        System.assertEquals('doc-2', match.documentId, 'returns the matching mock doc');
        System.assertNotEquals(null, fallback, 'unknown id falls back to first row (scaffold)');
        System.assertNotEquals(null, fallback.documentId, 'fallback doc populated');
    }
}