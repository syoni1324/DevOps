public with sharing class AccountUtilityService {

    public static List<Account> getAccountsByType(String typeValue) {
        if (String.isBlank(typeValue)) {
            return new List<Account>();
        }

        return [
            SELECT Id, Name, Type, Description
            FROM Account
            WHERE Type = :typeValue
            ORDER BY Name
        ];
    }

    public static Integer updateAccountDescriptions(Set<Id> accountIds, String appendText) {
        if (accountIds == null || accountIds.isEmpty() || String.isBlank(appendText)) {
            return 0;
        }
        

        
        List<Account> accountsToUpdate = [
            SELECT Id, Description
            FROM Account
            WHERE Id IN :accountIds
        ];

        for (Account acc : accountsToUpdate) {
            if (String.isBlank(acc.Description)) {
                acc.Description = appendText;
            } else {
                acc.Description = acc.Description + ' | ' + appendText;
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }

        return accountsToUpdate.size();
    }


    
    public static Map<Id, Integer> getContactCountByAccount(Set<Id> accountIds) {
        Map<Id, Integer> contactCountByAccount = new Map<Id, Integer>();

        if (accountIds == null || accountIds.isEmpty()) {
            return contactCountByAccount;
        }

        for (AggregateResult ar : [
            SELECT AccountId accId, COUNT(Id) contactCount
            FROM Contact
            WHERE AccountId IN :accountIds
            GROUP BY AccountId
        ]) {
            Id accId = (Id) ar.get('accId');
            Integer contactCount = Integer.valueOf(String.valueOf(ar.get('contactCount')));
            contactCountByAccount.put(accId, contactCount);
        }

        for (Id accId : accountIds) {
            if (!contactCountByAccount.containsKey(accId)) {
                contactCountByAccount.put(accId, 0);
            }
        }

        return contactCountByAccount;
    }
}
