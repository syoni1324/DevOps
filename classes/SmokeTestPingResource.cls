@RestResource(urlMapping='/smoketest/v1/*')
global with sharing class SmokeTestPingResource {
    global class PingResponse {
        public String status;
        public String orgId;
        public String userId;
        public String timestampUtc;
        public String message;
    }

    @HttpGet
    global static PingResponse doGet() {
        PingResponse res = new PingResponse();
        res.status = 'OK';
        res.orgId = UserInfo.getOrganizationId();
        res.userId = UserInfo.getUserId();
        res.timestampUtc = String.valueOf(Datetime.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
        res.message = 'Smoke test endpoint reachable.';
        return res;
    }
}


