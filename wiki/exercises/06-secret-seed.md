# 6 — Seed a synthetic secret, revoke write, prove read

[Previous](05-private-access.md) · [Index](README.md) · [Next](07-workload.md)

**Location:** both hosts. **Cloud writes:** temporary role and one synthetic secret.

## Objective

Demonstrate a bootstrap write that does not become a permanent capability.

## Steps

1. On the foundation workstation, set <code>enable_secret_seed = true</code> in the local variable file.
2. Plan, review the temporary vault grant, apply and export.

~~~powershell
./scripts/Invoke-Lab.ps1 -Action Plan -LabId $labId -SubscriptionId $subscriptionId -Execute
./scripts/Invoke-Lab.ps1 -Action Apply -LabId $labId -SubscriptionId $subscriptionId -Execute
./scripts/Invoke-Lab.ps1 -Action Export -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

3. Transfer the updated nonsecret export to the existing private host, then seed.

~~~powershell
./scripts/Seed-LabSecret.ps1 -ConfigPath .local/lab-config.json -Execute -Confirmation "SEED $labId"
~~~

4. On the foundation workstation, set <code>enable_secret_seed = false</code>. Repeat plan/apply/export. Transfer the refreshed export.
5. Verify revocation locally, then private access on the host.

~~~powershell
./scripts/Invoke-Lab.ps1 -Action VerifySeedRevoked -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

~~~powershell
./scripts/Test-LabPrivateAccess.ps1 -ConfigPath .local/lab-config.json -Execute -EvidencePath .local/private-access.json
~~~

6. Complete the [external denial test](../../docs/testing.md#external-public-endpoint-denial-test) from a public-network context using the same operator and this evidence (maximum age 24 hours). It checks public-only DNS and precise service network-denial responses; timeouts and unrelated RBAC failures do not count.

## Expected observations

The <code>lab-validation</code> secret is readable without printing its value. The seed-write grant is absent and the negative write test is denied. Both management-plane grant removal and data-plane behavior matter.

## Troubleshooting

If writes still succeed, inspect inherited roles and principal identity. Allow bounded propagation time and refresh the authorized session where appropriate. Record the failed negative test until denial is actually observed.

## Cleanup and evidence

Leave <code>enable_secret_seed = false</code>. An interrupted session must prioritize revoking the temporary grant. Do not delete the synthetic secret yet; later read tests need it. [Seed recovery runbook](../../docs/runbooks/secret-seed.md).
