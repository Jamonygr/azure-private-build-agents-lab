# Contributing

Keep this repository a focused, operator-driven Azure infrastructure lab. It contains no pipeline definitions or setup guide; actual pool job execution remains outside version 1.

## Before a change

Read [architecture](wiki/architecture/overview.md), [testing](docs/testing.md), [security](SECURITY.md) and the relevant exercise. Use a dedicated branch and preserve unrelated work.

## Local validation

~~~powershell
./scripts/offline-validation.ps1 -RequireAllTools
python tools/validate_repository.py --check
~~~

Use Terraform 1.16.4 and the committed AzureRM 5.6.0 lock baseline. A version upgrade must include lockfiles, compatibility evidence and updated references. Run source checks without an Azure login; live actions must remain explicit.

## Change expectations

- Keep foundation and workload ownership separate.
- Keep state paths scoped to the lab, with private workload backend access through Microsoft Entra.
- Preserve public-access denial throughout bootstrap.
- Preserve temporary seed write, removal and negative testing.
- Keep identity/scope guards and saved-plan binding.
- Add meaningful behavior tests for permissions, destructive guards and failure recovery.
- Never add a blanket security scanner exception to silence a real finding.
- Keep cost, version and service availability claims dated or linked to primary documentation.
- Preserve the distinction between source validation, private-host evidence and actual agent execution.

## Documentation

Update commands, expected observations, troubleshooting and cleanup together. Keep relative links working. SVGs need accessible title/description and readable labels. Generated Terraform references must be refreshed with the source change; do not hand-edit generated tables.

## Pull request content

Explain the user outcome, changed ownership/permissions, validation actually performed, and any untested live behavior. Never commit local state, binary plans, exported credentials, tokens, secret values or the ignored local working directory.

Live tests create billable resources. Record their cleanup result; a functional pass with unfinished deletion is incomplete work.
