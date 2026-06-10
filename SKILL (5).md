---
name: dependency-audit
description: Review and minimize dependencies for security, version control, reproducibility, and long-term maintainability.
---

# Dependency Audit

Treat every dependency as code you are choosing to trust and maintain indirectly.

## Principles

- Prefer fewer dependencies.
- Prefer mature, maintained, boring libraries.
- Prefer standard library when sufficient.
- Pin versions where reproducibility matters.
- Remove unused dependencies quickly.

## Audit checklist

- Is this dependency necessary?
- Is it actively maintained?
- Does it have a reasonable security posture?
- Does it pull a large transitive tree for little value?
- Is the version pinned or constrained appropriately?
- Is there a simpler alternative?

## Risks to flag

- Unmaintained packages
- Suspicious install scripts
- Large transitive dependency chains
- Duplicate libraries serving the same purpose
- Floating versions in critical systems
- Libraries used for trivial functionality already in standard libraries

## Language-agnostic rules

- Commit lockfiles where applicable.
- Review transitive dependencies in critical systems.
- Separate runtime dependencies from development-only tooling.
- Keep dependency update policy explicit.
- Prefer official vendor libraries when they are materially safer or better supported.

## Output behavior

Recommend the smallest credible dependency set and safer versioning practices.
