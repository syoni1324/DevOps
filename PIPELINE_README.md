# UAT End-to-End Pipeline Documentation

This GitHub Actions workflow implements a comprehensive CI/CD pipeline for Salesforce UAT deployments.

## Overview

The pipeline includes the following stages:

1. **Setup**: Evaluates availability of security scanners based on secrets.
2. **Salesforce Validation**: Validates PR changes, runs tests, checks coverage, and performs SCA.
3. **SCA/SAST Stage**: Runs npm audit with waivers.
4. **Automated Governance**: Full test suite and governance checks.
5. **Checkmarx SAST**: Runs Checkmarx scans if configured.
6. **Fortify SAST/DAST**: Runs Fortify scans if configured.
7. **Approval Merge Gate**: Handles PR approvals and merges.
8. **Deploy After Merge**: Deploys to UAT org.
9. **Trigger CRT Tests**: Runs Copado Robotic Testing smoke tests.

## Configuration

Configure the following variables in repository settings:

- `ORG_ALIAS`: Default 'uat'
- `COVERAGE_THRESHOLD`: Default '85'
- `SOURCE_DIR`: Default 'force-app/main/default'
- `SFDX_AUTH_SECRET_NAME`: Default 'CRT_UAT_AUTHURL'
- `DELTA_FROM_COMMIT`: Commit SHA for delta calculations
- `FCLI_BOOTSTRAP_VERSION`: Version for FCLI
- `SCA_ENFORCEMENT_MODE`: 'enforce', 'warn', or 'off'

## Secrets Required

- `CRT_UAT_AUTHURL`: SFDX auth URL for UAT org
- `CX_CLIENT_SECRET`: Checkmarx client secret
- `FOD_CLIENT_SECRET`: Fortify on Demand client secret
- `CRT_API_TOKEN`: Copado Robotic Testing API token
- `GH_PAT`: GitHub PAT for API calls

## Waiver Files

- `.github/sf-scanner-waivers.csv`: Waivers for Salesforce scanner violations
- `.github/sca-waivers.json`: Waivers for npm audit vulnerabilities

## Triggers

- PR to `uat` branch affecting specified paths
- PR reviews
- Manual workflow dispatch