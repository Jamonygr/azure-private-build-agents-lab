# Troubleshooting

[Home](../README.md) · [Recovery runbook](runbooks/recovery.md)

Diagnose one layer at a time: scope → identity → resource configuration → DNS → route → TLS → authorization → Terraform behavior.

| Symptom | Check | Recovery |
| --- | --- | --- |
| Pool creation fails | Region/SKU/quota, project rights, delegated subnet and service principal permissions | Correct the prerequisite; regenerate the foundation plan |
| Pool has no active agent | Zero standby is intentional; no job is queued by this lab | Validate resource configuration only; record actual agent execution not run |
| Private name returns public IP | Tester resolver path, private zone link and endpoint record | Repair DNS path; never enable public target access |
| Name resolves correctly but TLS fails | Endpoint approval, host route and security rules | Repair routing/endpoint state; retest the same hostname |
| Blob operation is forbidden | Signed-in principal, container data role, selected tenant/subscription | Correct the scoped grant; allow bounded propagation |
| Key Vault read fails before seed | Synthetic secret has not been created | Perform the controlled seed exercise |
| Secret write still succeeds after revocation | Inherited roles, stale tokens, actual principal and propagation | Inspect effective rights and retest; do not claim read-only yet |
| Workload cannot create resource group | Workload is trying to own the foundation's precreated group | Correct the root/configuration; do not grant subscription Contributor |
| Backend init fails from workstation | Workstation lacks private DNS/network path | Use the existing authorized private host |
| Terraform reports a lock | Another operation or deliberate lease test owns it | Verify owner and wait/release only your known test lease |
| Blocked egress has no Firewall event | Tester may bypass the Firewall or logs may lag | Prove route/source and correlate later; do not assume a deny |
| Foundation destroy refuses | Sample group contains resources | Destroy/verify workload first, then retry foundation |
| Plan rejected after input/source change | Saved plan metadata no longer matches | Review and create a fresh plan |

## Useful scope checks

~~~powershell
$c = Get-Content .local/lab-config.json -Raw | ConvertFrom-Json
az account show --query '{subscription:id,tenant:tenantId}' --output table
az resource list --resource-group $c.foundation_resource_group_name --query '[].{name:name,type:type}' --output table
az resource list --resource-group $c.workload_resource_group_name --query '[].{name:name,type:type}' --output table
~~~

Management-plane inventory does not prove data-plane reachability.

## When to stop

Stop a mutation if the subscription, tenant, principal or resource ownership is wrong. Preserve the nonsecret error and reviewed state location. Do not delete state to clear an error, overwrite a backend key, force-unlock an unknown lease, or broaden network access as a troubleshooting shortcut.
