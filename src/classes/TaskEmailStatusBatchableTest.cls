/**
 * Developed by Doug Ayers
 * douglascayers.com
 */
@isTest
private class TaskEmailStatusBatchableTest {

    @isTest
    static void test_schedule_batch() {

        Test.startTest();

        String jobId = System.schedule( 'TaskEmailStatusBatchableJob', '0 0 1 ? * *', new TaskEmailStatusBatchable() );

        Test.stopTest();

    }

    @isTest
    static void test_batch() {

        Account acct = new Account(
            name = 'Salesforce'
        );

        insert acct;

        Contact cont = new Contact(
            accountId = acct.id,
            firstName = 'Marc',
            lastName = 'Benioff',
            email = 'ceo@salesforce.com'
        );

        insert cont;

        Lead ld = new Lead(
            company = 'Salesforce',
            firstName = 'Parker',
            lastName = 'Harris',
            email = 'parker@salesforce.com'
        );

        insert ld;

        Task tsk1 = new Task(
            subject = 'Test Email',
            whatId = acct.id,
            whoId = cont.id,
            taskSubType = 'Email'
        );

        insert tsk1;

        Task tsk2 = new Task(
            subject = 'Test Email',
            whatId = null,
            whoId = ld.id,
            taskSubType = 'Email'
        );

        insert tsk2;

        Test.startTest();

        // now, we haven't actually "sent" any real emails
        // and we can't from an apex test. nor can we create
        // EmailStatus records to spoof that we did either.
        // we can't even create EmailMessage record and
        // specify its ActivityId... blurggh
        // so at best we're just testing that most of the
        // mechanics of the batchable are working here.

        Database.executeBatch( new TaskEmailStatusBatchable() );

        Test.stopTest();

    }

    @isTest
    static void test_process_email_statuses() {

        // lame sauce, not only can we not DML the EmailStatus object
        // we can't even set field values on the object in memory for unit testing!
        // just as in the other tests, we're at best just testing that most of the
        // mechanics of the batchable are working here.

        List<EmailStatus> emailStatuses = new List<EmailStatus>{ new EmailStatus() };

        List<Task> tasksToUpdate = new List<Task>{ new Task() };

        List<HTML_Email_Status__c> emailStatusesToUpsert = new List<HTML_Email_Status__c>{ new HTML_Email_Status__c() };

        // because we can't set the taskId property of the EmailStatus object
        // then in the batchable when it tries to retrieve a map value by task id
        // it's actually passing in <null> as the key to retrieve by.
        // to get code coverage, we set a value whose key is <null> and voila
        Map<ID, EmailMessage> taskIdToEmailMessageMap = new Map<ID, EmailMessage>{ null => new EmailMessage() };

        Test.startTest();

        TaskEmailStatusBatchable batchable = new TaskEmailStatusBatchable();

        batchable.processEmailStatuses( emailStatuses, tasksToUpdate, emailStatusesToUpsert, taskIdToEmailMessageMap );

        Test.stopTest();

    }

}