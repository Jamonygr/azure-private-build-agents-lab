# Synthetic secret seed and write revocation

[Home](../../README.md) · [Exercise 6](../../wiki/exercises/06-secret-seed.md)

Purpose: create one disposable training secret without a permanent write grant or putting its value in Terraform state.

## Preconditions

- Foundation exists; public access remains disabled.
- Existing private Windows host passes DNS/endpoint checks.
- Signed-in identity matches the configured operator principal.
- No unrelated inherited secret-write role makes the negative test meaningless.

## Procedure

On the foundation workstation:

1. Set <code>enable_secret_seed = true</code> in the local variable file.
2. Plan and inspect the temporary role change.
3. Apply and export configuration.
4. Transfer the updated nonsecret export to the private host.

~~~powershell
./scripts/Invoke-Lab.ps1 -Action Plan -LabId $labId -SubscriptionId $subscriptionId -Execute
./scripts/Invoke-Lab.ps1 -Action Apply -LabId $labId -SubscriptionId $subscriptionId -Execute
./scripts/Invoke-Lab.ps1 -Action Export -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

On the private host:

~~~powershell
./scripts/Seed-LabSecret.ps1 -ConfigPath .local/lab-config.json -Execute -Confirmation "SEED $labId"
~~~

The helper creates the synthetic <code>lab-validation</code> secret. Do not print or preserve its value.

Immediately return to the foundation workstation, set <code>enable_secret_seed = false</code>, then plan/apply/export again. Refresh the private host's export.

~~~powershell
./scripts/Invoke-Lab.ps1 -Action VerifySeedRevoked -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

On the private host:

~~~powershell
./scripts/Test-LabPrivateAccess.ps1 -ConfigPath .local/lab-config.json -Execute
~~~

## Acceptance

The temporary grant is absent, the synthetic secret remains readable, and secret write is denied. If effective write still exists, investigate inherited roles and bounded propagation before declaring success.

## If interrupted

Restore <code>enable_secret_seed = false</code> as the first recovery action, apply the reviewed revocation, and verify it. Do not leave bootstrap enabled because a later exercise is unfinished. The synthetic secret is removed with the lab vault during ordered cleanup.
