---
name: least-privilege
description: Apply least-privilege principles to IAM, service accounts, CI tokens, containers, network access, and system permissions.
---

# Least Privilege

Grant only the minimum access required for the task to succeed.

## Core rules

- Default deny.
- Scope permissions narrowly by action, resource, environment, and lifetime.
- Separate read, write, admin, and deploy capabilities.
- Prefer short-lived credentials over long-lived credentials.
- Avoid shared admin identities.

## Apply to

- Cloud IAM roles and policies
- Kubernetes RBAC and service accounts
- GitLab tokens and deploy tokens
- Container runtime permissions
- Filesystem permissions
- Network policies and firewall rules
- Database roles

## IAM guidance

- Avoid wildcard actions and wildcard resources unless unavoidable.
- Split human and machine access paths.
- Use separate roles per workload.
- Reduce blast radius by environment and account/project.
- Review privilege escalation paths, not only direct access.

## CI/CD guidance

- Job tokens should access only required resources.
- Deployment credentials should be environment-specific.
- Build jobs should not receive production deploy credentials.
- Protect production actions behind protected branches/environments and approvals when appropriate.

## Container guidance

- Run as non-root.
- Use read-only root filesystem where practical.
- Drop unnecessary capabilities.
- Avoid privileged mode.
- Mount only required volumes.

## Review checklist

- Can this permission be reduced?
- Can this identity be split by environment or workload?
- Is there any wildcard that can be replaced with a narrower scope?
- Is access time-bounded where possible?
- Could compromise of this identity pivot further than necessary?

## Output behavior

Prefer restrictive defaults and explicitly justify any elevated permission.
