# Operator reference

[Home](../README.md) · [Testing](testing.md)

| Item | Baseline |
| --- | --- |
| Foundation / workload roots | Repository root / <code>workload/</code> |
| Terraform / AzureRM | <code>1.16.4</code> / <code>5.6.0</code> |
| Image / SKU | <code>windows-2025-g2</code> / <code>Standard_D2ads_v5</code> |
| Capacity | One maximum, zero standby |
| Network | <code>10.60.0.0/16</code>, Firewall Standard DNS proxy |
| Inputs / export | <code>.local/lab.tfvars</code> / <code>.local/lab-config.json</code> |
| Foundation state | <code>.local/state/foundation-&lt;lab-id&gt;.tfstate</code> |
| Synthetic secret | <code>lab-validation</code> |

## Foundation helper

Use <code>scripts/Invoke-Lab.ps1 -Action &lt;action&gt; -LabId &lt;id&gt; -SubscriptionId &lt;guid&gt;</code>, optionally with <code>-VarFile</code>, <code>-ConfigPath</code>, <code>-Execute</code> and <code>-Confirmation</code>.

| Action | Purpose |
| --- | --- |
| Preflight | Tool/input checks; live prerequisites when executing |
| Plan | Reviewed foundation plan and metadata |
| Apply | Apply matching reviewed plan |
| Export | Nonsecret configuration |
| ValidatePublicAccess | Private target public-access posture |
| VerifySeedRevoked | Temporary write-grant removal |
| Destroy | Foundation teardown; confirmation <code>DESTROY &lt;lab-id&gt;</code> |
| VerifyCleanup | Foundation residual inspection |

ValidatePublicAccess also accepts <code>-PrivateEvidencePath</code> and <code>-EvidencePath</code> for the [authenticated external negative test](testing.md#external-public-endpoint-denial-test). Without private evidence it checks configuration only.

Preview mode is not live validation. The helper refuses foundation teardown while the sample resource group remains nonempty.

## Export object

~~~powershell
$c = Get-Content .local/lab-config.json -Raw | ConvertFrom-Json
$c | Select-Object lab_id, subscription_id, tenant_id, pool_name, operator_principal_id
~~~

The flat object includes:

- Scope: <code>lab_id</code>, <code>subscription_id</code>, <code>tenant_id</code>, <code>location</code>.
- Ownership: <code>foundation_resource_group_name</code>, <code>workload_resource_group_name</code>.
- Pool: <code>pool_name</code>, <code>azure_devops_organization_url</code>, <code>azure_devops_project_name</code>.
- Identity: <code>operator_principal_id</code>, <code>agent_identity_client_id</code>, <code>agent_identity_principal_id</code>.
- State: <code>state_storage_account_name</code>, <code>state_container_name</code>, <code>state_key</code>.
- Vault: <code>key_vault_name</code>, <code>key_vault_uri</code>, <code>bootstrap_secret_write_enabled</code>.
- Diagnostics/network: <code>blob_private_ip</code>, <code>vault_private_ip</code>, <code>firewall_resource_id</code>, <code>log_analytics_workspace_id</code>, <code>workload_vnet_cidr</code>.

The workspace field is the Log Analytics GUID for query operations. Regenerate this object instead of redirecting values manually to unrelated resources.

## Authority

Terraform references define input/output contracts. PowerShell parameters define command contracts. Tests describe expected behavior. Update these documents alongside implementation changes.
