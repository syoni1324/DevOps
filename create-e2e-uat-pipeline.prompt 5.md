---
description: "Generate the complete UAT end-to-end GitHub Actions pipeline workflow (e2e-uat-pipeline.yml) from scratch, including all jobs, waiver files, and documentation markdown files"
agent: "agent"
tools: [read, edit, search]
argument-hint: "Optionally specify customizations: target branch, org alias, coverage threshold, scanners to enable (checkmarx/fortify/all), CRT job/project/org IDs"
---

Generate a complete Salesforce UAT End-to-End GitHub Actions pipeline. Use the existing workflow at `.github/workflows/e2e-uat-pipeline.yml` and associated files as reference implementations.

## Workflow File: `.github/workflows/e2e-uat-pipeline.yml`

Create a workflow named `UAT End-to-End Pipeline` with the following characteristics:

### Triggers
- `pull_request` to `uat` branch for paths: `force-app/**`, `.github/workflows/e2e-uat-pipeline.yml`, `.github/sf-scanner-waivers.csv` — types: opened, reopened, synchronize, edited, ready_for_review
- `pull_request_review` — types: submitted
- `workflow_dispatch` with inputs: `scanner` (choices: all | checkmarx | fortify), `action` (choices: deploy | rollback), `rollback_commit_sha` (string), `rollback_pr_number` (string)

### Global env vars (configurable via `vars.*`)
- `ORG_ALIAS` (default: `uat`)
- `COVERAGE_THRESHOLD` (default: `85`)
- `SOURCE_DIR` (default: `force-app/main/default`)
- `SFDX_AUTH_SECRET_NAME` (default: `CRT_UAT_AUTHURL`)
- `DELTA_FROM_COMMIT`, `FCLI_BOOTSTRAP_VERSION`
- `SCA_ENFORCEMENT_MODE` (default: `enforce`) — controls scanner failure behaviour: `enforce` = expired waivers fail pipeline; `warn` = all violations are warnings only; `off` = all SCA steps skipped entirely

### Jobs (in dependency order)

**Job 1 — `setup`**: Evaluate Scanner Availability
- Outputs: `run-checkmarx`, `run-fortify` booleans based on presence of `CX_CLIENT_SECRET` / `FOD_CLIENT_SECRET`
- Skips on `pull_request_review`

**Job 2 — `salesforce-validation`**: Salesforce PR Validation
- Triggers: `pull_request` only
- **Outputs:** `has_delta` (bool) — set `true` if `package/package.xml` or `destructiveChanges/destructiveChanges.xml` contains members
- Steps:
  1. checkout (fetch-depth: 0) → setup-node 20 → **bootstrap `package.json` if missing** (writes full standard Salesforce `package.json` with eslint/prettier/jest/husky devDependencies via bash heredoc) → npm install → install Salesforce CLI
  2. Authenticate org from `secrets.CRT_UAT_AUTHURL`
  3. Extract test classes from PR body + comments (pattern: `Tests: Class1, Class2`)
  4. Install `sfdx-git-delta` → build delta package → upload delta artifact
  5. Compute Apex delta + infer test classes by `*Test`, `*Tests`, `*TestClass` suffix
  6. Set `has_delta` output
  7. **[if has_delta]** `sf project deploy validate --async` → poll every 15s → show live progress table → show component breakdown (➕ CREATED / ✏️ UPDATED / 🗑️ DELETED) → per-class coverage
  8. **[if has_delta]** Check Apex coverage (threshold: `$COVERAGE_THRESHOLD`)
  9. **[if has_delta && SCA_ENFORCEMENT_MODE != 'off']** Install `@salesforce/sfdx-scanner`
  10. **[if has_delta && SCA_ENFORCEMENT_MODE != 'off']** Detect waiver file tampering — warns if dev modified `.github/sf-scanner-waivers.csv` in PR (ignored; waivers always read from main)
  11. **[if has_delta && SCA_ENFORCEMENT_MODE != 'off']** Fetch SCA waivers from main branch via GitHub API — fallback chain: default branch → base_ref → head_ref; if not found, continues without waiver check
  12. **[if SCA_ENFORCEMENT_MODE != 'off']** Detect changed `.cls/.trigger/.js/.html/.css` files for targeted SCA
  13. **[if has_targets && SCA_ENFORCEMENT_MODE != 'off']** `sf scanner run --target <changed-files-only> --format csv --outfile sfdx-report.csv --severity-threshold 3` (`continue-on-error: true`)
  14. **[if has_targets && SCA_ENFORCEMENT_MODE != 'off']** Check results against `.github/sf-scanner-waivers.csv` (fetched from main) — Python script with `parse_date()` supporting DD-MM-YYYY, DD/MM/YYYY, YYYY-MM-DD:
      - `WAIVED` ✅ — active waiver, >30 days remaining
      - `WAIVED_EXPIRING_SOON` ⏰ — active waiver, ≤30 days remaining (warning, does not fail)
      - `EXPIRED_WAIVER` ❌ — past expiry date — **job FAILS** (unless `SCA_ENFORCEMENT_MODE=warn`)
      - `VIOLATION` ⚠️ — no waiver found — warning only, does not fail
      - Writes `sca-governance-report.csv` with columns: Status, Rule, File, Line, Severity, Description, Expiry, Days_Left, Reason, Approved_By, Approved_Date, Ticket
  15. **[if has_targets && pull_request && SCA_ENFORCEMENT_MODE != 'off']** Post SCA governance report as PR comment (deletes previous comment first to avoid duplicates)
  16. Upload `sfdx-scanner-reports` artifact (includes `sfdx-report.csv`, `sca-governance-report.csv`, `fetched-waivers.csv`)
