# Security policy

This repository is a disposable learning environment. It demonstrates specific Azure boundaries; it is not a production security certification.

## Reporting

Do not open a public issue containing credentials, exploit-ready access details, raw state or secret values. Use the repository's private security reporting feature when available, or arrange a private channel with the maintainer before sharing sensitive evidence. Do not assume a contact address that is not published by the maintainer.

## Trust boundaries

- Foundation and workload state are distinct.
- Blob state and Key Vault public network access remain disabled.
- The configured operator uses Microsoft Entra authentication and explicit scoped roles.
- Secret write is temporary and must be removed after synthetic seeding.
- The managed pool subnet is exclusive; external validation hosts do not belong in it.
- The existing host's results do not establish actual agent job security.
- No automation trust/federation or pipeline setup is included in this version.

## Local handling

Protect the ignored local directory, state backups, saved plans and Terraform working data. A nonsecret export can still expose infrastructure identifiers. Share it deliberately and never modify it to bypass scope guards.

Do not log Azure access tokens, secret values, full credential-bearing environments, backend keys or state contents.

## Testing boundaries

Use only a disposable authorized subscription/resource set. Fault injection must target exact lab IDs, have a restoration path and leave the default boundary intact. Do not force-unlock unknown leases or delete state to hide residual infrastructure.

Inspect effective inherited RBAC before declaring that a negative test proves least privilege.

See [security exceptions](SECURITY_EXCEPTIONS.md) for deliberate lab choices and [recovery](docs/runbooks/recovery.md) for operational procedures.
