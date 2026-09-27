# Cost model

[Home](../README.md) · [Cleanup](runbooks/cleanup.md)

The repository supplies **no invented monthly total**. Region, runtime, traffic and retention determine the bill. Model your planned session in the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) before deployment.

| Driver | What to inspect |
| --- | --- |
| Firewall Standard | Provisioned time and traffic processing; it remains present with zero active agents |
| Managed DevOps Pools | Active compute, image/SKU and current service charging |
| Private endpoints | Provisioned endpoint time and traffic |
| Blob storage | State versions, diagnostics, transactions and retained data |
| Log Analytics | Ingestion volume and retention |
| Networking | Firewall IP, outbound data and applicable regional transfer |
| Existing private host | Your own host/connectivity costs, outside this deployment |

Zero standby reduces idle agent compute. It does not make the foundation free. A one-agent limit bounds concurrency, not total spend.

## Session checklist

1. Choose a region and confirm current service/SKU availability.
2. Estimate setup, exercises, failure diagnosis and cleanup time.
3. Record an owner and a cleanup deadline.
4. Retain only compact sanitized evidence.
5. Verify resource absence after teardown.
6. Review actual cost later, allowing for billing-data delay.

Budgets are notifications rather than a guaranteed stop mechanism. Ordered teardown is the primary cost control demonstrated here.

Record deployment start, last test, workload deletion and foundation cleanup times. Explain later differences such as retained logs/storage or a Firewall left deployed.
