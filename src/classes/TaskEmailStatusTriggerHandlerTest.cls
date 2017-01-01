/**
 * Developed by Doug Ayers
 * douglascayers.com
 */
@isTest
private class TaskEmailStatusTriggerHandlerTest {

    @isTest
    static void test_handler() {

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

        Test.startTest();

        // insert task

        Task tsk = new Task(
            subject = 'Test Email',
            whatId = acct.id,
            whoId = cont.id,
            taskSubType = 'Email'
        );

        insert tsk;

        List<HTML_Email_Status__c> emailStatuses = [ SELECT id, task_id__c, who_id__c FROM HTML_Email_Status__c WHERE task_id__c = :tsk.id ];

        System.assertEquals( 1, emailStatuses.size() );
        System.assertEquals( cont.id, emailStatuses[0].who_id__c );

        // change who id

        tsk.whatId = null;
        tsk.whoId = ld.id;

        update tsk;

        emailStatuses = [ SELECT id, task_id__c, who_id__c FROM HTML_Email_Status__c WHERE task_id__c = :tsk.id ];

        System.assertEquals( 1, emailStatuses.size() );
        System.assertEquals( ld.id, emailStatuses[0].who_id__c );

        // delete task

        delete tsk;

        System.assertEquals( 0, [ SELECT count() FROM HTML_Email_Status__c WHERE task_id__c = :tsk.id ] );

        Test.stopTest();

    }

}