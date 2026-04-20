@IsTest
private class DeploySmokeCheckTest {

    @IsTest
    static void run_defaultMessage_populatesFields() {
        Test.startTest();
        DeploySmokeCheck.CheckResult out = DeploySmokeCheck.run(null);
        Test.stopTest();

        System.assertNotEquals(null, out);
        System.assertEquals('OK', out.status);
        System.assertEquals(UserInfo.getOrganizationId(), out.orgId);
        System.assertEquals(UserInfo.getUserId(), out.userId);
        System.assertEquals('Deployment smoke check passed.', out.message);

        System.assertNotEquals(null, out.warnings);
        System.assert(out.warnings.contains('DEFAULT_MESSAGE_USED'));

        System.assertNotEquals(null, out.timestampUtc);
        System.assertEquals(20, out.timestampUtc.length());
        System.assert(out.timestampUtc.endsWith('Z'));
        System.assertEquals(true, DeploySmokeCheck.isIsoZulu(out.timestampUtc));
    }


    
    @IsTest
    static void run_customMessage_trim_and_truncate() {
        String longMsg = '   ' + String.valueOf('X').repeat(200) + '   ';

        Test.startTest();
        DeploySmokeCheck.CheckResult out = DeploySmokeCheck.run(longMsg);
        Test.stopTest();

        System.assertEquals('OK', out.status);
        System.assertEquals(140, out.message.length(), 'Message should be truncated to 140 chars');
        System.assertEquals(false, out.message.startsWith(' '), 'Message should be trimmed');
        System.assertEquals(false, out.message.endsWith(' '), 'Message should be trimmed');

        System.assert(out.warnings.contains('MESSAGE_TRIMMED'));
        System.assert(out.warnings.contains('MESSAGE_TRUNCATED'));
        System.assertEquals(true, DeploySmokeCheck.isIsoZulu(out.timestampUtc));
    }
    
    @IsTest
    static void isoZulu_validator_negativeCases_and_exception() {
        System.assertEquals(false, DeploySmokeCheck.isIsoZulu(null));
        System.assertEquals(false, DeploySmokeCheck.isIsoZulu(''));
        System.assertEquals(false, DeploySmokeCheck.isIsoZulu('2026-01-01')); // too short
        System.assertEquals(false, DeploySmokeCheck.isIsoZulu('2026-01-01T00:00:00')); // missing Z
        System.assertEquals(false, DeploySmokeCheck.isIsoZulu('2026-01-01 00:00:00Z')); // missing T
        System.assertEquals(false, DeploySmokeCheck.isIsoZulu('2026-01-01T0A:00:00Z')); // non-digit

        Boolean threw = false;
        try {
            DeploySmokeCheck.assertIsoZuluOrThrow('bad');
        } catch (DeploySmokeCheck.SmokeCheckException e) {
            threw = true;
            System.assert(e.getMessage().contains('Timestamp is not ISO-8601 Zulu'));
        }
        System.assertEquals(true, threw, 'Expected SmokeCheckException');
    }
}
