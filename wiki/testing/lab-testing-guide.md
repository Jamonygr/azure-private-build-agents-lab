# Testing the lab as a learner

[Wiki](../README.md) · [Operator strategy](../../docs/testing.md)

For each exercise, keep a five-part record:

1. **Context:** commit, UTC time, lab ID, source host and signed-in principal.
2. **Expectation:** the specific result that would establish the claim.
3. **Observation:** the actual output or sanitized screenshot.
4. **Interpretation:** what the result proves and what remains untested.
5. **Cleanup:** resource/configuration restoration or final removal.

A source check can pass while live prerequisites remain unavailable. A private DNS result can pass while RBAC fails. A host can reach a denied-test destination without traversing the lab Firewall. Separate these results rather than collapsing them into one green check.

Use the [validation status](../../docs/validation-status.md) page to record the repository's actual validation level.
