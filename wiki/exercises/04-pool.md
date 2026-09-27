# 4 — Inspect Windows pool configuration and lifecycle

[Previous](03-identity.md) · [Index](README.md) · [Next](05-private-access.md)

**Location:** operator workstation. **Cloud writes:** none.

## Objective

Inspect the managed pool's intended runtime configuration without claiming that an agent job has run.

## Steps

1. Inspect the pool resource.

~~~powershell
$c = Get-Content .local/lab-config.json -Raw | ConvertFrom-Json
az resource show --resource-group $c.foundation_resource_group_name --name $c.pool_name --resource-type Microsoft.DevOpsInfrastructure/pools --query '{state:properties.provisioningState,max:properties.maximumConcurrency,fabric:properties.fabricProfile,agents:properties.agentProfile}' --output json
~~~

2. Locate the selected image, VM SKU, delegated subnet, concurrency and standby configuration.
3. In Azure, inspect provisioning state and service errors. In the existing DevOps project, inspect the corresponding pool registration if your role permits.
4. Record whether any actual agent exists. Do not queue a job as part of this version.

## Expected observations

Configuration refers to <code>windows-2025-g2</code>, <code>Standard_D2ads_v5</code>, one maximum concurrent agent and zero standby. No warm agent is promised. An idle pool may have no running compute.

The delegated subnet is dedicated to Managed DevOps Pools. Your validation host belongs elsewhere.

## Troubleshooting

A successful resource deployment does not prove image boot, installed tools or job networking. An unavailable SKU, quota shortage or project permission error is a provisioning issue to resolve before claiming the pool is ready.

Refer to current [image](https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/configure-images?view=azure-devops) and [scaling](https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/configure-scaling?view=azure-devops) guidance when interpreting configuration.

## Cleanup and evidence

No resources are changed. Record **pool configuration inspected; actual agent job not run**.
