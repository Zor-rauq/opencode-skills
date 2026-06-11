# OpenCode - Agent Instructions

Permanent instructions for all OpenCode sessions.
This file is the agent behavior reference for this project.

> Note: Written in English to avoid encoding issues across platforms.

---

## General behavior

- Produce the simplest implementation that satisfies the requirement.
- Prefer clarity over cleverness.
- Keep functions short with a single responsibility.
- Use variable and function names that reveal business or operational intent.
- Avoid premature abstractions and unnecessary patterns.
- Limit comments to intent, non-obvious constraints, or critical operational caveats.
- Do not comment what the code already expresses clearly.
- Never generate secrets, tokens, passwords or keys in plaintext in code, configs, logs or examples.
- Validate inputs at trust boundaries.
- Fail fast on invalid configuration or missing required state.

---

## Standards by file type

### Bash / Shell

- Start every script with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Quote variables systematically.
- Use arrays for command arguments.
- Validate required tools and input arguments at startup.
- Emit errors to stderr with an actionable message.
- Use traps to clean up temporary files.
- Do not use `|| true` without documented justification.

### Python

- Use type hints on public functions and important internal helpers.
- Use `pathlib` for paths.
- Use `logging` for operational scripts, not `print`.
- Separate parsing, orchestration, API access, and output formatting.
- Raise explicit exceptions with context.
- Return non-zero exit codes for CLI failures.
- Never embed credentials.

### Terraform / OpenTofu

- Pin provider versions in `versions.tf`.
- Use type constraints on variables.
- Prefer `for_each` over `count` when identity matters.
- Use remote state for shared and production environments.
- Never embed secrets; use CI variables or secret stores.
- Consistent tagging and naming across all resources.

### GitLab CI/CD

- Use `rules` instead of `only`/`except`.
- Name stages and jobs clearly.
- Scope artifacts carefully.
- Set explicit timeouts.
- Use masked and protected variables for secrets.
- Never print secret-backed variables to logs.
- Move complex logic into versioned scripts rather than inline YAML.

### Docker / Podman

- Multi-stage builds by default.
- Minimal base image.
- Non-root user.
- `COPY` over `ADD` unless ADD behavior is explicitly needed.
- No secrets in layers.
- Exec-form entrypoint.

### Markdown / Documentation

- Concise, structured, action-oriented.
- Prefer bullets and tables for scanning.
- Sanitized examples, no real secrets.
- Terminology consistent with the codebase.

---

## Secret hygiene

- Use placeholders only in examples: `${SECRET_NAME}`, `<TOKEN>`, `CHANGE_ME`.
- Reference secrets via CI/CD variables, vaults, or secret managers.
- Never produce a secret in plaintext, even for a test or an example.
- Immediately flag any suspicious value detected in existing code.

---

## Security defaults

- Apply least-privilege on IAM, RBAC, CI tokens, and container permissions.
- Avoid wildcards in permissions unless strictly necessary and justified.
- Separate human and machine identities.
- Use short-lived credentials when available.

---

## Git workflow - branch, commits, and validation

### Fundamental rule

Every change, even a minor one, must be made in a dedicated branch.
Never commit directly to `main`, `master`, or any production branch.

### Branch naming

Build the branch name based on the task context:

| Context                  | Format                         | Example                              |
|--------------------------|--------------------------------|--------------------------------------|
| New feature              | `feat/<short-description>`     | `feat/add-gitlab-ci-scan-stage`      |
| Bug fix                  | `fix/<short-description>`      | `fix/terraform-missing-timeout`      |
| Refactoring              | `refactor/<short-description>` | `refactor/simplify-deploy-script`    |
| Infrastructure / IaC     | `infra/<short-description>`    | `infra/s3-backend-state-migration`   |
| CI/CD                    | `ci/<short-description>`       | `ci/add-dependency-audit-job`        |
| Documentation            | `docs/<short-description>`     | `docs/update-runbook-deploy`         |
| Security                 | `security/<short-description>` | `security/rotate-ci-token-refs`      |
| Chore / maintenance      | `chore/<short-description>`    | `chore/bump-terraform-providers`     |

- Use kebab-case, all lowercase.
- Keep the name short and factual (3-5 words max after the prefix).
- If an issue or ticket exists, include its ID: `feat/PROJ-42-add-scan-stage`.

### Systematic startup procedure

Before any change:

```bash
git checkout main && git pull
git checkout -b <type>/<description>
```