- **Key:** SCA targets only changed files, not the full `force-app/`. Scanner violations NEVER block the job.
- **Key:** `--test-level NoTestRun` is invalid for validate — omit `--test-level` when no Apex changed.
- **Key:** All SCA steps are gated on `vars.SCA_ENFORCEMENT_MODE != 'off'`. In `warn` mode, nothing fails.

**Job 3 — `sca-sast-stage`**: SCA/SAST Stage (npm audit)
- `needs: [setup]` (runs in **parallel** with Jobs 2, 5, 6)
- **Condition:** `pull_request` or `workflow_dispatch`
- Runs `npm audit --json`, checks against `.github/sca-waivers.json`, fails on unwaived/expired violations
- **package.json bootstrap:** same guard as Job 2 — if no `package.json` exists a standard one is created before `npm install` so `npm audit` does not ENOENT

**Job 4 — `automated-governance`**: Automated Hard Gates
- `needs: [salesforce-validation]`
- **Condition:** `needs.salesforce-validation.outputs.has_delta == 'true'`
- Full Apex test suite with coverage (`$COVERAGE_THRESHOLD` minimum, default 85%), destructive changes check + PR comment, targeted SCA

**Job 5 — `checkmarx-sast`**: CheckMarx AST Scan
- `needs: [setup]` (runs in **parallel** with Jobs 2, 3, 6), conditional on `run-checkmarx == 'true'`

**Job 6 — `fortify-sast-dast`**: Fortify SAST + optional DAST
- `needs: [setup]` (runs in **parallel** with Jobs 2, 3, 5), conditional on `run-fortify == 'true'`

**Job 7 — `approval-merge-gate`**: Approval + Merge Gate
- Triggers on `pull_request_review` (state=approved)
- Verifies approval freshness, merges PR, outputs `merge_commit_sha`

**Job 8 — `deploy-after-merge`**: Deploy to UAT
- `needs: [approval-merge-gate]`, `permissions: contents: write`
- Steps:
  1. Build delta package: `id: delta_pkg` — uses `git rev-parse HEAD^1` (merge parent = UAT branch tip before PR merged) as FROM for `sfdx-git-delta`. Exports `merge_base` output. Falls back to `DELTA_FROM_COMMIT` only if `HEAD^1` is unavailable (shallow clone).
  2. `sf project deploy start --async` → poll every 15s → live progress table → component breakdown → per-class coverage
  3. Build deployment package: `package.xml` + `destructiveChanges.xml` + `components.zip` + `deployment-info.json`
  4. Upload artifact (90-day retention)
  5. Commit package folder to `pr_packages` orphan branch
  6. Update `DELTA_FROM_COMMIT` via GitHub API (saved for rollback reference + fallback): `curl -L -X PATCH -H "Authorization: Bearer ${GH_PAT}" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/{repo}/actions/variables/DELTA_FROM_COMMIT -d '{"name":"DELTA_FROM_COMMIT","value":"<sha>"}'`

