# 8 — Allowed and blocked outbound with Firewall evidence

[Previous](07-workload.md) · [Index](README.md) · [Next](09-recovery-locking.md)

**Location:** existing private host **whose tested outbound route uses the lab Firewall**. **Cloud writes:** diagnostic events only.

## Objective

Attribute an allow/deny result to a specific network path and Firewall rule.

## Preconditions

Review [egress](../../docs/egress.md), including its optional Azure CLI extension prerequisites. Missing <code>azure-firewall</code> or <code>log-analytics</code> causes INCOMPLETE; the helper does not install them. If the tester uses another default route, record this exercise as unverified for the lab Firewall until an authorized matching path exists. Do not put the host in the delegated pool subnet.

## Steps
Before running the egress command, set these values from the actual existing host and its Azure subnet. The helper verifies the subnet route to this Firewall, local source address and a matching deny log:

~~~powershell
$probeSubnetId = '<existing-non-MDP-subnet-resource-ID>'
$sourceIp = '<the-existing-host-private-IPv4-address>'
~~~

Without route inputs, the result is NOT_RUN. Without matching Firewall evidence, it is INCOMPLETE. Neither state is a pass.

1. Record the tester's address and routing context.

~~~powershell
Get-NetIPConfiguration
Get-NetRoute -AddressFamily IPv4 | Sort-Object RouteMetric | Select-Object DestinationPrefix, NextHop, InterfaceAlias, RouteMetric
Get-Date -AsUTC
~~~

2. Run the allowed/blocked probes.

~~~powershell
./scripts/Test-LabEgress.ps1 -ConfigPath .local/lab-config.json -Execute -ProbeSubnetId $probeSubnetId -SourceIp $sourceIp
~~~

3. Note the exact target, UTC test window, source IP and observed status.
4. Query the Firewall workspace using an operator with query permission.

~~~powershell
$c = Get-Content .local/lab-config.json -Raw | ConvertFrom-Json
$query = 'AZFWApplicationRule | where TimeGenerated > ago(30m) | project TimeGenerated, SourceIp, Fqdn, Action, RuleCollection, Rule | order by TimeGenerated desc'
az monitor log-analytics query --workspace $c.log_analytics_workspace_id --analytics-query $query --output table
~~~

5. Correlate the expected allowed and denied events. Use network-rule logs if necessary, as described in [monitoring](../../docs/monitoring.md).

## Expected observations

The allowed destination succeeds, the excluded destination is denied for the intended policy reason, and Firewall records match the tester/target/time. A timeout without correlation is inconclusive.

## Troubleshooting

Check ingestion delay, workspace, route and DNS before changing the allowlist. If the destination succeeds despite an intended deny, first prove that traffic used this Firewall. Do not add a wildcard merely because a tool needs another download endpoint.

## Cleanup and evidence

No rule change is needed. Save the correlated nonsecret events. Label the result **private-host Firewall path**, not Managed DevOps agent-job validation.
