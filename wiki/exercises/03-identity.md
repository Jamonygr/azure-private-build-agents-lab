# 3 — Inspect operator identity and scoped RBAC

[Previous](02-foundation.md) · [Index](README.md) · [Next](04-pool.md)

**Location:** workstation, then existing private host. **Cloud writes:** none.

## Objective

Distinguish the operator, pool identity and service principal, then prove which principal the private tests will use.

## Steps

1. Inspect the nonsecret identity contract.

~~~powershell
$c = Get-Content .local/lab-config.json -Raw | ConvertFrom-Json
$c | Select-Object operator_principal_id, agent_identity_client_id, agent_identity_principal_id
az role assignment list --assignee $c.operator_principal_id --all --include-inherited --output table
~~~

2. Locate the state-container Blob data grant, vault Secrets User grant, and Contributor grant on the sample group. Inspect inherited rights too.
3. Inspect the pool managed identity separately.

~~~powershell
az role assignment list --assignee $c.agent_identity_principal_id --all --include-inherited --output table
~~~

4. On the existing private host, sign in and compare scope.

~~~powershell
az login
az account set --subscription $c.subscription_id
az account show --query '{subscription:id,tenant:tenantId}' --output table
az ad signed-in-user show --query id --output tsv
~~~

5. Record why a Contributor grant on an existing resource group does not authorize creating another group.

## Expected observations

The actual private-host principal matches <code>operator_principal_id</code>. The pool identity has no assumed workload data roles. The DevOps infrastructure service principal's network permissions are separate from both.

If the operator inherits broad rights, document them. Later negative tests must not be described as scoped-role proofs unless those effective permissions allow the test to be meaningful.

## Troubleshooting

Wrong tenant/principal errors require selecting the correct identity, not editing the export to fit the current login. A data-plane role can take time to propagate; inspect assignment scope before waiting.

## Cleanup and evidence

No grants are changed in this exercise. Retain a sanitized table of actor, role and scope.
