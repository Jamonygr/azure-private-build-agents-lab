# Ten guided exercises

[Wiki](../README.md) · [Book](../book.md)

Follow the exercises in order. Foundation actions run from the operator workstation; private data-plane actions run from your existing Windows host with the approved private route. The host must not occupy the pool's exclusively delegated subnet.

| # | Exercise | Execution location |
| --- | --- | --- |
| 1 | [Prerequisites, architecture, permissions and cost](01-prerequisites.md) | Workstation |
| 2 | [Deploy foundation and inspect local state](02-foundation.md) | Workstation |
| 3 | [Inspect identity and scoped RBAC](03-identity.md) | Workstation / private host |
| 4 | [Inspect Windows pool configuration and lifecycle](04-pool.md) | Workstation |
| 5 | [Prove private DNS and endpoints](05-private-access.md) | Private host |
| 6 | [Seed, revoke write and prove read access](06-secret-seed.md) | Both |
| 7 | [Private backend, apply and no-op verification](07-workload.md) | Private host |
| 8 | [Allowed/blocked outbound and Firewall evidence](08-egress.md) | Qualified private host |
| 9 | [DNS/RBAC recovery and deterministic locking](09-recovery-locking.md) | Both |
| 10 | [Ordered teardown and residual verification](10-cleanup.md) | Both |

## Session variables

On each host, open PowerShell 7.4+ in the matching repository root:

~~~powershell
$labId = 'pbalab'
$subscriptionId = '<your-subscription-guid>'
~~~

After export, read and compare the actual values:

~~~powershell
$c = Get-Content .local/lab-config.json -Raw | ConvertFrom-Json
if ($c.lab_id -ne $labId -or $c.subscription_id -ne $subscriptionId) {
    throw 'The export belongs to a different lab or subscription.'
}
~~~

The guides show expected observations. Record your actual results in the [workbook](../certifications/lab-workbook.md) and [validation status](../../docs/validation-status.md). No actual pool agent job is run by these exercises.
