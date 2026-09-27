# Validation strategy

[Home](../README.md) · [Status](validation-status.md) · [Exercises](../wiki/exercises/README.md)

## Evidence layers

| Layer | What it proves | What it does not prove |
| --- | --- | --- |
| Offline source checks | Formatting, structure, contracts and documented invariants | Azure deployment success |
| Foundation control plane | Resources, policy and pool configuration | An agent has started or a job has run |
| Existing private-host checks | That host's DNS, network path and operator authorization | The Managed DevOps agent's runtime path |
| Workload checks | Private backend, controlled deployment and state locking | Build-job integration |
| Cleanup | Absence of expected lab resources and retained recovery evidence | Absence of unrelated account charges |

Actual pool job execution remains outside version 1.

## Offline checks

From the repository root:

~~~powershell
./scripts/offline-validation.ps1 -RequireAllTools
~~~

Use <code>-TerraformPath</code> if your Terraform binary is not on PATH. A missing required tool is a missing check, not a pass. Review the helper's summary and keep the command/commit with the result.

Here, offline means source validation without Azure credentials or Azure resource operations. A fresh machine can still need vendor-network access for pinned dependencies. The helper does not install quality tools automatically; their versions are listed in <code>toolchain.json</code>.

The repository validator checks documentation and repository contracts:

~~~powershell
python tools/validate_repository.py --check
# Add --anchors to validate local heading fragments.
~~~

Run relevant Terraform mocked contracts, script tests, lint/security checks and documentation checks when changing their behavior. Do not treat a generated reference as an integration test.

## Live sequence

1. Foundation preflight and reviewed apply from the operator workstation.
2. Public-access posture and pool configuration inspection.
3. Identity/scope validation on the existing private Windows host.
4. DNS and private endpoint checks before seeding.
5. Temporary synthetic-secret seed, grant removal and negative write test.
6. Workload plan/apply and no-op result.
7. Allowed/blocked outbound probes correlated with Firewall logs.
8. Deterministic lease-conflict test and controlled failure recovery.
9. Workload destroy and empty-group verification.
10. Foundation destroy and residual verification.

No automated live deployment is started by offline tests.

## Private-host commands
Before running the egress command, set these values from the actual existing host and its Azure subnet. The helper verifies the subnet route to this Firewall, local source address and a matching deny log:

~~~powershell
$probeSubnetId = '<existing-non-MDP-subnet-resource-ID>'
$sourceIp = '<the-existing-host-private-IPv4-address>'
~~~

Without route inputs, the result is NOT_RUN. Without matching Firewall evidence, it is INCOMPLETE. Neither state is a pass.

~~~powershell
./scripts/Test-LabPrivateAccess.ps1 -ConfigPath .local/lab-config.json -Execute -SkipSecretTests
./scripts/Seed-LabSecret.ps1 -ConfigPath .local/lab-config.json -Execute -Confirmation "SEED $labId"
./scripts/Test-LabPrivateAccess.ps1 -ConfigPath .local/lab-config.json -Execute
./scripts/Test-LabEgress.ps1 -ConfigPath .local/lab-config.json -Execute -ProbeSubnetId $probeSubnetId -SourceIp $sourceIp
./scripts/Test-LabStateLock.ps1 -ConfigPath .local/lab-config.json -Execute
~~~

Seed only after enabling the temporary foundation flag; normal full private-access validation happens after revoking it. Do not run these commands as a broad administrator and call the result a least-privilege proof.


## External public-endpoint denial test

Use a separate **public-network operator context**, which can be the workstation only when it resolves and reaches the public service path. The lab does not deploy another host.

After seeding and revoking temporary write, create fresh private positive evidence on the existing private host:

~~~powershell
./scripts/Test-LabPrivateAccess.ps1 -ConfigPath .local/lab-config.json -Execute -EvidencePath .local/private-access.json
~~~

Do not use <code>-SkipSecretTests</code>. The evidence binds the lab, subscription, tenant, operator, exact storage/container/vault, private DNS results and successful Blob/secret reads. It must be no more than 24 hours old.

Transfer only nonsecret configuration/evidence to the public-network context. Sign in as the **same operator**:

~~~powershell
./scripts/Test-LabPublicAccess.ps1 -ConfigPath .local/lab-config.json -PrivateEvidencePath .local/private-access.json -EvidencePath .local/public-access.json -Execute
~~~

The public probe is deliberately IPv4-only: it conservatively rejects IPv6 DNS responses as well as private/reserved IPv4 addresses. An IPv6-only or mixed answer is unsupported/incomplete, not a security pass.

Expected: public-only DNS and authenticated HTTP 403 responses with the required service-specific network-denial codes. Timeout, expired credential or unrelated RBAC rejection is not a pass. If the host still uses a private path, use an authorized public-network context; do not weaken service configuration.

<code>Invoke-Lab -Action ValidatePublicAccess</code> without private evidence reports **CONFIGURATION_ONLY** and external probes **NOT_RUN**. It also accepts <code>-PrivateEvidencePath</code>/<code>-EvidencePath</code> for an actual external probe from the correct context.

## Record useful evidence

For each test capture the location, authenticated principal, commit, UTC time, command, expected result, observed result and cleanup outcome. Keep nonsecret summaries in ignored <code>.local/evidence/</code>. Update [status](validation-status.md) without copying tokens, secret values, state or plans.

A failed cleanup is a failed live run even when the functional checks passed.