### Atomic commits

- One commit = one coherent logical change.
- Do not group unrelated changes in the same commit.
- Use the conventional format:

```
<type>(<scope>): <short imperative description>

[Optional body: why - only if not obvious from the code]
[Compatibility or migration note if applicable]
```

Valid types: `feat`, `fix`, `refactor`, `docs`, `ci`, `chore`, `test`, `security`, `infra`.

Correct examples:
```
feat(ci): add SAST scan stage to merge request pipeline
fix(terraform): set explicit timeout on RDS instance
refactor(deploy): extract environment validation into function
```

Incorrect examples:
```
update stuff
fixes
WIP
various changes
```

### Mandatory check-points - user validation

The agent must request explicit validation before continuing in the following situations.
Never chain two check-points without waiting for the user's confirmation.

#### Check-point 1 - Before starting

Before creating the branch and writing any code:

```
--- CHECK-POINT 1 / Understanding -------------------------------------------
Goal      : <what is requested in one sentence>
Approach  : <short list of planned steps>
Files     : <list of impacted files or components>
Risks     : <attention points or open questions>
-----------------------------------------------------------------------------
-> Do you confirm this direction before I start?
```

#### Check-point 2 - After each significant logical step

After committing a coherent step:

```
--- CHECK-POINT 2 / Step completed ------------------------------------------
Done      : <description of what was committed>
Commit    : <short hash - message>
Result    : <expected or observed behavior>
Next      : <planned next step>
-----------------------------------------------------------------------------
-> Shall we continue to the next step?
```

#### Check-point 3 - Before any destructive or irreversible action

Mandatory before:
- Deleting files, resources, or branches
- Modifying Terraform state in production
- Changing a database schema
- Rotating or invalidating credentials
- Force-push

```
--- CHECK-POINT 3 / Irreversible action -------------------------------------
Action    : <precise description of what will be executed>
Impact    : <what will be permanently modified or deleted>
Rollback  : <whether rollback is possible or not>
-----------------------------------------------------------------------------
-> Do you confirm the execution of this action?
```

#### Check-point 4 - End of task / ready for Merge Request

Before proposing to open a MR:

```
--- CHECK-POINT 4 / Ready for Merge Request ---------------------------------
Branch    : <branch name>
Commits   : <list of commits with short hash>
Summary   : <description of what the MR brings>
To verify : <points to validate manually before merge>
-----------------------------------------------------------------------------
-> Shall I prepare the MR description or do you handle the rest?
```

---

## Code review

- Evaluate in this order: correctness, security, operational risk, maintainability, simplicity.
- Separate blocking issues from optional improvements.
- Always propose a simpler or safer alternative rather than just flagging.
- Do not nitpick style if the project already has automatic formatting tooling.

---

## Refactoring

- Prefer small, reviewable steps.
- Do not mix refactoring and feature addition in the same commit.
- Preserve public interfaces unless the change explicitly allows breakage.
- Stop when the code is clear enough; do not chase theoretical perfection.

---

## Always forbidden

- Committing directly to `main` or a production branch.
- Hardcoding secrets, tokens, passwords, or keys.
- Logging sensitive values.
- Using wildcards in IAM permissions without explicit justification.
- Executing a destructive action without a prior validation check-point.
- Introducing a new dependency without justifying the need.
- Silently ignoring an error.
- Chaining steps without having obtained user validation on the previous check-point.

---

## Available skills

Load the corresponding skill for any specialized task:

| Context                          | Skill                |
|----------------------------------|----------------------|
| Code quality and style           | `senior-code-style`  |
| Code review                      | `code-review`        |
| Refactoring                      | `refactor-safe`      |
| Terraform/OpenTofu infrastructure| `terraform-iac`      |
| GitLab CI/CD pipelines           | `ci-cd-gitlab`       |
| Docker/Podman containers         | `container-build`    |
| Bash scripts                     | `shell-scripting`    |
| Secret management                | `secret-hygiene`     |
| Permissions and IAM              | `least-privilege`    |
| Dependencies                     | `dependency-audit`   |
| Python automation                | `python-devops`      |
| REST/GraphQL API integrations    | `api-integration`    |
| Markdown/MkDocs documentation    | `docs-as-code`       |
| Architecture decisions           | `adr-writing`        |
| Commit messages                  | `git-commit-style`   |
| Branch strategy                  | `git-branching`      |
