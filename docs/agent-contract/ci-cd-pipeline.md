# Agent Contract: CI/CD Pipeline (Tasks 8.1-8.5)

## Spec Reference
- Primary: `openspec/changes/terraform-observability-stack/specs/ci-cd/terraform-pipeline/spec.md`
- Tasks: `openspec/changes/terraform-observability-stack/tasks.md` (Tasks 8.1-8.5)

## Permitted Files
**MUST ONLY MODIFY/CREATE THESE FILES:**
- `.github/workflows/terraform-ci.yml` (main CI workflow)
- `.github/workflows/terraform-drift.yml` (optional drift detection)
- `.github/dependabot.yml` (optional dependabot config)

**NEVER MODIFY:**
- Any spec files under `openspec/`
- Terraform files in `terraform/` (except if needed for workflow)
- Docker Compose files in `compose/`
- Application files in `compose/app/`

## Interface Contract

### Task 8.1: Terraform CI Workflow (fmt, validate, plan)
- Create `.github/workflows/terraform-ci.yml`
- Jobs: `fmt`, `validate`, `plan`
- Trigger: on push to main, pull requests to main
- Use `hashicorp/setup-terraform` action
- Cache Terraform plugins
- Run `terraform fmt -check` and `terraform validate` in `fmt` and `validate` jobs
- Run `terraform plan` in `plan` job (with AWS/GCP credentials via OIDC)
- Output plan to file for comment posting

### Task 8.2: Plan Comment Posting on PRs
- Add step in `plan` job to post plan as PR comment
- Use `github-script` or `thollender/terraform-comment` action
- Comment should include plan summary and link to full output
- Update existing comment on subsequent pushes (don't create duplicates)

### Task 8.3: Apply Job with Manual Approval Gate
- Add `apply` job that runs on merge to main (or manual dispatch)
- Use GitHub Environment `production` for approval gate
- Require manual approval before `terraform apply`
- Use `-auto-approve` flag only after approval
- Pass plan output from `plan` job to `apply` job

### Task 8.4: OIDC Authentication for AWS/GCP
- Configure OIDC for both AWS and GCP
- AWS: Use `aws-actions/configure-aws-credentials` with role ARN
- GCP: Use `google-github-actions/auth` with workload identity provider
- Use conditional logic based on `cloud_provider` variable
- No static credentials in repository

### Task 8.5: Scheduled Drift Detection (Optional)
- Create `.github/workflows/terraform-drift.yml`
- Schedule: daily or weekly (cron)
- Run `terraform plan` and check for drift
- Alert via GitHub Issue or PR comment if drift detected
- Use same OIDC authentication as main workflow

## Verification Commands
```bash
# YAML syntax validation
yamllint .github/workflows/terraform-ci.yml
yamllint .github/workflows/terraform-drift.yml

# GitHub Actions workflow validation (requires act or GitHub)
act -j fmt -j validate -j plan  # if act available

# Terraform fmt/validate in CI context
cd terraform && terraform fmt -check && terraform validate

# Check workflow syntax with actionlint (if available)
actionlint .github/workflows/terraform-ci.yml
```

## Definition of Done
- [ ] Task 8.1: terraform-ci.yml with fmt, validate, plan jobs
- [ ] Task 8.2: Plan comment posting on PRs
- [ ] Task 8.3: Apply job with manual approval (Environment)
- [ ] Task 8.4: OIDC authentication for AWS/GCP
- [ ] Task 8.5: Scheduled drift detection workflow (optional)
- [ ] All verification commands pass
- [ ] All files documented per code-doc-standard
- [ ] No secrets in code (OIDC only)

## Project Profile
**Type:** Pipeline/CI-CD
**Verification:** yamllint, actionlint, act (if available), terraform fmt/validate
**Skills:** github-actions-templates, deployment-pipeline-design, code-doc-standard, secrets-management

## Report Format
Return summary with:
1. Task completion status (8.1, 8.2, 8.3, 8.4, 8.5)
2. Command outputs proving verification passes
3. Any blockers
4. List of files created/modified