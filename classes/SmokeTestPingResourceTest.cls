@IsTest
private class SmokeTestPingResourceTest {
    @IsTest
    static void pingReturnsOk() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'GET';
        req.requestUri = '/services/apexrest/smoketest/v1/ping';
        RestContext.request = req;
        RestContext.response = res;

        SmokeTestPingResource.PingResponse out = SmokeTestPingResource.doGet();

        System.assertEquals('OK', out.status);
        System.assertNotEquals(null, out.orgId);
        System.assertNotEquals(null, out.userId);
        System.assert(out.timestampUtc != null && out.timestampUtc.contains('T'));
    }
}


