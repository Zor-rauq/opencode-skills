---
name: secret-hygiene
description: Prevent exposure of secrets in code, pipelines, logs, images, configs, and documentation.
---

# Secret Hygiene

Treat any credential exposure as a production incident waiting to happen.

## Scope

Apply this skill to code, CI/CD, container builds, shell scripts, Terraform, Kubernetes manifests, documentation, sample files, and logs.

## Non-negotiable rules

- Never hardcode secrets in source code.
- Never commit secrets, even in examples or tests.
- Never print secrets to logs.
- Never include secrets in Docker layers or image history.
- Never pass secrets through unsafe channels when avoidable.
- Never use real secrets in documentation, screenshots, or examples.

## Approved patterns

- Use environment variables only when the runtime model supports them safely.
- Prefer dedicated secret stores: Vault, cloud secret managers, sealed secrets, SOPS, external secret operators, CI secret stores.
- Inject secrets as late as possible.
- Scope secrets to the narrowest environment, app, or job.
- Rotate secrets after suspected exposure.

## Detection mindset

Watch for:

- API tokens
- passwords
- SSH private keys
- kubeconfigs
- cloud access keys
- database URLs with credentials
- .npmrc, .pypirc, .netrc, auth headers, bearer tokens
- certificates and private material
- copied production values in examples

## Logging rules

- Redact sensitive fields.
- Never log Authorization headers, cookies, session IDs, passwords, tokens, or connection strings with credentials.
- Be careful with debug mode in CI and production.

## File hygiene

- Use .gitignore and equivalent ignore mechanisms.
- Keep example files sanitized, e.g. .env.example with placeholders only.
- Audit generated artifacts and archives before distribution.
- Prevent secret sprawl across local scripts and copied config fragments.

## CI/CD rules

- Use masked and protected variables where applicable.
- Avoid echoing secret-backed variables.
- Avoid writing secrets to workspace files unless required and cleaned up.
- Restrict secret availability by branch, environment, and job.

## Incident stance

If a secret may have been exposed:

1. Assume compromise.
2. Revoke or rotate it.
3. Remove it from code and history if needed.
4. Audit logs, artifacts, and images.
5. Document the exposure path.

## Output behavior

When generating code or config, use placeholders and secret references, never live secret values.
