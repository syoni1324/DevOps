@isTest
private class AccountUtilityServiceTest {

    @testSetup
    static void setupTestData() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Acme One', Type = 'Customer - Direct', Description = 'Existing description'),
            new Account(Name = 'Acme Two', Type = 'Customer - Direct'),
            new Account(Name = 'Acme Three', Type = 'Prospect')
        };
        insert accounts;

        List<Contact> contacts = new List<Contact>{
            new Contact(FirstName = 'John', LastName = 'Doe', AccountId = accounts[0].Id),
            new Contact(FirstName = 'Jane', LastName = 'Doe', AccountId = accounts[0].Id),
            new Contact(FirstName = 'Sam', LastName = 'Smith', AccountId = accounts[1].Id)
        };
        insert contacts;
    }

    @isTest
    static void testGetAccountsByType() {
        Test.startTest();
        List<Account> result = AccountUtilityService.getAccountsByType('Customer - Direct');
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Expected 2 Customer - Direct accounts');
    }

    @isTest
    static void testGetAccountsByType_BlankInput() {
        Test.startTest();
        List<Account> result = AccountUtilityService.getAccountsByType('');
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Expected no records for blank input');
    }

    @isTest
    static void testUpdateAccountDescriptions() {
        List<Account> accounts = [
            SELECT Id, Description
            FROM Account
            WHERE Name IN ('Acme One', 'Acme Two')
            ORDER BY Name
        ];

        Set<Id> accountIds = new Set<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }

        Test.startTest();
        Integer updatedCount = AccountUtilityService.updateAccountDescriptions(accountIds, 'QA Ready');
        Test.stopTest();

        System.assertEquals(2, updatedCount, 'Expected 2 accounts to be updated');

        Map<Id, Account> refreshedAccounts = new Map<Id, Account>([
            SELECT Id, Description
            FROM Account
            WHERE Id IN :accountIds
        ]);

        for (Account originalAcc : accounts) {
            Account refreshed = refreshedAccounts.get(originalAcc.Id);
            System.assert(refreshed.Description.contains('QA Ready'), 'Description should contain appended text');
        }
    }

    @isTest
    static void testUpdateAccountDescriptions_InvalidInput() {
        Test.startTest();
        Integer result1 = AccountUtilityService.updateAccountDescriptions(null, 'Test');
        Integer result2 = AccountUtilityService.updateAccountDescriptions(new Set<Id>(), 'Test');
        Integer result3 = AccountUtilityService.updateAccountDescriptions(new Set<Id>{UserInfo.getUserId()}, '');
        Test.stopTest();

        System.assertEquals(0, result1, 'Expected 0 for null Id set');
        System.assertEquals(0, result2, 'Expected 0 for empty Id set');
        System.assertEquals(0, result3, 'Expected 0 for blank append text');
    }

    @isTest
    static void testGetContactCountByAccount() {
        List<Account> accounts = [
            SELECT Id, Name
            FROM Account
            WHERE Name IN ('Acme One', 'Acme Two', 'Acme Three')
        ];

        Set<Id> accountIds = new Set<Id>();
        Map<String, Id> accountNameToId = new Map<String, Id>();

        for (Account acc : accounts) {
            accountIds.add(acc.Id);
            accountNameToId.put(acc.Name, acc.Id);
        }

        Test.startTest();
        Map<Id, Integer> counts = AccountUtilityService.getContactCountByAccount(accountIds);
        Test.stopTest();

        System.assertEquals(3, counts.size(), 'Expected all accounts in result map');
        System.assertEquals(2, counts.get(accountNameToId.get('Acme One')), 'Acme One should have 2 contacts');
        System.assertEquals(1, counts.get(accountNameToId.get('Acme Two')), 'Acme Two should have 1 contact');
        System.assertEquals(0, counts.get(accountNameToId.get('Acme Three')), 'Acme Three should have 0 contacts');
    }

    @isTest
    static void testGetContactCountByAccount_EmptyInput() {
        Test.startTest();
        Map<Id, Integer> counts = AccountUtilityService.getContactCountByAccount(new Set<Id>());
        Test.stopTest();

        System.assertEquals(0, counts.size(), 'Expected empty result for empty input');
    }
}
