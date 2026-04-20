@IsTest
private class CoverageDemoServiceTest {

    @IsTest
    static void testCalcDiscount_allBranches() {
        System.assertEquals(0, CoverageDemoService.calcDiscount(100, null));
        System.assertEquals(0, CoverageDemoService.calcDiscount(100, '   '));

        System.assertEquals(3, CoverageDemoService.calcDiscount(100, 'BRONZE'));
        System.assertEquals(7, CoverageDemoService.calcDiscount(100, 'SILVER'));
        System.assertEquals(12, CoverageDemoService.calcDiscount(100, 'GOLD'));

        System.assertEquals(750, CoverageDemoService.calcDiscount(5000, 'PLATINUM'));
        System.assertEquals(1200, CoverageDemoService.calcDiscount(6000, 'PLATINUM'));

        System.assertEquals(0, CoverageDemoService.calcDiscount(9999, 'UNKNOWN'));
        System.assertEquals(500, CoverageDemoService.calcDiscount(10000, 'UNKNOWN'));

        // Clamp upper bound
        System.assertEquals(2500, CoverageDemoService.calcDiscount(20000, 'PLATINUM'));

        try {
            CoverageDemoService.calcDiscount(null, 'SILVER');
            System.assert(false, 'Expected exception for null amount');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('amount must be >= 0'));
        }

        try {
            CoverageDemoService.calcDiscount(-1, 'SILVER');
            System.assert(false, 'Expected exception for negative amount');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('amount must be >= 0'));
        }
    }
    
    @IsTest
    static void testClassifyAccount_allBranches() {
        System.assertEquals('NULL', CoverageDemoService.classifyAccount(null));

        Account a1 = new Account(Name = 'A1');
        System.assertEquals('UNKNOWN', CoverageDemoService.classifyAccount(a1));

        Account a2 = new Account(Name = 'BigCo', AnnualRevenue = 10000000);
        System.assertEquals('ENTERPRISE', CoverageDemoService.classifyAccount(a2));

        Account a3 = new Account(Name = 'MidCo', AnnualRevenue = 1000000);
        System.assertEquals('MID', CoverageDemoService.classifyAccount(a3));

        Account a4 = new Account(Name = 'SmbCo', AnnualRevenue = 100000);
        System.assertEquals('SMB', CoverageDemoService.classifyAccount(a4));

        Account a5 = new Account(Name = 'OpsCo', AnnualRevenue = 50000, NumberOfEmployees = 700);
        System.assertEquals('WORKFORCE_LARGE', CoverageDemoService.classifyAccount(a5));

        Account a6 = new Account(Name = 'Test Holdings', AnnualRevenue = 50000, NumberOfEmployees = 10);
        System.assertEquals('NAME_TEST', CoverageDemoService.classifyAccount(a6));

        Account a7 = new Account(Name = 'TinyCo', AnnualRevenue = 50000, NumberOfEmployees = 10);
        System.assertEquals('MICRO', CoverageDemoService.classifyAccount(a7));
    }

    @IsTest
    static void testComputeRiskScore_keyBranches() {
        System.assertEquals(0, CoverageDemoService.computeRiskScore(null));
        System.assertEquals(0, CoverageDemoService.computeRiskScore('   '));

        System.assertEquals(3, CoverageDemoService.computeRiskScore('hello!'));

        String highRisk = 'admin!!!!!!!!!!!1234567890123456ABCDEFGHIJKLMN';
        System.assertEquals(30, CoverageDemoService.computeRiskScore(highRisk));

        String mediumRisk = 'admin!1234567890';
        System.assertEquals(19, CoverageDemoService.computeRiskScore(mediumRisk));
    }
}