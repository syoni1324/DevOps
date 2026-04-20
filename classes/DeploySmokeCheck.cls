public with sharing class DeploySmokeCheck {
    public class SmokeCheckException extends Exception {}

    public class CheckResult {
        public String status;
        public String orgId;
        public String userId;
        public String timestampUtc;
        public String message;
        public List<String> warnings;
    }

    // Main entrypoint: safe to call from CI smoke validation, flows, or REST wrappers.
    public static CheckResult run(String messageOverride) {
        CheckResult res = new CheckResult();
        res.status = 'OK';
        res.orgId = UserInfo.getOrganizationId();
        res.userId = UserInfo.getUserId();
        res.timestampUtc = Datetime.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        res.warnings = new List<String>();

        String msg;
        if (String.isBlank(messageOverride)) {
            msg = 'Deployment smoke check passed.';
            res.warnings.add('DEFAULT_MESSAGE_USED');
        } else {
            msg = messageOverride.trim();
            if (msg != messageOverride) {
                res.warnings.add('MESSAGE_TRIMMED');
            }
        }

        
        // Keep messages log-friendly (and UI-friendly if surfaced later)
        Integer maxLen = 140;
        if (msg.length() > maxLen) {
            msg = msg.substring(0, maxLen);
            res.warnings.add('MESSAGE_TRUNCATED');
        }
        res.message = msg;

        // Defensive check: ensure timestamp is in expected Zulu format
        assertIsoZuluOrThrow(res.timestampUtc);

        return res;
    }
 

    
    @TestVisible
    private static void assertIsoZuluOrThrow(String value) {
        if (!isIsoZulu(value)) {
            throw new SmokeCheckException('Timestamp is not ISO-8601 Zulu: ' + value);
        }
    }
  
    @TestVisible
    private static Boolean isIsoZulu(String value) {
        if (String.isBlank(value)) return false;
        if (value.length() != 20) return false; // yyyy-MM-ddTHH:mm:ssZ

        // Position checks
        if (value.substring(4, 5) != '-') return false;
        if (value.substring(7, 8) != '-') return false;
        if (value.substring(10, 11) != 'T') return false;
        if (value.substring(13, 14) != ':') return false;
        if (value.substring(16, 17) != ':') return false;
        if (!value.endsWith('Z')) return false;

        // Digit checks (basic)
        String digitsOnly = value.replace('-', '').replace(':', '').replace('T', '').replace('Z', '');
        if (digitsOnly.length() != 14) return false;
        for (Integer i = 0; i < digitsOnly.length(); i++) {
            String ch = digitsOnly.substring(i, i + 1);
            if (ch < '0' || ch > '9') return false;
        }
        return true;
    }
}
