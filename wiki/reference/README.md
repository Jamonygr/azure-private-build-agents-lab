# Learning reference

[Wiki](../README.md) · [Operator reference](../../docs/reference.md)

## Terms

| Term | Meaning in this lab |
| --- | --- |
| Foundation | Shared resources and role assignments managed from the root |
| Workload | Independent sample managed from <code>workload/</code> |
| Private host | An existing operator-supplied Windows machine with the required path |
| Control plane | Azure resource management/configuration operations |
| Data plane | Blob and secret operations against service endpoints |
| State lock | A lease preventing concurrent conflicting state operations |
| Seed | One controlled synthetic-secret write |
| Evidence | A sanitized observed result with scope, source and timestamp |

## State and configuration

Foundation state is local; workload state is a private Blob. The export is nonsecret metadata, not a credential. It still identifies your resources, so share it deliberately.

The fixed baseline uses Terraform 1.16.4 and AzureRM 5.6.0. Change source pins, lockfiles, tests and documentation together.

## Evidence language

“Configured” means a resource setting was inspected. “Private-host verified” means that host's path passed. “Agent job verified” would require an actual pool job and is not provided by version 1. Use precise labels in demonstrations and reports.
