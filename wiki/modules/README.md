# Module responsibilities

[Wiki](../README.md) · [Architecture](../architecture/overview.md)

Use the generated module references for exact variables and outputs. This page explains what each responsibility means.

| Responsibility | Teaching focus |
| --- | --- |
| Network | Dedicated delegated pool subnet, endpoint subnet, routes and address boundaries |
| Firewall | Explicit outbound policy and DNS proxy |
| Private services | Blob state, Key Vault, private endpoints and linked zones |
| Identity | Operator data-plane scopes, pool identity and service network permissions |
| Pool | Image, SKU, region, one maximum agent and zero standby |
| Monitoring | Diagnostic flow and evidence needed to attribute allow/deny results |
| Sample workload | Small independently managed resources in a precreated group |

A module should expose useful IDs and ownership boundaries rather than force a caller to reconstruct resource names. The export contract connects those module outputs to operator tools.

When changing a module, update its mocked behavior tests and generated reference. Live tests remain a separate evidence level.
