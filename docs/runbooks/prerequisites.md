# Prerequisite verification runbook

[Setup](../setup.md) · [Exercise 1](../../wiki/exercises/01-prerequisites.md)

These checks inspect existing permissions and identity records. They do not create service principals, register providers, grant roles or configure jobs.

## 1. Verify the signed-in operator

~~~powershell
$account = az account show --output json | ConvertFrom-Json
$account | Select-Object id, tenantId, name
$operatorPrincipalId = az ad signed-in-user show --query id --output tsv
$operatorPrincipalId
az role assignment list --assignee $operatorPrincipalId --scope "/subscriptions/$subscriptionId" --include-inherited --all --output table
~~~

The signed-in user command applies to an interactive user login. For a different authorized principal, inspect its corresponding identity record instead. Compare the actual object ID with the configured operator principal.

## 2. Discover the service principal without guessing

~~~powershell
az ad sp list --display-name DevOpsInfrastructure --query '[].{name:displayName,objectId:id,appId:appId,ownerTenant:appOwnerOrganizationId,verifiedPublisher:verifiedPublisher.displayName}' --output table
$candidates = @(az ad sp list --display-name DevOpsInfrastructure --output json | ConvertFrom-Json)
$exact = @($candidates | Where-Object { $_.displayName -ceq 'DevOpsInfrastructure' })
if ($exact.Count -ne 1) {
    throw 'Expected exactly one verified DevOpsInfrastructure application. Ask the tenant administrator to resolve missing or ambiguous records.'
}
$exact | Select-Object displayName, id, appId, appOwnerOrganizationId, verifiedPublisher
~~~

**Do not select by display name alone.** In Microsoft Entra enterprise applications, have the tenant administrator verify that this record is the Microsoft first-party application used by Managed DevOps Pools, including its application ID, owner tenant and publisher details against the trusted service record. Publisher metadata alone is not a substitute for that verification.

After verification, copy its tenant-specific **object ID** into <code>devops_infrastructure_principal_id</code>. Do not copy the application/client ID. No universal application GUID is prescribed here; the repository never silently picks a candidate or creates one when none exists.

Microsoft documents the service principal's VNet permissions in [Managed DevOps Pools networking](https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/configure-networking?view=azure-devops).

## 3. Review effective Azure authorization manually

The foundation creates resource groups, network/Firewall resources, managed identities, Dev Center resources, the pool, private services, diagnostics and role assignments. A pool-only role does not cover the entire foundation.

Inspect actual role definitions when custom roles, conditions or PIM are involved:

~~~powershell
az role definition list --name '<an-actual-assigned-role-name>' --query '[].{name:roleName,permissions:permissions}' --output json
~~~

Record whether the operator can:

- Create/update/delete the foundation resources and resource groups at the intended scope.
- Create/delete the lab's role assignments, including any assignment conditions.
- Assign the pool managed identity and establish the service's VNet permissions.
- Read diagnostic data needed by the manual evidence exercises.

Use the Azure portal's **Access control (IAM) → Check access** view with the exact principal and target scope. Check deny assignments, active PIM state and conditions with the scope administrator. A role listing alone does not prove all operations are permitted.

Do not grant a broader role just to bypass a failed check. Resolve the precise required permission with the authorized administrator.

## 4. Review Azure DevOps membership and pool permissions

The Azure DevOps organization must be connected to Microsoft Entra ID. Verify the operator belongs to the required tenants and is a member of the organization and existing project.

In **Project settings → Agent pools → Security**, verify Administrator or Creator permission for creation. For an existing pool update, also inspect its organization-level pool security; updates can require Administrator there. Record the effective user/group and ask the project/pool administrator to resolve any missing permission.

This is prerequisite inspection only. There is no pipeline or service-connection setup in this version. See the current [Microsoft prerequisites](https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/prerequisites?view=azure-devops).

## 5. Interpret automated preflight correctly

~~~powershell
./scripts/Invoke-Lab.ps1 -Action Preflight -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

The live helper checks selected subscription, required provider registrations, advertised Managed DevOps Pools region, unrestricted <code>Standard_D2ads_v5</code>, and at least two available family vCPUs.

Effective deployment/RBAC authorization and Azure DevOps permissions remain **NOT_RUN** by that helper. Complete the manual checks above and record them separately before a live apply. Capacity can change after preflight; this is not a capacity reservation or a guarantee of deployment success.

## Evidence

Keep a sanitized record of scope, principal, verified service-principal object ID, manual permission findings, and preflight output. Record unknowns as unresolved. Do not retain access tokens or directory exports containing unrelated personal information.
