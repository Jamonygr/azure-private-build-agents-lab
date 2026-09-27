# Instructor workbook

[Wiki](../README.md) · [Exercises](../exercises/README.md)

This is a practical infrastructure curriculum. It is not a promise of complete coverage for a certification exam.

## Suggested teaching format

Before class, the instructor verifies service availability, permissions, private-host access and the cost/cleanup plan. Learners should complete offline checks and scope identification before live deployment. Provisioning time varies; prepare discussion questions while Azure operations complete.

| Exercise | Learner evidence | Discussion |
| --- | --- | --- |
| 1 | Correct scope, tools and cost drivers | Why is a subscription ID insufficient without a tenant/principal? |
| 2 | Plan, local state inventory and resource inventory | Why keep foundation state independent? |
| 3 | Exact role scopes and authenticated principal | Why do management and data-plane roles differ? |
| 4 | Pool image, subnet, capacity and lifecycle settings | Why can zero active agents be correct? |
| 5 | Private addresses and successful endpoint checks | What does a DNS result fail to prove? |
| 6 | Seed, role removal, read success and write denial | How can inherited roles defeat the negative test? |
| 7 | Apply, outputs and no-op verification | Why does the sample not own its group? |
| 8 | Probe/time/source correlated with Firewall logs | What if the tester bypasses the Firewall? |
| 9 | Controlled failure, restoration and lease conflict | Why is force-unlock dangerous? |
| 10 | Empty sample group and foundation residual checks | When is cleanup complete? |

## Completion criteria

The learner explains the trust and ownership boundaries, executes only tests supported by their environment, records limitations honestly, restores every injected fault, and verifies ordered cleanup. Actual Managed DevOps job execution remains untested in this version.

Do not grade by the absence of errors alone. A learner who identifies an inherited role or an incorrect tester route has found a meaningful defect in the experiment.
