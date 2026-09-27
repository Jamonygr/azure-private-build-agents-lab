# Infrastructure guardrails

`guardrails.rego` evaluates Terraform plan JSON. Tests include safe fixtures and deliberately unsafe network, authorization, and capacity changes.

```powershell
conftest verify --policy policies
conftest test policies/fixtures/allowed.json --policy policies
```

The offline gate runs these fixtures; it does not claim to evaluate a live Azure plan. To check an operator-created plan, keep its JSON only under the ignored `.local` directory, run `conftest test` against it, and remove that JSON afterward. Do not publish raw plans or state as evidence.

Deletion-only changes are permitted by these configuration policies. Destructive ownership and teardown ordering are enforced by the operator wrappers and their tests. An explicit seed grant is accepted only when `enable_secret_seed` is true; remove it after seeding.

Missing or unknown Storage, vault and pool security settings fail validation. An RBAC scope that Terraform cannot yet resolve produces a warning: it has **not** passed scope verification. Review those references and verify the actual assignments after deployment; use `--fail-on-warn` when requiring fully resolved policy evidence. The focused rules do not replace the mocked Terraform contracts or permission checks.