**Job 9 — `trigger-crt-tests`**: CRT Smoke Tests
- `needs: [deploy-after-merge]`
- GraphQL API: `POST https://graphql.eu-robotic.copado.com/v1` with `X-Authorization: ${CRT_API_TOKEN}`
- Mutation: `createBuild(projectId: <id>, jobId: <id>)` — triggers the build
- Step `id: crt` triggers build AND polls `latestBuilds(projectId: <id>, resultSize: 50)` every 30s until terminal status
- CRT statuses are **lowercase**: `executing`, `passed`, `failed`, `error`, `cancelled`, `skipped`
- Terminal check uses `is_terminal()` function matching lowercase values; exports `build_id` and `crt_status` outputs
- Step `id: pr_meta` (runs `if: always()`) — fetches PR number, raiser (PR author), and last approver via GitHub API
- Step `Print Job Summary` (runs `if: always() && steps.pr_meta.outputs.has_pr == 'true'`) — prints a box:
  ```
  ╔══════════════════════════════════════════╗
  ║        CRT Job Execution Summary         ║
  ╠══════════════════════════════════════════╣
    PR Number       : #<n>
    Workflow Run #  : <n>
    PR Raiser       : <username>
    PR Approver     : <username>
    Test Build ID   : <id>
    Test Result     : <crt_status>
  ╚══════════════════════════════════════════╝
  ```
- Posts result PR comment + GitHub Step Summary (with final CRT status icon + Build ID) with CRT dashboard link

**Job 10 — `rollback`**: Rollback Deployment
- Triggers on `workflow_dispatch` with `action=rollback`
- Input: `rollback_commit_sha` — the SHA to revert TO
- Uses `sfdx-git-delta` in reverse: new metadata treated as destructive
- Uses `--pre-destructive-changes` to delete new components before re-deploying prior state

---

## Waiver Files

### `.github/sf-scanner-waivers.csv`
CSV file on **main branch only**. The pipeline always fetches from main via GitHub API — PR branch copies are ignored. Schema:
```
rule,file_pattern,message_contains,severity_threshold,expiry,reason,approved_by,approved_date,ticket,status
ApexDoc,MyClass.cls,,3,10-05-2026,Reason here. Tracked in PROJ-123.,jane-techlead,10-04-2026,PROJ-123,ACTIVE
*,MyLegacyClass.cls,,3,10-05-2026,Global component waiver — rewrite in progress. Tracked in PROJ-999.,jane-techlead,10-04-2026,PROJ-999,ACTIVE
ApexDoc,*,,3,10-05-2026,Global rule waiver — ApexDoc deferred for sprint. Tracked in PROJ-998.,jane-techlead,10-04-2026,PROJ-998,ACTIVE
*,myLWCComponent,,3,10-05-2026,Global LWC component waiver — ESLint refactor in progress. Tracked in PROJ-997.,jane-techlead,10-04-2026,PROJ-997,ACTIVE
no-unused-vars,/lwc/,,3,10-05-2026,Global rule for all LWC files. Tracked in PROJ-996.,jane-techlead,10-04-2026,PROJ-996,ACTIVE
```

| Column | Required | Description |
|--------|----------|-------------|
| `rule` | ✅ | Rule name substring match. **Blank or `*` = global component waiver (waives ALL rules for that file/LWC).** |
| `file_pattern` | ✅ | Filename substring match (e.g. `MyClass.cls`, `myLWC`, `/lwc/`). **Blank or `*` = global rule waiver (waives this rule for ALL files).** |
| `message_contains` | ⬜ | Optional substring of violation message to narrow match |
| `severity_threshold` | ⬜ | Only waive at this severity or above (blank = any) |
| `expiry` | ✅ | DD-MM-YYYY preferred; also accepts DD/MM/YYYY and YYYY-MM-DD |
| `reason` | ✅ | Business justification with Jira reference |
| `approved_by` | ✅ | GitHub username of approver |
| `approved_date` | ✅ | Approval date |
| `ticket` | ✅ | Jira/GitHub issue ID |
| `status` | ✅ | `ACTIVE` or `REVOKED` (keep revoked rows for audit trail — never delete) |

Comment rows starting with `#` are ignored.

**Waiver types (determined by `rule` and `file_pattern` wildcards):**

