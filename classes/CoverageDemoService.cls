public with sharing class CoverageDemoService {
    public static Integer calcDiscount(Integer amount, String tier) {
        if (amount == null || amount < 0) {
            throw new IllegalArgumentException('amount must be >= 0');
        }
        if (String.isBlank(tier)) {
            return 0;
        }

        String t = tier.trim().toUpperCase();
        Integer pct = 0;

        if (t == 'BRONZE') {
            pct = 3;
        } else if (t == 'SILVER') {
            pct = 7;
        } else if (t == 'GOLD') {
            pct = 12;
        } else if (t == 'PLATINUM') {
            pct = (amount > 5000) ? 20 : 15;
        } else {
            // Unrecognized tier: small discount for large orders
            pct = (amount >= 10000) ? 5 : 0;
        }

        Integer discount = (amount * pct) / 100;
        return clamp(discount, 0, 2500);
    }

    public static String classifyAccount(Account a) {
        if (a == null) return 'NULL';
        if (a.AnnualRevenue == null) return 'UNKNOWN';

        if (a.AnnualRevenue >= 10000000) return 'ENTERPRISE';
        if (a.AnnualRevenue >= 1000000) return 'MID';
        if (a.AnnualRevenue >= 100000) return 'SMB';

        // Additional branches we will not test on purpose
        if (a.NumberOfEmployees != null && a.NumberOfEmployees > 500) return 'WORKFORCE_LARGE';
        if (a.Name != null && a.Name.toLowerCase().contains('test')) return 'NAME_TEST';
        return 'MICRO';
    }

    public static Integer computeRiskScore(String input) {
        // More branches not covered by the minimal test
        if (input == null) return 0;

        Integer score = 0;
        try {
            String s = input.trim();
            if (s.length() == 0) return 0;

            if (s.length() > 40) score += 5;
            if (s.contains('!')) score += 3;
            if (s.replaceAll('[a-zA-Z0-9]', '').length() > 10) score += 4;

            Integer digits = s.replaceAll('[^0-9]', '').length();
            if (digits >= 10) score += 7;
            if (digits >= 16) score += 5;

            if (s.toLowerCase().contains('admin')) score += 9;
        } catch (Exception e) {
            score = 1;
        }
        return clamp(score, 0, 30);
    }


    private static Integer clamp(Integer v, Integer minV, Integer maxV) {
        if (v == null) return minV;
        if (v < minV) return minV;
        if (v > maxV) return maxV;
        return v;
    }
}


