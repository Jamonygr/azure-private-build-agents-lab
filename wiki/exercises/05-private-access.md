# 5 — Prove private DNS and endpoints

[Previous](04-pool.md) · [Index](README.md) · [Next](06-secret-seed.md)

**Location:** existing private-connected Windows host. **Cloud writes:** none.

## Preconditions

The host is outside the exclusive pool subnet and has a real route/DNS path to the private services. Source and exported configuration match the deployed foundation.

## Steps

1. Check identity and scope as in Exercise 3.
2. Resolve normal service hostnames.

~~~powershell
$c = Get-Content .local/lab-config.json -Raw | ConvertFrom-Json
$blobHost = "$($c.state_storage_account_name).blob.core.windows.net"
$vaultHost = "$($c.key_vault_name).vault.azure.net"
Resolve-DnsName $blobHost -Type A
Resolve-DnsName $vaultHost -Type A
$c | Select-Object blob_private_ip, vault_private_ip
~~~

3. Compare the final A records with the exported endpoint addresses.
4. Test the private TLS path.

~~~powershell
Test-NetConnection $blobHost -Port 443 -InformationLevel Detailed
Test-NetConnection $vaultHost -Port 443 -InformationLevel Detailed
~~~

5. Run the helper without secret tests because the synthetic secret has not yet been created.

~~~powershell
./scripts/Test-LabPrivateAccess.ps1 -ConfigPath .local/lab-config.json -Execute -SkipSecretTests
~~~

6. From the foundation workstation, reconfirm private public-access posture.

~~~powershell
./scripts/Invoke-Lab.ps1 -Action ValidatePublicAccess -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

The final command inspects configuration only at this point. It reports external probes NOT_RUN without fresh private evidence. Complete the actual public-network denial test after Exercise 6, when both private Blob and secret reads can be proven.

## Expected observations

Names resolve to the intended private addresses, TCP/TLS access succeeds where required, and authorized Blob operations pass. This is evidence for **this host**. The pool agent's runtime path remains untested.

## Troubleshooting

Public A records indicate a resolver/zone path issue. Correct private IP with failed connection indicates routing/endpoint/security investigation. A 403 with working TLS calls for identity/data-role inspection. Never open the public service endpoint to repair these checks.

## Cleanup and evidence

No infrastructure change is needed. Save the hostname/address comparison and sanitized helper result, not tokens or state content.