| Type | `rule` | `file_pattern` | Effect | Log Label |
|------|--------|----------------|--------|-----------|
| Specific | `ApexDoc` | `MyClass.cls` | Waive ApexDoc for MyClass.cls only | `WAIVED` |
| Global Component | `*` or blank | `MyClass.cls` | Waive ALL rules for MyClass.cls | `GLOBAL COMPONENT WAIVER` |
| Global Rule | `ApexDoc` | `*` or blank | Waive ApexDoc for ALL files | `GLOBAL RULE WAIVER` |
| Global All | `*` or blank | `*` or blank | Waive ALL rules for ALL files ⚠️ | `GLOBAL ALL WAIVER` |
Status values: `WAIVED` (active, >30d), `WAIVED_EXPIRING_SOON` (≤30d), `VIOLATION` (no waiver), `EXPIRED_WAIVER` (past expiry — fails pipeline in enforce mode).
Results written to `sca-governance-report.csv` (includes Days_Left, Approved_Date columns).

### `.github/sca-waivers.json`
JSON array for npm audit waivers:
```json
{
  "package": "lodash",
  "severity": "high",
  "advisory": "GHSA-xxxx-xxxx-xxxx",
  "reason": "No fix available.",
  "expires": "YYYY-MM-DD",
  "approved_by": "platform-security"
}
```

---

## Required Secrets & Variables

| Secret/Variable | Type | Required | Default | Description |
|---|---|---|---|---|
| `CRT_UAT_AUTHURL` | Secret | ✅ | — | SFDX Auth URL for UAT org |
| `GH_PAT` | Secret | ✅ | — | Fine-Grained PAT with Variables: Read+Write |
| `CRT_API_TOKEN` | Secret | ✅ | — | CRT GraphQL API token (X-Authorization header) |
| `CX_CLIENT_SECRET` | Secret | ⬜ | — | Enables CheckMarx Job 5 |
| `FOD_CLIENT_SECRET` | Secret | ⬜ | — | Enables Fortify Job 6 |
| `DELTA_FROM_COMMIT` | Variable | ✅ | — | Baseline SHA (used for rollback reference + shallow-clone fallback) |
| `ORG_ALIAS` | Variable | ⬜ | `uat` | SF org alias |
| `COVERAGE_THRESHOLD` | Variable | ⬜ | `85` | Apex coverage % |
| `SCA_ENFORCEMENT_MODE` | Variable | ⬜ | `enforce` | `enforce` = expired waivers fail; `warn` = nothing fails; `off` = all SCA steps skipped |
| `CRT_JOB_ID` | Variable | ⬜ | `115686` | CRT job ID |
| `CRT_PROJECT_ID` | Variable | ⬜ | `73283` | CRT project ID |
| `CRT_ORG_ID` | Variable | ⬜ | `43532` | CRT org ID |

---

## Documentation Files (in `docs/`)

### `docs/pipeline-setup.md`
- All required secrets (with descriptions + how to create GH_PAT)
- All required variables (with defaults)
- Branch protection rules
- `pr_packages` branch description
- DELTA_FROM_COMMIT auto-update explanation
- No-delta skip behaviour table
- Quick start checklist

### `docs/sca-waivers.md`
- Part 1: SF Code Analyzer waivers (schema, governance, expiry policy, who updates, results CSV format)
- Part 2: npm SCA waivers (schema, governance)

### `docs/manual_runbook.md`
- PR review and deployment approver guide — PR review approval is the single human gate before deployment (no ReleaseGate)
- Rollback procedure: find SHA, trigger workflow_dispatch with action=rollback
- What rollback does (new metadata → destructive, modified → re-deployed, deleted → restored)

### `docs/troubleshooting.md`
- Common failures per job with diagnosis and fix

---

## Instructions
1. Read the existing workflow file at `.github/workflows/e2e-uat-pipeline.yml` first
2. Generate or update each file listed above
3. Preserve existing content in docs files — only add/update relevant sections
4. Ensure YAML is valid — quote strings with colons, 2-space indentation
5. Never use `--test-level NoTestRun` with `deploy validate` — omit the flag instead
6. Never combine `--async` and `--wait` on the same deploy command
7. Summarize what was created/updated and any required configuration
8. `SCA_ENFORCEMENT_MODE` must be documented in every relevant doc file. Set it to `off` to bypass all SCA steps during initial project phase, `warn` for informational-only, `enforce` (default) to fail on expired waivers.
