# Monitoring and evidence

[Home](../README.md) · [Egress](egress.md) · [Testing](testing.md)

| Question | Evidence |
| --- | --- |
| Was the intended pool configured? | Resource configuration: image, SKU, subnet and maximum capacity |
| Did private DNS work on the tester? | Hostname, expected endpoint address and actual A record |
| Did operator authorization work? | Scoped principal, operation and result; no tokens |
| Did tested egress use the Firewall? | Source IP, route evidence, target, time and matching rule event |
| Did state locking work? | Known held lease, rejected competing operation and confirmed release |
| Did cleanup finish? | Empty workload group followed by foundation residual checks |

## Query Firewall diagnostics

From an authenticated operator context with workspace query rights:

~~~powershell
$c = Get-Content .local/lab-config.json -Raw | ConvertFrom-Json
$query = 'AZFWApplicationRule | where TimeGenerated > ago(30m) | project TimeGenerated, SourceIp, Fqdn, Action, RuleCollection, Rule | order by TimeGenerated desc'
az monitor log-analytics query --workspace $c.log_analytics_workspace_id --analytics-query $query --output table
~~~

For network-rule events:

~~~kusto
AZFWNetworkRule
| where TimeGenerated > ago(30m)
| project TimeGenerated, SourceIp, DestinationIp, DestinationPort, Action
| order by TimeGenerated desc
~~~

Inspect the actual deployed diagnostic table/schema. Missing records can mean ingestion delay, the wrong workspace/time window, or traffic that never used the Firewall. Missing records do not prove enforcement.

## Evidence hygiene

Keep UTC time, lab ID, source commit, source host/IP, test and observed result. Do not collect unrestricted environment dumps, Key Vault values, raw state/plans, access tokens or authorization headers.

Use ignored local evidence or a restricted evidence store. Record only safe summaries in [validation status](validation-status.md). Preserve the difference between control-plane, private-host and actual-agent evidence.
